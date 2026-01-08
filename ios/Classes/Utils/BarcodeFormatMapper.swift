// BarcodeFormatMapper.swift
// ScanKit - Modern barcode scanner for Flutter
//
// This file provides mapping between string format identifiers
// and native Vision/VisionKit symbology types.

import Vision
import VisionKit

// MARK: - Barcode Format Mapper

/// Maps between ScanKit format strings and native symbology types.
///
/// Format string identifiers:
/// - 2D codes: "qr", "aztec", "dataMatrix", "pdf417"
/// - 1D product: "ean8", "ean13", "upca", "upce"
/// - 1D industrial: "code39", "code93", "code128", "codabar", "itf"
struct BarcodeFormatMapper {

    // MARK: - Vision Framework (for image scanning)

    /// Map format strings to Vision symbologies.
    /// Used for VNDetectBarcodesRequest in image scanning.
    static func mapFormatsToSymbologies(_ formats: [String]?) -> [VNBarcodeSymbology] {
        guard let formats = formats, !formats.isEmpty else {
            return allSymbologies()
        }

        var symbologies: [VNBarcodeSymbology] = []
        for format in formats {
            if let symbology = formatToSymbology(format) {
                symbologies.append(symbology)
            }
        }
        return symbologies.isEmpty ? [.qr] : symbologies
    }

    /// Convert a format string to Vision symbology.
    static func formatToSymbology(_ format: String) -> VNBarcodeSymbology? {
        switch format {
        case "qr": return .qr
        case "aztec": return .aztec
        case "dataMatrix": return .dataMatrix
        case "pdf417": return .pdf417
        case "ean8": return .ean8
        case "ean13": return .ean13
        case "upca": return .upce  // Note: Vision maps UPC-A to UPC-E
        case "upce": return .upce
        case "code39": return .code39
        case "code93": return .code93
        case "code128": return .code128
        case "codabar":
            if #available(iOS 15.0, *) { return .codabar }
            return nil
        case "itf": return .itf14
        default: return nil
        }
    }

    /// Convert Vision symbology to format string.
    static func symbologyToFormat(_ symbology: VNBarcodeSymbology) -> String {
        switch symbology {
        case .qr: return "qr"
        case .aztec: return "aztec"
        case .dataMatrix: return "dataMatrix"
        case .pdf417: return "pdf417"
        case .ean8: return "ean8"
        case .ean13: return "ean13"
        case .upce: return "upce"
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum:
            return "code39"
        case .code93, .code93i: return "code93"
        case .code128: return "code128"
        case .itf14: return "itf"
        default:
            if #available(iOS 15.0, *) {
                if symbology == .codabar { return "codabar" }
            }
            return "unknown"
        }
    }

    /// All supported Vision symbologies.
    private static func allSymbologies() -> [VNBarcodeSymbology] {
        var symbologies: [VNBarcodeSymbology] = [
            .qr, .aztec, .dataMatrix, .pdf417,
            .ean8, .ean13, .upce,
            .code39, .code93, .code128, .itf14
        ]
        if #available(iOS 15.0, *) {
            symbologies.append(.codabar)
        }
        return symbologies
    }

    // MARK: - VisionKit Framework (for DataScannerViewController)

    /// Map format strings to VisionKit symbologies.
    /// Used for DataScannerViewController (iOS 16+).
    @available(iOS 16.0, *)
    static func mapFormatsToVisionKitSymbologies(_ formats: [String]?) -> [VNBarcodeSymbology] {
        guard let formats = formats, !formats.isEmpty else {
            return [
                .qr, .aztec, .dataMatrix, .pdf417,
                .ean8, .ean13, .upce,
                .code39, .code93, .code128, .codabar, .itf14
            ]
        }

        var symbologies: [VNBarcodeSymbology] = []
        for format in formats {
            if let symbology = formatToVisionKitSymbology(format) {
                symbologies.append(symbology)
            }
        }
        return symbologies.isEmpty ? [.qr] : symbologies
    }

    /// Convert format string to VisionKit symbology (iOS 16+).
    @available(iOS 16.0, *)
    private static func formatToVisionKitSymbology(_ format: String) -> VNBarcodeSymbology? {
        switch format {
        case "qr": return .qr
        case "aztec": return .aztec
        case "dataMatrix": return .dataMatrix
        case "pdf417": return .pdf417
        case "ean8": return .ean8
        case "ean13": return .ean13
        case "upca": return .upce
        case "upce": return .upce
        case "code39": return .code39
        case "code93": return .code93
        case "code128": return .code128
        case "codabar": return .codabar
        case "itf": return .itf14
        default: return nil
        }
    }
}
