// FullScreenScanner.swift
// ScanKit - Modern barcode scanner for Flutter
//
// This file implements full-screen scanner presentation using either:
// - VisionKit DataScannerViewController (iOS 16+) - Apple's native scanner UI
// - Legacy AVFoundation scanner (iOS 13-15) - Custom implementation

import UIKit
import AVFoundation
import VisionKit

// MARK: - Full Screen Scanner Presenter

/// Handles presentation and dismissal of full-screen scanner interfaces.
/// Automatically selects the best scanner implementation for the iOS version.
@MainActor
class FullScreenScannerPresenter {

    // MARK: - Properties

    private weak var plugin: ScankitPlugin?
    private var scannerViewController: UIViewController?
    private var pendingResult: ((Result<BarcodeResult?, Error>) -> Void)?

    // MARK: - Initialization

    init(plugin: ScankitPlugin) {
        self.plugin = plugin
    }

    // MARK: - Public API

    /// Present a full-screen scanner with the given configuration.
    /// - Parameters:
    ///   - config: Scanner configuration options
    ///   - completion: Called with scan result or nil if cancelled
    func presentScanner(config: ScannerConfig, completion: @escaping (Result<BarcodeResult?, Error>) -> Void) {
        guard let rootViewController = findRootViewController() else {
            completion(.failure(PigeonError(
                code: "NO_VIEW_CONTROLLER",
                message: "Could not find root view controller",
                details: nil
            )))
            return
        }

        self.pendingResult = completion

        if #available(iOS 16.0, *) {
            presentDataScanner(from: rootViewController, config: config)
        } else {
            presentLegacyScanner(from: rootViewController, config: config)
        }
    }

    /// Handle scan result and dismiss the scanner.
    func handleScanResult(_ result: BarcodeResult) {
        dismissScanner {
            // Haptic feedback on successful scan
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            self.pendingResult?(.success(result))
            self.pendingResult = nil
        }
    }

    /// Handle user cancellation.
    func handleCancel() {
        dismissScanner {
            self.pendingResult?(.success(nil))
            self.pendingResult = nil
        }
    }

    /// Handle scanner errors.
    func handleError(_ error: Error) {
        dismissScanner {
            self.pendingResult?(.failure(error))
            self.pendingResult = nil
        }
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
        // Stop scanning if using DataScanner
        if #available(iOS 16.0, *) {
            if let scanner = scannerViewController as? DataScannerViewController {
                scanner.stopScanning()
            } else if let nav = scannerViewController as? UINavigationController,
                      let scanner = nav.viewControllers.first as? DataScannerViewController {
                scanner.stopScanning()
            }
        }

        // Turn off torch when dismissing
        TorchController.setTorch(enabled: false)

        scannerViewController?.dismiss(animated: true) {
            self.scannerViewController = nil
            completion()
        }
    }
}

// MARK: - VisionKit DataScanner (iOS 16+)

@available(iOS 16.0, *)
extension FullScreenScannerPresenter {

    private func presentDataScanner(from viewController: UIViewController, config: ScannerConfig) {
        guard DataScannerViewController.isSupported else {
            pendingResult?(.failure(PigeonError(
                code: "NOT_SUPPORTED",
                message: "DataScanner is not supported on this device",
                details: nil
            )))
            pendingResult = nil
            return
        }

        let symbologies = BarcodeFormatMapper.mapFormatsToVisionKitSymbologies(config.formats)

        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: symbologies)],
            qualityLevel: .accurate,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )

        scanner.delegate = plugin

        // Wrap in navigation controller for toolbar
        let nav = UINavigationController(rootViewController: scanner)
        nav.navigationBar.isTranslucent = true
        nav.navigationBar.barStyle = .black
        nav.navigationBar.tintColor = .white

        // Cancel button
        scanner.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        // Torch button (if available and enabled in config)
        if config.showTorchButton, TorchController.isTorchAvailable() {
            let flashButton = UIBarButtonItem(
                image: UIImage(systemName: "bolt.slash.fill"),
                style: .plain,
                target: self,
                action: #selector(torchTapped)
            )
            scanner.navigationItem.rightBarButtonItem = flashButton
        }

        nav.modalPresentationStyle = .fullScreen
        scannerViewController = nav

        viewController.present(nav, animated: true) {
            try? scanner.startScanning()
        }
    }

    @objc private func cancelTapped() {
        handleCancel()
    }

    @objc private func torchTapped() {
        let newState = TorchController.toggleTorch()

        // Update button icon
        if let nav = scannerViewController as? UINavigationController,
           let scanner = nav.viewControllers.first {
            let iconName = newState ? "bolt.fill" : "bolt.slash.fill"
            scanner.navigationItem.rightBarButtonItem?.image = UIImage(systemName: iconName)
        }
    }
}

// MARK: - Legacy Scanner (iOS 13-15)

extension FullScreenScannerPresenter {

    private func presentLegacyScanner(from viewController: UIViewController, config: ScannerConfig) {
        let legacyScanner = LegacyScannerViewController()
        legacyScanner.formats = config.formats
        legacyScanner.showTorchButton = config.showTorchButton

        legacyScanner.onResult = { [weak self] result in
            Task { @MainActor in
                self?.handleScanResult(result)
            }
        }

        legacyScanner.onCancel = { [weak self] in
            Task { @MainActor in
                self?.handleCancel()
            }
        }

        let nav = UINavigationController(rootViewController: legacyScanner)
        nav.modalPresentationStyle = .fullScreen
        scannerViewController = nav

        viewController.present(nav, animated: true)
    }
}
