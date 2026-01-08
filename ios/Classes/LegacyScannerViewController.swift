import UIKit
import AVFoundation
import Vision

/// Fallback scanner for iOS 13-15 using AVFoundation + Vision
class LegacyScannerViewController: UIViewController {

    var formats: [String]?
    var showTorchButton: Bool = true
    var onResult: ((BarcodeResult) -> Void)?
    var onCancel: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var captureDevice: AVCaptureDevice?
    private var isProcessing = false
    private var torchEnabled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupNavigationBar()
        checkCameraPermission()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopScanning()
    }

    private func setupNavigationBar() {
        title = "Scan Barcode"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        // Add torch button if available
        if showTorchButton, let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            let torchButton = UIBarButtonItem(
                image: UIImage(systemName: "bolt.slash.fill"),
                style: .plain,
                target: self,
                action: #selector(toggleTorch)
            )
            navigationItem.rightBarButtonItem = torchButton
        }
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func toggleTorch() {
        guard let device = captureDevice, device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            torchEnabled = !torchEnabled
            device.torchMode = torchEnabled ? .on : .off
            device.unlockForConfiguration()

            // Update button icon
            let iconName = torchEnabled ? "bolt.fill" : "bolt.slash.fill"
            navigationItem.rightBarButtonItem?.image = UIImage(systemName: iconName)
        } catch {
            // Ignore torch errors
        }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.showPermissionDenied()
                    }
                }
            }
        default:
            showPermissionDenied()
        }
    }

    private func showPermissionDenied() {
        let alert = UIAlertController(
            title: "Camera Access Required",
            message: "Please enable camera access in Settings to scan barcodes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.onCancel?()
        })
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }

        self.captureDevice = device

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "scankit.video"))

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        self.previewLayer = previewLayer
        self.captureSession = session

        addScanOverlay()

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func addScanOverlay() {
        let overlayView = ScanOverlayView(frame: view.bounds)
        overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlayView)
    }

    private func stopScanning() {
        captureSession?.stopRunning()

        // Turn off torch when stopping
        if let device = captureDevice, device.hasTorch, device.torchMode == .on {
            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension LegacyScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        isProcessing = true

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }

            defer { self.isProcessing = false }

            guard error == nil,
                  let results = request.results as? [VNBarcodeObservation],
                  let firstBarcode = results.first,
                  let payload = firstBarcode.payloadStringValue else {
                return
            }

            let format = BarcodeFormatMapper.symbologyToFormat(firstBarcode.symbology)

            DispatchQueue.main.async {
                self.stopScanning()

                let result = BarcodeResult(
                    value: payload,
                    format: format,
                    rawBytes: nil
                )
                self.onResult?(result)
            }
        }

        request.symbologies = BarcodeFormatMapper.mapFormatsToSymbologies(formats)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
}

// MARK: - Scan Overlay View
private class ScanOverlayView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // Semi-transparent background
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(rect)

        // Clear center square
        let size = min(rect.width, rect.height) * 0.7
        let centerRect = CGRect(
            x: (rect.width - size) / 2,
            y: (rect.height - size) / 2,
            width: size,
            height: size
        )

        context.setBlendMode(.clear)
        context.fill(centerRect)

        // Draw corner brackets
        context.setBlendMode(.normal)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)

        let cornerLength: CGFloat = 30
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            // Top-left
            (CGPoint(x: centerRect.minX, y: centerRect.minY + cornerLength),
             CGPoint(x: centerRect.minX, y: centerRect.minY),
             CGPoint(x: centerRect.minX + cornerLength, y: centerRect.minY)),
            // Top-right
            (CGPoint(x: centerRect.maxX - cornerLength, y: centerRect.minY),
             CGPoint(x: centerRect.maxX, y: centerRect.minY),
             CGPoint(x: centerRect.maxX, y: centerRect.minY + cornerLength)),
            // Bottom-left
            (CGPoint(x: centerRect.minX, y: centerRect.maxY - cornerLength),
             CGPoint(x: centerRect.minX, y: centerRect.maxY),
             CGPoint(x: centerRect.minX + cornerLength, y: centerRect.maxY)),
            // Bottom-right
            (CGPoint(x: centerRect.maxX - cornerLength, y: centerRect.maxY),
             CGPoint(x: centerRect.maxX, y: centerRect.maxY),
             CGPoint(x: centerRect.maxX, y: centerRect.maxY - cornerLength)),
        ]

        for (start, corner, end) in corners {
            context.move(to: start)
            context.addLine(to: corner)
            context.addLine(to: end)
            context.strokePath()
        }
    }
}
