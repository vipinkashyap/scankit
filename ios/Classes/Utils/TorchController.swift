// TorchController.swift
// ScanKit - Modern barcode scanner for Flutter
//
// This file provides centralized torch/flashlight control
// for use across different scanner implementations.

import AVFoundation

// MARK: - Torch Controller

/// Centralized torch/flashlight control for camera-based scanning.
struct TorchController {

    // MARK: - Availability

    /// Check if torch is available on the device.
    static func isTorchAvailable() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video) else {
            return false
        }
        return device.hasTorch
    }

    // MARK: - State

    /// Get the current torch state.
    static func getTorchState() -> Bool {
        guard let device = AVCaptureDevice.default(for: .video) else {
            return false
        }
        return device.torchMode == .on
    }

    // MARK: - Control

    /// Set the torch state.
    /// - Parameter enabled: Whether torch should be on
    /// - Returns: The new torch state
    @discardableResult
    static func setTorch(enabled: Bool) -> Bool {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else {
            return false
        }

        do {
            try device.lockForConfiguration()
            device.torchMode = enabled ? .on : .off
            device.unlockForConfiguration()
            return enabled
        } catch {
            return false
        }
    }

    /// Toggle the torch on/off.
    /// - Returns: The new torch state
    @discardableResult
    static func toggleTorch() -> Bool {
        let currentState = getTorchState()
        return setTorch(enabled: !currentState)
    }
}
