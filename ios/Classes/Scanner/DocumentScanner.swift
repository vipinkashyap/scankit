// DocumentScanner.swift
// ScanKit - Modern barcode scanner for Flutter
//
// This file implements document scanning using VNDocumentCameraViewController.
// Documents are saved as JPEG images to temporary storage.

import UIKit
import VisionKit

// MARK: - Document Scanner Presenter

/// Handles presentation and results from the system document scanner.
class DocumentScannerPresenter: NSObject {

    // MARK: - Properties

    private var pendingResult: ((Result<DocumentScanResult?, Error>) -> Void)?
    private var scannerViewController: VNDocumentCameraViewController?

    // MARK: - Public API

    /// Check if document scanning is supported on this device.
    static var isSupported: Bool {
        return VNDocumentCameraViewController.isSupported
    }

    /// Present the document scanner.
    /// - Parameters:
    ///   - config: Document scan configuration
    ///   - completion: Called with scanned pages or nil if cancelled
    func presentDocumentScanner(config: DocumentScanConfig, completion: @escaping (Result<DocumentScanResult?, Error>) -> Void) {
        guard let rootViewController = findRootViewController() else {
            completion(.failure(PigeonError(
                code: "NO_VIEW_CONTROLLER",
                message: "Could not find root view controller",
                details: nil
            )))
            return
        }

        self.pendingResult = completion

        let documentScanner = VNDocumentCameraViewController()
        documentScanner.delegate = self
        self.scannerViewController = documentScanner

        rootViewController.present(documentScanner, animated: true)
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

    private func dismissScanner(completion: @escaping () -> Void) {
        scannerViewController?.dismiss(animated: true) {
            self.scannerViewController = nil
            completion()
        }
    }
}

// MARK: - VNDocumentCameraViewControllerDelegate

extension DocumentScannerPresenter: VNDocumentCameraViewControllerDelegate {

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var pages: [ScannedPage] = []
        let tempDir = FileManager.default.temporaryDirectory

        // Save each scanned page as a JPEG file
        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            let fileName = "scankit_doc_\(UUID().uuidString)_\(i).jpg"
            let filePath = tempDir.appendingPathComponent(fileName)

            if let data = image.jpegData(compressionQuality: 0.9) {
                try? data.write(to: filePath)
                pages.append(ScannedPage(
                    imagePath: filePath.path,
                    width: Int64(image.size.width),
                    height: Int64(image.size.height)
                ))
            }
        }

        dismissScanner {
            let result = DocumentScanResult(pages: pages, pdfPath: nil)
            self.pendingResult?(.success(result))
            self.pendingResult = nil
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        dismissScanner {
            self.pendingResult?(.success(nil))
            self.pendingResult = nil
        }
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        dismissScanner {
            self.pendingResult?(.failure(PigeonError(
                code: "DOCUMENT_SCAN_ERROR",
                message: error.localizedDescription,
                details: nil
            )))
            self.pendingResult = nil
        }
    }
}
