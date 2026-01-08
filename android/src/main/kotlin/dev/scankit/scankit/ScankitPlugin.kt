/**
 * ScankitPlugin.kt
 * ScanKit - Modern barcode scanner for Flutter
 *
 * Main plugin entry point that implements the Pigeon-generated ScannerHostApi.
 * This file coordinates between Flutter and native scanner implementations.
 *
 * Architecture:
 * - ScankitPlugin: Main plugin, handles Pigeon API calls
 * - EmbeddedScannerView: Platform view for embedded scanning
 * - ScannerActivity: Full-screen scanner activity
 * - ImageScanner: Static image scanning (scanner/)
 * - BarcodeFormatMapper: Format string <-> ML Kit constant mapping (utils/)
 */
package dev.scankit.scankit

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.provider.MediaStore
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.IntentSenderRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import dev.scankit.scankit.scanner.ImageScanner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Main ScanKit Flutter plugin class.
 *
 * Implements:
 * - FlutterPlugin: For Flutter engine attachment
 * - ActivityAware: For activity lifecycle management
 * - ScannerHostApi: Pigeon-generated API interface
 */
class ScankitPlugin : FlutterPlugin, ActivityAware, ScannerHostApi {

    // MARK: - Properties

    private var activity: Activity? = null
    private var context: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var flutterApi: ScannerFlutterApi? = null

    // Pending callbacks for async operations
    private var pendingCallback: ((Result<BarcodeResult?>) -> Unit)? = null
    private var pendingDocumentCallback: ((Result<DocumentScanResult?>) -> Unit)? = null
    private var pendingGalleryCallback: ((Result<BarcodeResult?>) -> Unit)? = null
    private var pendingGalleryFormats: List<String>? = null

    // Document scanner components
    private var documentScanner: GmsDocumentScanner? = null
    private var scannerLauncher: ActivityResultLauncher<IntentSenderRequest>? = null

    // Torch state tracking
    private var torchEnabled = false

    /** Reference to active embedded scanner for runtime configuration updates */
    internal var activeEmbeddedScanner: EmbeddedScannerView? = null

    // MARK: - FlutterPlugin Implementation

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        flutterApi = ScannerFlutterApi(flutterPluginBinding.binaryMessenger)

        // Set up Pigeon API
        ScannerHostApi.setUp(flutterPluginBinding.binaryMessenger, this)

        // Register platform view factory for embedded scanner
        flutterPluginBinding.platformViewRegistry.registerViewFactory(
            "dev.scankit/scanner",
            ScannerViewFactory(flutterPluginBinding.binaryMessenger, this)
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        ScannerHostApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
        context = null
    }

    // MARK: - ActivityAware Implementation

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding

        // Register activity result listener
        binding.addActivityResultListener { requestCode, resultCode, data ->
            handleActivityResult(requestCode, resultCode, data)
        }

        // Register document scanner launcher if activity supports it
        (binding.activity as? AppCompatActivity)?.let { appCompatActivity ->
            scannerLauncher = appCompatActivity.registerForActivityResult(
                ActivityResultContracts.StartIntentSenderForResult()
            ) { result ->
                handleDocumentScanResult(result.resultCode, result.data)
            }
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
        activityBinding = null
        scannerLauncher = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding

        (binding.activity as? AppCompatActivity)?.let { appCompatActivity ->
            scannerLauncher = appCompatActivity.registerForActivityResult(
                ActivityResultContracts.StartIntentSenderForResult()
            ) { result ->
                handleDocumentScanResult(result.resultCode, result.data)
            }
        }
    }

    override fun onDetachedFromActivity() {
        activity = null
        activityBinding = null
        scannerLauncher = null
    }

    // MARK: - Device Capabilities

    override fun isSupported(): Boolean = true

    override fun isTorchAvailable(): Boolean {
        val ctx = context ?: return false
        val cameraManager = ctx.getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            ?: return false

        return try {
            val cameraId = cameraManager.cameraIdList.firstOrNull() ?: return false
            val characteristics = cameraManager.getCameraCharacteristics(cameraId)
            characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
        } catch (e: Exception) {
            false
        }
    }

    override fun isDocumentScanSupported(): Boolean = true

    // MARK: - Torch Control

    override fun setTorch(enabled: Boolean) {
        torchEnabled = enabled
        flutterApi?.onTorchStateChanged(enabled) { }
    }

    override fun getTorchState(): Boolean = torchEnabled

    // MARK: - Full-Screen Barcode Scanning

    override fun startScan(config: ScannerConfig, callback: (Result<BarcodeResult?>) -> Unit) {
        val currentActivity = activity
        if (currentActivity == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "No activity available", null)))
            return
        }

        pendingCallback = callback

        val intent = Intent(currentActivity, ScannerActivity::class.java).apply {
            putStringArrayListExtra(ScannerActivity.EXTRA_FORMATS, config.formats?.let { ArrayList(it) })
            putExtra(ScannerActivity.EXTRA_VIBRATE, config.vibrateOnScan)
            putExtra(ScannerActivity.EXTRA_BEEP, config.beepOnScan)
            putExtra(ScannerActivity.EXTRA_SHOW_TORCH, config.showTorchButton)
        }

        currentActivity.startActivityForResult(intent, REQUEST_CODE_SCAN)
    }

    // MARK: - Document Scanning

    override fun startDocumentScan(config: DocumentScanConfig, callback: (Result<DocumentScanResult?>) -> Unit) {
        val currentActivity = activity
        if (currentActivity == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "No activity available", null)))
            return
        }

        pendingDocumentCallback = callback

        val optionsBuilder = GmsDocumentScannerOptions.Builder()
            .setGalleryImportAllowed(config.allowGalleryImport)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)

        config.maxPages?.let { maxPages ->
            optionsBuilder.setPageLimit(maxPages.toInt())
        }

        documentScanner = GmsDocumentScanning.getClient(optionsBuilder.build())

        documentScanner?.getStartScanIntent(currentActivity)
            ?.addOnSuccessListener { intentSender ->
                val launcher = scannerLauncher
                if (launcher != null) {
                    launcher.launch(IntentSenderRequest.Builder(intentSender).build())
                } else {
                    // Fallback for non-AppCompatActivity
                    currentActivity.startIntentSenderForResult(
                        intentSender,
                        REQUEST_CODE_DOCUMENT_SCAN,
                        null, 0, 0, 0
                    )
                }
            }
            ?.addOnFailureListener { e ->
                pendingDocumentCallback?.invoke(Result.failure(FlutterError(
                    "DOCUMENT_SCAN_ERROR",
                    e.message ?: "Failed to start scanner",
                    null
                )))
                pendingDocumentCallback = null
            }
    }

    // MARK: - Image Scanning

    override fun scanFromImagePath(imagePath: String, formats: List<String>?, callback: (Result<BarcodeResult?>) -> Unit) {
        ImageScanner.scanFromFile(imagePath, formats, callback)
    }

    override fun scanFromGallery(formats: List<String>?, callback: (Result<BarcodeResult?>) -> Unit) {
        val currentActivity = activity
        if (currentActivity == null) {
            callback(Result.failure(FlutterError("NO_ACTIVITY", "No activity available", null)))
            return
        }

        pendingGalleryCallback = callback
        pendingGalleryFormats = formats

        val intent = Intent(Intent.ACTION_PICK, MediaStore.Images.Media.EXTERNAL_CONTENT_URI)
        currentActivity.startActivityForResult(intent, REQUEST_CODE_GALLERY)
    }

    // MARK: - Warm-up

    override fun warmUp() {
        // Pre-initialize ML Kit barcode scanner for faster first scan
        val options = BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
            .build()
        BarcodeScanning.getClient(options)
    }

    // MARK: - Embedded Scanner Configuration

    override fun updateEmbeddedConfig(config: EmbeddedScannerConfig) {
        activeEmbeddedScanner?.updateConfig(config)
    }

    override fun switchCamera() {
        activeEmbeddedScanner?.switchCamera()
    }

    override fun setZoom(zoom: Double) {
        activeEmbeddedScanner?.setZoom(zoom.toFloat())
    }

    // MARK: - Flutter Callbacks

    /** Notify Flutter of a detected barcode */
    fun notifyBarcodeDetected(result: BarcodeResult) {
        flutterApi?.onBarcodeDetected(result) { }
    }

    /** Notify Flutter of an error */
    fun notifyError(code: String, message: String) {
        flutterApi?.onError(code, message) { }
    }

    /** Notify Flutter of a camera switch */
    fun notifyCameraSwitched(facing: CameraFacing) {
        flutterApi?.onCameraSwitched(facing) { }
    }

    /** Notify Flutter of a zoom change */
    fun notifyZoomChanged(zoom: Double) {
        flutterApi?.onZoomChanged(zoom) { }
    }

    // MARK: - Activity Result Handling

    private fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        when (requestCode) {
            REQUEST_CODE_SCAN -> {
                handleScanResult(resultCode, data)
                return true
            }
            REQUEST_CODE_DOCUMENT_SCAN -> {
                handleDocumentScanResult(resultCode, data)
                return true
            }
            REQUEST_CODE_GALLERY -> {
                handleGalleryResult(resultCode, data)
                return true
            }
        }
        return false
    }

    private fun handleScanResult(resultCode: Int, data: Intent?) {
        val callback = pendingCallback
        pendingCallback = null

        when (resultCode) {
            Activity.RESULT_OK -> {
                val value = data?.getStringExtra(ScannerActivity.RESULT_VALUE)
                val format = data?.getStringExtra(ScannerActivity.RESULT_FORMAT)
                val rawBytes = data?.getByteArrayExtra(ScannerActivity.RESULT_RAW_BYTES)

                // Get bounding box
                val boxLeft = data?.getDoubleExtra(ScannerActivity.RESULT_BOX_LEFT, -1.0) ?: -1.0
                val boxTop = data?.getDoubleExtra(ScannerActivity.RESULT_BOX_TOP, -1.0) ?: -1.0
                val boxRight = data?.getDoubleExtra(ScannerActivity.RESULT_BOX_RIGHT, -1.0) ?: -1.0
                val boxBottom = data?.getDoubleExtra(ScannerActivity.RESULT_BOX_BOTTOM, -1.0) ?: -1.0

                val boundingBox = if (boxLeft >= 0) {
                    BoundingBox(boxLeft, boxTop, boxRight, boxBottom)
                } else null

                // Get corner points
                val cornerPointsArray = data?.getDoubleArrayExtra(ScannerActivity.RESULT_CORNERS)
                val cornerPoints = cornerPointsArray?.let { arr ->
                    if (arr.size >= 8) {
                        listOf(
                            Point(arr[0], arr[1]),
                            Point(arr[2], arr[3]),
                            Point(arr[4], arr[5]),
                            Point(arr[6], arr[7])
                        )
                    } else null
                }

                if (value != null && format != null) {
                    callback?.invoke(Result.success(BarcodeResult(
                        value, format, rawBytes, boundingBox, cornerPoints
                    )))
                } else {
                    callback?.invoke(Result.success(null))
                }
            }
            Activity.RESULT_CANCELED -> {
                callback?.invoke(Result.success(null))
            }
            else -> {
                val error = data?.getStringExtra(ScannerActivity.RESULT_ERROR)
                callback?.invoke(Result.failure(FlutterError(
                    "SCAN_ERROR",
                    error ?: "Unknown error",
                    null
                )))
            }
        }
    }

    private fun handleDocumentScanResult(resultCode: Int, data: Intent?) {
        val callback = pendingDocumentCallback
        pendingDocumentCallback = null

        if (resultCode == Activity.RESULT_OK && data != null) {
            val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
            if (scanResult != null) {
                val pages = scanResult.pages?.map { page ->
                    ScannedPage(
                        imagePath = page.imageUri.path ?: "",
                        width = 0,
                        height = 0
                    )
                } ?: emptyList()

                val result = DocumentScanResult(
                    pages = pages,
                    pdfPath = scanResult.pdf?.uri?.path
                )
                callback?.invoke(Result.success(result))
            } else {
                callback?.invoke(Result.success(null))
            }
        } else if (resultCode == Activity.RESULT_CANCELED) {
            callback?.invoke(Result.success(null))
        } else {
            callback?.invoke(Result.failure(FlutterError(
                "DOCUMENT_SCAN_ERROR",
                "Document scan failed",
                null
            )))
        }
    }

    private fun handleGalleryResult(resultCode: Int, data: Intent?) {
        val callback = pendingGalleryCallback
        val formats = pendingGalleryFormats
        pendingGalleryCallback = null
        pendingGalleryFormats = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback?.invoke(Result.success(null))
            return
        }

        val ctx = context
        if (ctx == null) {
            callback?.invoke(Result.failure(FlutterError("NO_CONTEXT", "No context available", null)))
            return
        }

        try {
            val uri = data.data!!
            val image = InputImage.fromFilePath(ctx, uri)
            ImageScanner.scanFromImage(image, formats, image.width, image.height, callback!!)
        } catch (e: Exception) {
            callback?.invoke(Result.failure(FlutterError(
                "IMAGE_ERROR",
                e.message ?: "Failed to load image",
                null
            )))
        }
    }

    companion object {
        private const val REQUEST_CODE_SCAN = 29438
        private const val REQUEST_CODE_DOCUMENT_SCAN = 29439
        private const val REQUEST_CODE_GALLERY = 29440
    }
}

/**
 * Factory for creating embedded scanner platform views.
 * Registered with Flutter to handle "dev.scankit/scanner" view type.
 */
class ScannerViewFactory(
    private val messenger: BinaryMessenger,
    private val plugin: ScankitPlugin
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = args as? Map<*, *>
        val formats = (params?.get("formats") as? List<*>)?.filterIsInstance<String>()
        return EmbeddedScannerView(context, viewId, formats, plugin)
    }
}
