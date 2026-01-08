package dev.scankit.scankit

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.ScaleGestureDetector
import android.view.View
import android.widget.FrameLayout
import androidx.annotation.OptIn
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ExperimentalGetImage
import androidx.camera.core.FocusMeteringAction
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import io.flutter.plugin.platform.PlatformView
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import android.util.Size

class EmbeddedScannerView(
    private val context: Context,
    private val viewId: Int,
    private var formats: List<String>?,
    private val plugin: ScankitPlugin
) : PlatformView, LifecycleOwner {

    private val containerView: FrameLayout = FrameLayout(context)
    private val previewView: PreviewView = PreviewView(context).apply {
        // Use COMPATIBLE mode (TextureView) for better Flutter integration
        // PERFORMANCE mode (SurfaceView) can cause issues with Flutter's platform view composition
        implementationMode = PreviewView.ImplementationMode.COMPATIBLE
    }
    private val cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val lifecycleRegistry: LifecycleRegistry = LifecycleRegistry(this)
    private var cameraProvider: ProcessCameraProvider? = null
    private var camera: Camera? = null
    private var lastScannedValue: String? = null
    private var lastScannedTime: Long = 0
    private val focusIndicatorView = FocusIndicatorView(context)

    // Configuration
    private var useFrontCamera = false
    private var resolution = CameraResolution.HIGH
    private var invertColors = false
    private var scanRegion: ScanRegion? = null
    private var debounceMs: Long = 500
    private var autoZoom = false
    private var currentZoom = 1.0f

    private val scaleGestureDetector = ScaleGestureDetector(context,
        object : ScaleGestureDetector.SimpleOnScaleGestureListener() {
            override fun onScale(detector: ScaleGestureDetector): Boolean {
                val camera = camera ?: return true
                val zoomState = camera.cameraInfo.zoomState.value ?: return true
                val currentZoom = zoomState.zoomRatio
                val newZoom = currentZoom * detector.scaleFactor
                val clampedZoom = newZoom.coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
                camera.cameraControl.setZoomRatio(clampedZoom)
                this@EmbeddedScannerView.currentZoom = clampedZoom
                plugin.notifyZoomChanged(clampedZoom.toDouble())
                return true
            }
        }
    )

    private val tapGestureDetector = GestureDetector(context,
        object : GestureDetector.SimpleOnGestureListener() {
            override fun onSingleTapUp(e: MotionEvent): Boolean {
                handleTapToFocus(e.x, e.y)
                return true
            }
        }
    )

    init {
        containerView.addView(
            previewView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        // Add focus indicator overlay
        containerView.addView(
            focusIndicatorView,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
        )

        // Enable pinch-to-zoom and tap-to-focus
        previewView.setOnTouchListener { _, event ->
            var handled = scaleGestureDetector.onTouchEvent(event)
            // Only handle tap if not in the middle of a scale gesture
            if (!scaleGestureDetector.isInProgress) {
                handled = tapGestureDetector.onTouchEvent(event) || handled
            }
            handled
        }

        lifecycleRegistry.currentState = Lifecycle.State.CREATED
        lifecycleRegistry.currentState = Lifecycle.State.STARTED
        lifecycleRegistry.currentState = Lifecycle.State.RESUMED

        // Register with plugin
        plugin.activeEmbeddedScanner = this

        startCamera()
    }

    override val lifecycle: Lifecycle
        get() = lifecycleRegistry

    override fun getView(): View = containerView

    override fun dispose() {
        if (plugin.activeEmbeddedScanner == this) {
            plugin.activeEmbeddedScanner = null
        }
        cameraProvider?.unbindAll()
        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
        cameraExecutor.shutdown()
    }

    fun updateConfig(config: EmbeddedScannerConfig) {
        formats = config.formats
        useFrontCamera = config.cameraFacing == CameraFacing.FRONT
        resolution = config.resolution
        invertColors = config.invertColors
        scanRegion = config.scanRegion
        debounceMs = config.debounceMs.toLong()
        autoZoom = config.autoZoom

        // Restart camera with new config
        cameraProvider?.unbindAll()
        startCamera()
    }

    fun switchCamera() {
        useFrontCamera = !useFrontCamera
        cameraProvider?.unbindAll()
        startCamera()

        val newFacing = if (useFrontCamera) CameraFacing.FRONT else CameraFacing.BACK
        plugin.notifyCameraSwitched(newFacing)
    }

    fun setZoom(zoom: Float) {
        val camera = camera ?: return
        val zoomState = camera.cameraInfo.zoomState.value ?: return
        val clampedZoom = zoom.coerceIn(zoomState.minZoomRatio, zoomState.maxZoomRatio)
        camera.cameraControl.setZoomRatio(clampedZoom)
        currentZoom = clampedZoom
        plugin.notifyZoomChanged(clampedZoom.toDouble())
    }

    fun setTorch(enabled: Boolean): Boolean {
        val camera = camera ?: return false
        if (!camera.cameraInfo.hasFlashUnit()) return false
        camera.cameraControl.enableTorch(enabled)
        plugin.notifyTorchStateChanged(enabled)
        return true
    }

    fun isTorchAvailable(): Boolean {
        return camera?.cameraInfo?.hasFlashUnit() == true
    }

    private fun startCamera() {
        // Check camera permission first
        val permissionStatus = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA)
        if (permissionStatus != PackageManager.PERMISSION_GRANTED) {
            plugin.notifyError(
                "camera_permission_denied",
                "Camera permission not granted. Please enable in Settings."
            )
            return
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(context)

        cameraProviderFuture.addListener({
            try {
                val cameraProvider = cameraProviderFuture.get()
                this.cameraProvider = cameraProvider

                // Build preview with resolution
                val previewBuilder = Preview.Builder()
                applyResolution(previewBuilder)
                val preview = previewBuilder.build().also {
                    it.surfaceProvider = previewView.surfaceProvider
                }

                val barcodeFormats = mapFormatsToMLKit(formats)
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

                val imageAnalysisBuilder = ImageAnalysis.Builder()
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                applyResolution(imageAnalysisBuilder)
                val imageAnalysis = imageAnalysisBuilder.build()

                imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                    processImageProxy(barcodeScanner, imageProxy)
                }

                val cameraSelector = if (useFrontCamera) {
                    CameraSelector.DEFAULT_FRONT_CAMERA
                } else {
                    CameraSelector.DEFAULT_BACK_CAMERA
                }

                cameraProvider.unbindAll()
                camera = cameraProvider.bindToLifecycle(
                    this,
                    cameraSelector,
                    preview,
                    imageAnalysis
                )

                // Apply auto-zoom if enabled and we have a previous zoom level
                if (currentZoom > 1.0f) {
                    setZoom(currentZoom)
                }
            } catch (e: Exception) {
                plugin.notifyError("SCANNER_ERROR", "Failed to start camera: ${e.message}")
            }
        }, ContextCompat.getMainExecutor(context))
    }

    private fun <T> applyResolution(builder: T) {
        val size = when (resolution) {
            CameraResolution.LOW -> Size(640, 480)
            CameraResolution.MEDIUM -> Size(1280, 720)
            CameraResolution.HIGH -> Size(1920, 1080)
            CameraResolution.MAX -> Size(3840, 2160)
        }

        val resolutionSelector = ResolutionSelector.Builder()
            .setResolutionStrategy(
                ResolutionStrategy(size, ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER)
            )
            .build()

        when (builder) {
            is Preview.Builder -> builder.setResolutionSelector(resolutionSelector)
            is ImageAnalysis.Builder -> builder.setResolutionSelector(resolutionSelector)
        }
    }

    @OptIn(ExperimentalGetImage::class)
    private fun processImageProxy(
        barcodeScanner: com.google.mlkit.vision.barcode.BarcodeScanner,
        imageProxy: ImageProxy
    ) {
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return
        }

        val inputImage = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)

        barcodeScanner.process(inputImage)
            .addOnSuccessListener { barcodes ->
                // Filter by scan region if set
                val filteredBarcodes = if (scanRegion != null) {
                    barcodes.filter { barcode ->
                        barcode.boundingBox?.let { box ->
                            val viewWidth = previewView.width.toFloat()
                            val viewHeight = previewView.height.toFloat()
                            if (viewWidth > 0 && viewHeight > 0) {
                                val normalizedLeft = box.left / viewWidth
                                val normalizedTop = box.top / viewHeight
                                val normalizedRight = box.right / viewWidth
                                val normalizedBottom = box.bottom / viewHeight

                                val region = scanRegion!!
                                normalizedLeft >= region.left &&
                                normalizedTop >= region.top &&
                                normalizedRight <= (region.left + region.width) &&
                                normalizedBottom <= (region.top + region.height)
                            } else true
                        } ?: true
                    }
                } else barcodes

                if (filteredBarcodes.isNotEmpty()) {
                    val barcode = filteredBarcodes.first()
                    handleBarcodeDetected(barcode, imageProxy)

                    // Auto-zoom toward barcode if enabled
                    if (autoZoom && barcode.boundingBox != null) {
                        autoZoomToBarcode(barcode)
                    }
                }
            }
            .addOnCompleteListener {
                imageProxy.close()
            }
    }

    private fun autoZoomToBarcode(barcode: Barcode) {
        val box = barcode.boundingBox ?: return
        val camera = camera ?: return
        val zoomState = camera.cameraInfo.zoomState.value ?: return

        val viewWidth = previewView.width.toFloat()
        val viewHeight = previewView.height.toFloat()
        if (viewWidth <= 0 || viewHeight <= 0) return

        // Calculate barcode size relative to view
        val barcodeWidth = box.width() / viewWidth
        val barcodeHeight = box.height() / viewHeight
        val barcodeSize = maxOf(barcodeWidth, barcodeHeight)

        // If barcode is small, zoom in
        if (barcodeSize < 0.3f && currentZoom < zoomState.maxZoomRatio) {
            val targetZoom = (currentZoom * 1.5f).coerceAtMost(zoomState.maxZoomRatio)
            camera.cameraControl.setZoomRatio(targetZoom)
            currentZoom = targetZoom
            plugin.notifyZoomChanged(targetZoom.toDouble())
        }
    }

    private fun handleBarcodeDetected(barcode: Barcode, imageProxy: ImageProxy) {
        val value = barcode.rawValue ?: barcode.displayValue ?: return

        // Debounce: don't report same barcode within debounceMs
        val now = System.currentTimeMillis()
        if (value == lastScannedValue && now - lastScannedTime < debounceMs) {
            return
        }
        lastScannedValue = value
        lastScannedTime = now

        val format = mlkitFormatToString(barcode.format)

        // Calculate normalized bounding box
        val viewWidth = previewView.width.toFloat()
        val viewHeight = previewView.height.toFloat()

        val boundingBox = barcode.boundingBox?.let { box ->
            if (viewWidth > 0 && viewHeight > 0) {
                BoundingBox(
                    box.left.toDouble() / viewWidth,
                    box.top.toDouble() / viewHeight,
                    box.right.toDouble() / viewWidth,
                    box.bottom.toDouble() / viewHeight
                )
            } else null
        }

        val cornerPoints = barcode.cornerPoints?.let { corners ->
            if (viewWidth > 0 && viewHeight > 0 && corners.size == 4) {
                corners.map { point ->
                    Point(point.x.toDouble() / viewWidth, point.y.toDouble() / viewHeight)
                }
            } else null
        }

        val result = BarcodeResult(
            value,
            format,
            barcode.rawBytes,
            boundingBox,
            cornerPoints
        )

        // Notify Flutter on main thread
        containerView.post {
            plugin.notifyBarcodeDetected(result)
        }
    }

    private fun mapFormatsToMLKit(formats: List<String>?): List<Int> {
        if (formats.isNullOrEmpty()) return emptyList()

        return formats.mapNotNull { format ->
            when (format) {
                "qr" -> Barcode.FORMAT_QR_CODE
                "aztec" -> Barcode.FORMAT_AZTEC
                "dataMatrix" -> Barcode.FORMAT_DATA_MATRIX
                "pdf417" -> Barcode.FORMAT_PDF417
                "ean8" -> Barcode.FORMAT_EAN_8
                "ean13" -> Barcode.FORMAT_EAN_13
                "upca" -> Barcode.FORMAT_UPC_A
                "upce" -> Barcode.FORMAT_UPC_E
                "code39" -> Barcode.FORMAT_CODE_39
                "code93" -> Barcode.FORMAT_CODE_93
                "code128" -> Barcode.FORMAT_CODE_128
                "codabar" -> Barcode.FORMAT_CODABAR
                "itf" -> Barcode.FORMAT_ITF
                else -> null
            }
        }
    }

    private fun mlkitFormatToString(format: Int): String {
        return when (format) {
            Barcode.FORMAT_QR_CODE -> "qr"
            Barcode.FORMAT_AZTEC -> "aztec"
            Barcode.FORMAT_DATA_MATRIX -> "dataMatrix"
            Barcode.FORMAT_PDF417 -> "pdf417"
            Barcode.FORMAT_EAN_8 -> "ean8"
            Barcode.FORMAT_EAN_13 -> "ean13"
            Barcode.FORMAT_UPC_A -> "upca"
            Barcode.FORMAT_UPC_E -> "upce"
            Barcode.FORMAT_CODE_39 -> "code39"
            Barcode.FORMAT_CODE_93 -> "code93"
            Barcode.FORMAT_CODE_128 -> "code128"
            Barcode.FORMAT_CODABAR -> "codabar"
            Barcode.FORMAT_ITF -> "itf"
            else -> "unknown"
        }
    }

    private fun handleTapToFocus(x: Float, y: Float) {
        val camera = camera ?: return

        // Create metering point from tap coordinates
        val meteringPointFactory = previewView.meteringPointFactory
        val meteringPoint = meteringPointFactory.createPoint(x, y)

        // Build focus and metering action
        val action = FocusMeteringAction.Builder(meteringPoint)
            .setAutoCancelDuration(3, java.util.concurrent.TimeUnit.SECONDS)
            .build()

        // Execute focus action
        camera.cameraControl.startFocusAndMetering(action)

        // Show focus indicator
        focusIndicatorView.showAt(x, y)
    }
}

// Custom view for showing focus indicator animation
private class FocusIndicatorView(context: Context) : View(context) {
    private val paint = Paint().apply {
        color = Color.YELLOW
        style = Paint.Style.STROKE
        strokeWidth = 4f
        isAntiAlias = true
    }

    private var focusX = 0f
    private var focusY = 0f
    private var radius = 80f
    private var alpha = 0

    fun showAt(x: Float, y: Float) {
        focusX = x
        focusY = y
        radius = 80f
        alpha = 255

        invalidate()

        // Animate shrink and fade out
        animate()
            .setDuration(150)
            .withStartAction {
                visibility = VISIBLE
            }
            .withEndAction {
                // Hold briefly then fade out
                postDelayed({
                    animate()
                        .setDuration(300)
                        .withEndAction {
                            visibility = INVISIBLE
                        }
                        .start()
                }, 500)
            }
            .start()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (alpha > 0) {
            paint.alpha = alpha
            canvas.drawCircle(focusX, focusY, radius * 0.7f, paint)
        }
    }
}
