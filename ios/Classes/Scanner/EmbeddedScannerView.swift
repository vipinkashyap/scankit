// EmbeddedScannerView.swift
// ScanKit - Modern barcode scanner for Flutter
//
// This file implements the embedded scanner view that can be placed
// within a Flutter widget tree using platform views.

import Flutter
import UIKit
import AVFoundation
import Vision

// MARK: - Platform View Factory

/// Factory for creating embedded scanner platform views.
/// Registered with Flutter to handle "dev.scankit/scanner" view type.
class ScannerViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private weak var plugin: ScankitPlugin?

    init(messenger: FlutterBinaryMessenger, plugin: ScankitPlugin) {
        self.messenger = messenger
        self.plugin = plugin
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return EmbeddedScannerView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            messenger: messenger,
            plugin: plugin
        )
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

// MARK: - Embedded Scanner View

/// A platform view that embeds a camera-based barcode scanner within a Flutter widget.
///
/// Features:
/// - Real-time barcode detection using Vision framework
/// - Front/back camera support
/// - Pinch-to-zoom and tap-to-focus gestures
/// - Configurable scan region (ROI)
/// - Debounce for duplicate detections
/// - Auto-zoom toward detected barcodes
class EmbeddedScannerView: NSObject, FlutterPlatformView {

    // MARK: - UI Components

    private let containerView: ScannerContainerView
    private var previewLayer: AVCaptureVideoPreviewLayer?

    // MARK: - Camera Components

    private var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var currentZoomFactor: CGFloat = 1.0

    // MARK: - Configuration

    /// Barcode formats to detect (nil = all formats)
    private var formats: [String]?

    /// Use front-facing camera instead of back
    private var useFrontCamera = false

    /// Minimum time between same-value detections (milliseconds)
    private var debounceMs: Int = 500

    /// Region of interest for barcode detection (nil = full frame)
    private var scanRegion: ScanRegion?

    /// Automatically zoom toward detected barcodes
    private var autoZoom = false

    // MARK: - Debounce State

    private var lastScannedValue: String?
    private var lastScannedTime: Date = Date.distantPast

    // MARK: - Plugin Reference

    private weak var plugin: ScankitPlugin?

    // MARK: - Initialization

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger, plugin: ScankitPlugin?) {
        containerView = ScannerContainerView(frame: frame)
        containerView.backgroundColor = .black
        self.plugin = plugin

        // Parse initial configuration from Flutter
        if let params = args as? [String: Any] {
            formats = params["formats"] as? [String]
        }

        super.init()

        setupGestures()
        registerWithPlugin()
        setupCamera()
    }

    deinit {
        captureSession?.stopRunning()
        unregisterFromPlugin()
    }

    func view() -> UIView {
        return containerView
    }

    // MARK: - Setup

    private func setupGestures() {
        // Layout updates
        containerView.onLayoutUpdate = { [weak self] in
            self?.updatePreviewLayerFrame()
        }

        // Pinch-to-zoom
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        containerView.addGestureRecognizer(pinchGesture)

        // Tap-to-focus
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapGesture(_:)))
        containerView.addGestureRecognizer(tapGesture)

        containerView.isUserInteractionEnabled = true
    }

    private func registerWithPlugin() {
        Task { @MainActor in
            plugin?.activeEmbeddedScanner = self
        }
    }

    private func unregisterFromPlugin() {
        Task { @MainActor in
            if plugin?.activeEmbeddedScanner === self {
                plugin?.activeEmbeddedScanner = nil
            }
        }
    }

    private func updatePreviewLayerFrame() {
        previewLayer?.frame = containerView.bounds
    }

    // MARK: - Public Configuration API

    /// Update scanner configuration at runtime.
    /// Called from Flutter via the plugin when `updateConfig()` is invoked.
    func updateConfig(_ config: EmbeddedScannerConfig) {
        formats = config.formats
        useFrontCamera = config.cameraFacing == .front
        debounceMs = Int(config.debounceMs)
        scanRegion = config.scanRegion
        autoZoom = config.autoZoom

        // Restart camera with new configuration
        captureSession?.stopRunning()
        setupCamera()
    }

    /// Switch between front and back cameras.
    func switchCamera() {
        useFrontCamera = !useFrontCamera
        captureSession?.stopRunning()
        setupCamera()

        let newFacing: CameraFacing = useFrontCamera ? .front : .back
        Task { @MainActor in
            self.plugin?.notifyCameraSwitched(newFacing)
        }
    }

    /// Set the camera zoom level.
    /// - Parameter zoom: Zoom factor (1.0 = no zoom)
    func setZoom(_ zoom: CGFloat) {
        guard let device = captureDevice else { return }

        let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
        let clampedZoom = max(1.0, min(zoom, maxZoom))

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
            currentZoomFactor = clampedZoom
            Task { @MainActor in
                self.plugin?.notifyZoomChanged(Double(clampedZoom))
            }
        } catch {
            // Zoom errors are non-critical
        }
    }

    // MARK: - Gesture Handlers

    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let device = captureDevice else { return }

        switch gesture.state {
        case .began:
            currentZoomFactor = device.videoZoomFactor
        case .changed:
            let newZoomFactor = currentZoomFactor * gesture.scale
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0)
            let clampedZoom = max(1.0, min(newZoomFactor, maxZoom))

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
            } catch {
                // Zoom errors are non-critical
            }
        default:
            break
        }
    }

    @objc private func handleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard let device = captureDevice,
              let previewLayer = previewLayer else { return }

        let tapPoint = gesture.location(in: containerView)
        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)

        do {
            try device.lockForConfiguration()

            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }

            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }

            device.unlockForConfiguration()
            showFocusIndicator(at: tapPoint)
        } catch {
            // Focus errors are non-critical
        }
    }

    private func showFocusIndicator(at point: CGPoint) {
        let focusView = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        focusView.center = point
        focusView.layer.borderColor = UIColor.yellow.cgColor
        focusView.layer.borderWidth = 2
        focusView.layer.cornerRadius = 40
        focusView.alpha = 0
        containerView.addSubview(focusView)

        UIView.animate(withDuration: 0.15, animations: {
            focusView.alpha = 1
            focusView.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.5, options: [], animations: {
                focusView.alpha = 0
            }) { _ in
                focusView.removeFromSuperview()
            }
        }
    }
}

// MARK: - Camera Setup

extension EmbeddedScannerView {

    private func setupCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStartCamera()
                    } else {
                        self?.notifyPermissionError(denied: true)
                    }
                }
            }
        case .denied:
            notifyPermissionError(denied: true)
        case .restricted:
            notifyPermissionError(denied: false)
        @unknown default:
            break
        }
    }

    private func notifyPermissionError(denied: Bool) {
        Task { @MainActor in
            if denied {
                self.plugin?.notifyError(
                    code: "camera_permission_denied",
                    message: "Camera permission denied. Please enable in Settings."
                )
            } else {
                self.plugin?.notifyError(
                    code: "camera_permission_restricted",
                    message: "Camera access is restricted on this device."
                )
            }
        }
    }

    private func configureAndStartCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Select appropriate camera
        let cameraPosition: AVCaptureDevice.Position = useFrontCamera ? .front : .back
        guard let device = findCamera(position: cameraPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            Task { @MainActor in
                self.plugin?.notifyError(
                    code: "camera_unavailable",
                    message: "Could not access the \(useFrontCamera ? "front" : "back") camera"
                )
            }
            return
        }

        self.captureDevice = device

        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Configure video output for barcode detection
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "scankit.embedded.video"))

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        // Setup preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        containerView.layer.addSublayer(previewLayer)

        self.previewLayer = previewLayer
        self.captureSession = session

        updatePreviewLayerFrame()

        // Start camera on background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    /// Find a camera device for the specified position.
    private func findCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }
}

// MARK: - Video Frame Processing

extension EmbeddedScannerView: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            self?.handleBarcodeDetection(request: request, error: error)
        }

        request.symbologies = BarcodeFormatMapper.mapFormatsToSymbologies(formats)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }

    private func handleBarcodeDetection(request: VNRequest, error: Error?) {
        guard error == nil,
              let results = request.results as? [VNBarcodeObservation],
              let barcode = results.first,
              let payload = barcode.payloadStringValue else {
            return
        }

        // Apply scan region filter
        if !isBarcodeInScanRegion(barcode) {
            return
        }

        // Apply debounce
        if !shouldEmitBarcode(value: payload) {
            return
        }

        let result = createBarcodeResult(from: barcode, payload: payload)

        // Update debounce state
        lastScannedValue = payload
        lastScannedTime = Date()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.autoZoom {
                self.autoZoomToBarcode(boundingBox: barcode.boundingBox)
            }

            self.plugin?.notifyBarcodeDetected(result)
        }
    }

    private func createBarcodeResult(from barcode: VNBarcodeObservation, payload: String) -> BarcodeResult {
        let format = BarcodeFormatMapper.symbologyToFormat(barcode.symbology)

        // Convert Vision coordinates (bottom-left origin) to standard coordinates (top-left origin)
        let box = barcode.boundingBox
        let boundingBox = BoundingBox(
            left: Double(box.minX),
            top: Double(1 - box.maxY),
            right: Double(box.maxX),
            bottom: Double(1 - box.minY)
        )

        let cornerPoints: [Point] = [
            Point(x: Double(barcode.topLeft.x), y: Double(1 - barcode.topLeft.y)),
            Point(x: Double(barcode.topRight.x), y: Double(1 - barcode.topRight.y)),
            Point(x: Double(barcode.bottomRight.x), y: Double(1 - barcode.bottomRight.y)),
            Point(x: Double(barcode.bottomLeft.x), y: Double(1 - barcode.bottomLeft.y)),
        ]

        return BarcodeResult(
            value: payload,
            format: format,
            rawBytes: nil,
            boundingBox: boundingBox,
            cornerPoints: cornerPoints
        )
    }
}

// MARK: - Scan Region Filtering

extension EmbeddedScannerView {

    /// Check if the barcode's center is within the configured scan region.
    /// Vision framework uses bottom-left origin coordinates (0-1 normalized).
    private func isBarcodeInScanRegion(_ barcode: VNBarcodeObservation) -> Bool {
        guard let region = scanRegion else {
            return true // No region configured, accept all
        }

        let box = barcode.boundingBox
        let centerX = box.midX
        let centerY = box.midY

        // Convert scan region to Vision coordinates (flip Y axis)
        let regionLeft = region.left
        let regionRight = region.left + region.width
        let regionBottom = 1 - region.top - region.height
        let regionTop = 1 - region.top

        return centerX >= regionLeft && centerX <= regionRight &&
               centerY >= regionBottom && centerY <= regionTop
    }
}

// MARK: - Debounce Logic

extension EmbeddedScannerView {

    /// Determine if this barcode should be emitted based on debounce settings.
    /// Allows immediate emission for new values, but rate-limits repeated detections.
    private func shouldEmitBarcode(value: String) -> Bool {
        // Always emit different barcodes immediately
        if value != lastScannedValue {
            return true
        }

        // Same value - check if debounce period has elapsed
        let timeSinceLastScan = Date().timeIntervalSince(lastScannedTime) * 1000
        return timeSinceLastScan >= Double(debounceMs)
    }
}

// MARK: - Auto-Zoom Logic

extension EmbeddedScannerView {

    /// Automatically zoom toward barcode if it appears small in the frame.
    /// Uses smooth ramping for a better user experience.
    private func autoZoomToBarcode(boundingBox: CGRect) {
        guard let device = captureDevice else { return }

        // Calculate barcode area as percentage of frame
        let barcodeArea = boundingBox.width * boundingBox.height
        let minSizeThreshold: CGFloat = 0.09 // ~30% of each dimension

        guard barcodeArea < minSizeThreshold else { return }

        // Calculate if zoom would help
        let currentArea = barcodeArea * currentZoomFactor * currentZoomFactor
        if currentArea < minSizeThreshold {
            let targetZoom = currentZoomFactor * 1.5
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            let clampedZoom = min(targetZoom, maxZoom)

            if clampedZoom > currentZoomFactor {
                do {
                    try device.lockForConfiguration()
                    device.ramp(toVideoZoomFactor: clampedZoom, withRate: 2.0)
                    device.unlockForConfiguration()
                    currentZoomFactor = clampedZoom
                    Task { @MainActor in
                        self.plugin?.notifyZoomChanged(Double(clampedZoom))
                    }
                } catch {
                    // Zoom errors are non-critical
                }
            }
        }
    }
}

// MARK: - Container View

/// Custom UIView that notifies when layout changes occur.
/// Used to keep the preview layer frame in sync with the container.
private class ScannerContainerView: UIView {
    var onLayoutUpdate: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayoutUpdate?()
    }
}
