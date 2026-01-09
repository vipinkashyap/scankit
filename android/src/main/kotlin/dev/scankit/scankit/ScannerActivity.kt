package dev.scankit.scankit

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.Toast
import androidx.annotation.OptIn
import androidx.appcompat.app.AppCompatActivity
import dev.scankit.scankit.utils.BarcodeFormatMapper
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class ScannerActivity : AppCompatActivity() {

    private lateinit var previewView: PreviewView
    private lateinit var cameraExecutor: ExecutorService
    private var hasScanned = false
    private var camera: Camera? = null
    private var flashButton: ImageButton? = null
    private var torchEnabled = false

    private var formats: List<String>? = null
    private var vibrateOnScan = true
    private var beepOnScan = false
    private var showTorchButton = true
    private var showNativeOverlay = true

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        formats = intent.getStringArrayListExtra(EXTRA_FORMATS)
        vibrateOnScan = intent.getBooleanExtra(EXTRA_VIBRATE, true)
        beepOnScan = intent.getBooleanExtra(EXTRA_BEEP, false)
        showTorchButton = intent.getBooleanExtra(EXTRA_SHOW_TORCH, true)
        showNativeOverlay = intent.getBooleanExtra(EXTRA_SHOW_OVERLAY, true)

        setupUI()
        cameraExecutor = Executors.newSingleThreadExecutor()

        if (hasCameraPermission()) {
            startCamera()
        } else {
            requestCameraPermission()
        }
    }

    private fun setupUI() {
        previewView = PreviewView(this).apply {
            layoutParams = android.view.ViewGroup.LayoutParams(
                android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                android.view.ViewGroup.LayoutParams.MATCH_PARENT
            )
            implementationMode = PreviewView.ImplementationMode.PERFORMANCE
        }

        setContentView(previewView)

        val buttonSize = (resources.displayMetrics.density * 48).toInt()
        val topMargin = (resources.displayMetrics.density * 48).toInt()
        val sideMargin = (resources.displayMetrics.density * 16).toInt()

        // Add close button overlay
        val closeButton = ImageButton(this).apply {
            setImageResource(R.drawable.ic_close)
            setBackgroundColor(android.graphics.Color.TRANSPARENT)
            layoutParams = FrameLayout.LayoutParams(buttonSize, buttonSize).apply {
                this.topMargin = topMargin
                marginStart = sideMargin
                gravity = Gravity.START or Gravity.TOP
            }
            setOnClickListener { cancel() }
        }

        addContentView(closeButton, closeButton.layoutParams)

        // Add flash button overlay (if torch available and config allows)
        if (showTorchButton && packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)) {
            flashButton = ImageButton(this).apply {
                setImageResource(R.drawable.ic_flash_off)
                setBackgroundColor(android.graphics.Color.TRANSPARENT)
                contentDescription = "Toggle flash"
                layoutParams = FrameLayout.LayoutParams(buttonSize, buttonSize).apply {
                    this.topMargin = topMargin
                    marginEnd = sideMargin
                    gravity = Gravity.END or Gravity.TOP
                }
                setOnClickListener { toggleTorch() }
            }
            addContentView(flashButton, flashButton!!.layoutParams)
        }

        // Add scan overlay (optional - can be disabled for Flutter-based overlays)
        if (showNativeOverlay) {
            val overlayView = ScanOverlayView(this)
            addContentView(
                overlayView,
                android.view.ViewGroup.LayoutParams(
                    android.view.ViewGroup.LayoutParams.MATCH_PARENT,
                    android.view.ViewGroup.LayoutParams.MATCH_PARENT
                )
            )
        }
    }

    private fun toggleTorch() {
        camera?.let { cam ->
            if (cam.cameraInfo.hasFlashUnit()) {
                torchEnabled = !torchEnabled
                cam.cameraControl.enableTorch(torchEnabled)
                updateFlashButtonIcon()
            }
        }
    }

    private fun updateFlashButtonIcon() {
        flashButton?.setImageResource(
            if (torchEnabled) R.drawable.ic_flash_on
            else R.drawable.ic_flash_off
        )
    }

    private fun hasCameraPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestCameraPermission() {
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.CAMERA),
            REQUEST_CODE_PERMISSIONS
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                startCamera()
            } else {
                Toast.makeText(this, "Camera permission is required to scan barcodes", Toast.LENGTH_LONG).show()
                returnError("Camera permission denied")
            }
        }
    }

    private fun startCamera() {
        val cameraProviderFuture = ProcessCameraProvider.getInstance(this)

        cameraProviderFuture.addListener({
            val cameraProvider = cameraProviderFuture.get()

            val preview = Preview.Builder()
                .build()
                .also {
                    it.surfaceProvider = previewView.surfaceProvider
                }

            val barcodeFormats = BarcodeFormatMapper.mapFormatsToMlKit(formats)
            val options = if (barcodeFormats.isNotEmpty()) {
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(barcodeFormats.first(), *barcodeFormats.drop(1).toIntArray())
                    .build()
            } else {
                BarcodeScannerOptions.Builder()
                    .setBarcodeFormats(Barcode.FORMAT_ALL_FORMATS)
                    .build()
            }

            val barcodeScanner = BarcodeScanning.getClient(options)

            val imageAnalysis = ImageAnalysis.Builder()
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .build()

            imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                processImageProxy(barcodeScanner, imageProxy)
            }

            val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

            try {
                cameraProvider.unbindAll()
                camera = cameraProvider.bindToLifecycle(
                    this,
                    cameraSelector,
                    preview,
                    imageAnalysis
                )
            } catch (e: Exception) {
                returnError("Failed to bind camera: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(this))
    }

    @OptIn(ExperimentalGetImage::class)
    private fun processImageProxy(
        barcodeScanner: com.google.mlkit.vision.barcode.BarcodeScanner,
        imageProxy: ImageProxy
    ) {
        val mediaImage = imageProxy.image
        if (mediaImage == null || hasScanned) {
            imageProxy.close()
            return
        }

        val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

        barcodeScanner.process(inputImage)
            .addOnSuccessListener { barcodes ->
                if (barcodes.isNotEmpty() && !hasScanned) {
                    hasScanned = true
                    handleBarcodeDetected(barcodes.first())
                }
            }
            .addOnCompleteListener {
                imageProxy.close()
            }
    }

    private fun handleBarcodeDetected(barcode: Barcode) {
        if (vibrateOnScan) {
            vibrate()
        }

        val format = BarcodeFormatMapper.mlKitFormatToString(barcode.format)
        val value = barcode.rawValue ?: barcode.displayValue ?: ""

        val resultIntent = Intent().apply {
            putExtra(RESULT_VALUE, value)
            putExtra(RESULT_FORMAT, format)
            barcode.rawBytes?.let { putExtra(RESULT_RAW_BYTES, it) }

            // Add bounding box (normalized 0-1 coordinates)
            barcode.boundingBox?.let { box ->
                val viewWidth = previewView.width.toFloat()
                val viewHeight = previewView.height.toFloat()
                if (viewWidth > 0 && viewHeight > 0) {
                    putExtra(RESULT_BOX_LEFT, box.left.toDouble() / viewWidth)
                    putExtra(RESULT_BOX_TOP, box.top.toDouble() / viewHeight)
                    putExtra(RESULT_BOX_RIGHT, box.right.toDouble() / viewWidth)
                    putExtra(RESULT_BOX_BOTTOM, box.bottom.toDouble() / viewHeight)
                }
            }

            // Add corner points (normalized 0-1 coordinates)
            barcode.cornerPoints?.let { corners ->
                val viewWidth = previewView.width.toFloat()
                val viewHeight = previewView.height.toFloat()
                if (viewWidth > 0 && viewHeight > 0 && corners.size == 4) {
                    val normalizedCorners = corners.flatMap { point ->
                        listOf(point.x.toDouble() / viewWidth, point.y.toDouble() / viewHeight)
                    }.toDoubleArray()
                    putExtra(RESULT_CORNERS, normalizedCorners)
                }
            }
        }

        setResult(Activity.RESULT_OK, resultIntent)
        finish()
    }

    private fun vibrate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vibratorManager = getSystemService(VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vibratorManager?.defaultVibrator?.vibrate(
                VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE)
            )
        } else {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(VIBRATOR_SERVICE) as? Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator?.vibrate(VibrationEffect.createOneShot(100, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator?.vibrate(100)
            }
        }
    }

    private fun cancel() {
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    private fun returnError(message: String) {
        val resultIntent = Intent().apply {
            putExtra(RESULT_ERROR, message)
        }
        setResult(RESULT_ERROR_CODE, resultIntent)
        finish()
    }

    override fun onDestroy() {
        super.onDestroy()
        cameraExecutor.shutdown()
    }

    companion object {
        const val EXTRA_FORMATS = "formats"
        const val EXTRA_VIBRATE = "vibrate"
        const val EXTRA_BEEP = "beep"
        const val EXTRA_SHOW_TORCH = "showTorch"
        const val EXTRA_SHOW_OVERLAY = "showOverlay"

        const val RESULT_VALUE = "value"
        const val RESULT_FORMAT = "format"
        const val RESULT_RAW_BYTES = "rawBytes"
        const val RESULT_ERROR = "error"

        const val RESULT_BOX_LEFT = "boxLeft"
        const val RESULT_BOX_TOP = "boxTop"
        const val RESULT_BOX_RIGHT = "boxRight"
        const val RESULT_BOX_BOTTOM = "boxBottom"
        const val RESULT_CORNERS = "corners"

        const val RESULT_ERROR_CODE = 2

        private const val REQUEST_CODE_PERMISSIONS = 10
    }
}
