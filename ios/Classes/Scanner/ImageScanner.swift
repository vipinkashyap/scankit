// ImageScanner.swift
// ScanKit - Modern barcode scanner for Flutter
//
// This file implements barcode scanning from static images,
// either from the photo gallery or from a file path.

import UIKit
import Vision

// MARK: - Image Scanner

/// Scans barcodes from static images using the Vision framework.
class ImageScanner {

    // MARK: - Scan from CGImage

    /// Scan a barcode from a CGImage.
    /// - Parameters:
    ///   - cgImage: The image to scan
    ///   - formats: Barcode formats to detect (nil = all)
    ///   - completion: Called with detected barcode or nil if not found
    static func scanBarcode(
        from cgImage: CGImage,
        formats: [String]?,
        completion: @escaping (Result<BarcodeResult?, Error>) -> Void
    ) {
        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(PigeonError(
                        code: "SCAN_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    )))
                }
                return
            }

            guard let results = request.results as? [VNBarcodeObservation],
                  let barcode = results.first,
                  let payload = barcode.payloadStringValue else {
                DispatchQueue.main.async {
                    completion(.success(nil))
                }
                return
            }

            let result = createBarcodeResult(from: barcode, payload: payload)

            DispatchQueue.main.async {
                completion(.success(result))
            }
        }

        // Configure symbologies
        if let formats = formats, !formats.isEmpty {
            let symbologies = BarcodeFormatMapper.mapFormatsToSymbologies(formats)
            if !symbologies.isEmpty {
                request.symbologies = symbologies
            }
        }

        // Perform detection on background thread
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    /// Scan a barcode from an image file.
    /// - Parameters:
    ///   - imagePath: Path to the image file
    ///   - formats: Barcode formats to detect (nil = all)
    ///   - completion: Called with detected barcode or nil if not found
    static func scanBarcode(
        fromImagePath imagePath: String,
        formats: [String]?,
        completion: @escaping (Result<BarcodeResult?, Error>) -> Void
    ) {
        guard let image = UIImage(contentsOfFile: imagePath),
              let cgImage = image.cgImage else {
            completion(.success(nil))
            return
        }

        scanBarcode(from: cgImage, formats: formats, completion: completion)
    }

    // MARK: - Private Helpers

    private static func createBarcodeResult(from barcode: VNBarcodeObservation, payload: String) -> BarcodeResult {
        let format = BarcodeFormatMapper.symbologyToFormat(barcode.symbology)

        // Create bounding box (Vision uses bottom-left origin)
        let box = barcode.boundingBox
        let boundingBox = BoundingBox(
            left: Double(box.minX),
            top: Double(1 - box.maxY),
            right: Double(box.maxX),
            bottom: Double(1 - box.minY)
        )

        // Corner points
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

// MARK: - Gallery Image Picker

/// Handles image selection from the photo gallery for barcode scanning.
class GalleryImagePicker: NSObject {

    // MARK: - Properties

    private var pendingResult: ((Result<BarcodeResult?, Error>) -> Void)?
    private var pendingFormats: [String]?

    // MARK: - Public API

    /// Present the image picker and scan selected image for barcodes.
    /// - Parameters:
    ///   - formats: Barcode formats to detect (nil = all)
    ///   - completion: Called with detected barcode or nil if cancelled/not found
    func pickAndScanImage(
        formats: [String]?,
        completion: @escaping (Result<BarcodeResult?, Error>) -> Void
    ) {
        guard let rootViewController = findRootViewController() else {
            completion(.failure(PigeonError(
                code: "NO_VIEW_CONTROLLER",
                message: "Could not find root view controller",
                details: nil
            )))
            return
        }

        self.pendingResult = completion
        self.pendingFormats = formats

        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        rootViewController.present(picker, animated: true)
    }

    // MARK: - Private Helpers

    private func findRootViewController() -> UIViewController? {
        guard let rootViewController = UIApplication.shared.keyWindow?.rootViewController else {
            return nil
        }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }
}

// MARK: - UIImagePickerControllerDelegate

extension GalleryImagePicker: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }

            guard let image = info[.originalImage] as? UIImage,
                  let cgImage = image.cgImage else {
                self.pendingResult?(.success(nil))
                self.pendingResult = nil
                self.pendingFormats = nil
                return
            }

            ImageScanner.scanBarcode(from: cgImage, formats: self.pendingFormats) { result in
                self.pendingResult?(result)
                self.pendingResult = nil
                self.pendingFormats = nil
            }
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) { [weak self] in
            self?.pendingResult?(.success(nil))
            self?.pendingResult = nil
            self?.pendingFormats = nil
        }
    }
}
