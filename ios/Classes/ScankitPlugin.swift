// ScankitPlugin.swift
// ScanKit - Modern barcode scanner for Flutter
//
// Main plugin entry point that implements the Pigeon-generated ScannerHostApi.
// This file coordinates between Flutter and native scanner implementations.
//
// Architecture:
// - ScankitPlugin: Main plugin, handles Pigeon API calls
// - EmbeddedScannerView: Platform view for embedded scanning (Scanner/)
// - FullScreenScannerPresenter: Full-screen scanner UI (Scanner/)
// - DocumentScannerPresenter: Document scanning (Scanner/)
// - ImageScanner/GalleryImagePicker: Static image scanning (Scanner/)
// - BarcodeFormatMapper: Format string <-> symbology mapping (Utils/)
// - TorchController: Torch/flashlight control (Utils/)

import Flutter
import UIKit
import VisionKit
import AVFoundation
import Vision

// MARK: - Main Plugin

@MainActor
public class ScankitPlugin: NSObject, FlutterPlugin, ScannerHostApi {

    // MARK: - Properties

    /// Pigeon API for callbacks to Flutter
    private var flutterApi: ScannerFlutterApi?

    /// Plugin registrar reference
    private weak var registrar: FlutterPluginRegistrar?

    /// Active embedded scanner (for runtime config updates)
    weak var activeEmbeddedScanner: EmbeddedScannerView?

    /// Full-screen scanner presenter
    private var fullScreenPresenter: FullScreenScannerPresenter?

    /// Document scanner presenter
    private var documentPresenter: DocumentScannerPresenter?

    /// Gallery image picker
    private var galleryPicker: GalleryImagePicker?

    /// Pending results for async operations
    private var pendingResult: ((Result<BarcodeResult?, Error>) -> Void)?
    private var pendingDocumentResult: ((Result<DocumentScanResult?, Error>) -> Void)?

    // MARK: - Plugin Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ScankitPlugin()
        instance.registrar = registrar
        instance.flutterApi = ScannerFlutterApi(binaryMessenger: registrar.messenger())

        // Set up Pigeon API
        ScannerHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: instance)

        // Register platform view factory for embedded scanner
        let factory = ScannerViewFactory(messenger: registrar.messenger(), plugin: instance)
        registrar.register(factory, withId: "dev.scankit/scanner")
    }

    // MARK: - Device Capabilities

    nonisolated func isSupported() throws -> Bool {
        if #available(iOS 16.0, *) {
            return MainActor.assumeIsolated {
                DataScannerViewController.isSupported && DataScannerViewController.isAvailable
            }
        }
        return AVCaptureDevice.default(for: .video) != nil
    }

    nonisolated func isTorchAvailable() throws -> Bool {
        return TorchController.isTorchAvailable()
    }

    nonisolated func isDocumentScanSupported() throws -> Bool {
        return DocumentScannerPresenter.isSupported
    }

    // MARK: - Torch Control

    nonisolated func setTorch(enabled: Bool) throws {
        let success = TorchController.setTorch(enabled: enabled)
        if success {
            Task { @MainActor in
                self.flutterApi?.onTorchStateChanged(enabled: enabled) { _ in }
            }
        }
    }

    nonisolated func getTorchState() throws -> Bool {
        return TorchController.getTorchState()
    }

    // MARK: - Full-Screen Barcode Scanning

    nonisolated func startScan(config: ScannerConfig, completion: @escaping (Result<BarcodeResult?, Error>) -> Void) {
        Task { @MainActor in
            self.pendingResult = completion

            if self.fullScreenPresenter == nil {
                self.fullScreenPresenter = FullScreenScannerPresenter(plugin: self)
            }

            self.fullScreenPresenter?.presentScanner(config: config) { result in
                self.pendingResult = nil
                completion(result)
            }
        }
    }

    // MARK: - Document Scanning

    nonisolated func startDocumentScan(config: DocumentScanConfig, completion: @escaping (Result<DocumentScanResult?, Error>) -> Void) {
        Task { @MainActor in
            self.pendingDocumentResult = completion

            if self.documentPresenter == nil {
                self.documentPresenter = DocumentScannerPresenter()
            }

            self.documentPresenter?.presentDocumentScanner(config: config) { result in
                self.pendingDocumentResult = nil
                completion(result)
            }
        }
    }

    // MARK: - Image Scanning

    nonisolated func scanFromImagePath(imagePath: String, formats: [String]?, completion: @escaping (Result<BarcodeResult?, Error>) -> Void) {
        Task { @MainActor in
            ImageScanner.scanBarcode(fromImagePath: imagePath, formats: formats, completion: completion)
        }
    }

    nonisolated func scanFromGallery(formats: [String]?, completion: @escaping (Result<BarcodeResult?, Error>) -> Void) {
        Task { @MainActor in
            if self.galleryPicker == nil {
                self.galleryPicker = GalleryImagePicker()
            }

            self.galleryPicker?.pickAndScanImage(formats: formats, completion: completion)
        }
    }

    // MARK: - Warm-up

    nonisolated func warmUp() throws {
        // Pre-initialize Vision framework for faster first scan
        Task { @MainActor in
            let request = VNDetectBarcodesRequest { _, _ in }
            if #available(iOS 15.0, *) {
                _ = request.supportedSymbologies
            }
        }
    }

    // MARK: - Embedded Scanner Configuration

    nonisolated func updateEmbeddedConfig(config: EmbeddedScannerConfig) throws {
        Task { @MainActor in
            self.activeEmbeddedScanner?.updateConfig(config)
        }
    }

    nonisolated func switchCamera() throws {
        Task { @MainActor in
            self.activeEmbeddedScanner?.switchCamera()
        }
    }

    nonisolated func setZoom(zoom: Double) throws {
        Task { @MainActor in
            self.activeEmbeddedScanner?.setZoom(CGFloat(zoom))
        }
    }

    // MARK: - Flutter Callbacks

    /// Notify Flutter of a detected barcode.
    func notifyBarcodeDetected(_ result: BarcodeResult) {
        flutterApi?.onBarcodeDetected(barcode: result) { _ in }
    }

    /// Notify Flutter of a camera switch.
    func notifyCameraSwitched(_ facing: CameraFacing) {
        flutterApi?.onCameraSwitched(facing: facing) { _ in }
    }

    /// Notify Flutter of a zoom change.
    func notifyZoomChanged(_ zoom: Double) {
        flutterApi?.onZoomChanged(zoom: zoom) { _ in }
    }

    /// Notify Flutter of an error.
    func notifyError(code: String, message: String) {
        flutterApi?.onError(code: code, message: message) { _ in }
    }
}

// MARK: - DataScannerViewControllerDelegate

@available(iOS 16.0, *)
extension ScankitPlugin: DataScannerViewControllerDelegate {

    public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        processRecognizedItem(item, viewSize: dataScanner.view.bounds.size)
    }

    public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        if let firstItem = addedItems.first {
            processRecognizedItem(firstItem, viewSize: dataScanner.view.bounds.size)
        }
    }

    public func dataScannerDidZoom(_ dataScanner: DataScannerViewController) {}

    public func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
        fullScreenPresenter?.handleError(PigeonError(
            code: "SCANNER_ERROR",
            message: error.localizedDescription,
            details: nil
        ))
    }

    private func processRecognizedItem(_ item: RecognizedItem, viewSize: CGSize) {
        guard case .barcode(let barcode) = item else { return }

        let format = BarcodeFormatMapper.symbologyToFormat(barcode.observation.symbology)
        let value = barcode.payloadStringValue ?? ""

        // Calculate bounding box (normalized)
        let bounds = barcode.bounds
        let minX = min(bounds.topLeft.x, bounds.bottomLeft.x)
        let maxX = max(bounds.topRight.x, bounds.bottomRight.x)
        let minY = min(bounds.topLeft.y, bounds.topRight.y)
        let maxY = max(bounds.bottomLeft.y, bounds.bottomRight.y)

        let boundingBox = BoundingBox(
            left: minX / viewSize.width,
            top: minY / viewSize.height,
            right: maxX / viewSize.width,
            bottom: maxY / viewSize.height
        )

        // Corner points (normalized)
        let cornerPoints: [Point] = [
            Point(x: Double(bounds.topLeft.x / viewSize.width), y: Double(bounds.topLeft.y / viewSize.height)),
            Point(x: Double(bounds.topRight.x / viewSize.width), y: Double(bounds.topRight.y / viewSize.height)),
            Point(x: Double(bounds.bottomRight.x / viewSize.width), y: Double(bounds.bottomRight.y / viewSize.height)),
            Point(x: Double(bounds.bottomLeft.x / viewSize.width), y: Double(bounds.bottomLeft.y / viewSize.height)),
        ]

        let result = BarcodeResult(
            value: value,
            format: format,
            rawBytes: nil,
            boundingBox: boundingBox,
            cornerPoints: cornerPoints
        )

        fullScreenPresenter?.handleScanResult(result)
    }
}

// MARK: - UIAdaptivePresentationControllerDelegate

extension ScankitPlugin: UIAdaptivePresentationControllerDelegate {

    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        // User dismissed by swiping down
        fullScreenPresenter?.handleCancel()
    }
}
