/// Core ScanKit API for barcode and document scanning
///
/// This file contains:
/// - [ScanKit] - Main static API for scanning operations
/// - [CameraFacing] - Camera direction enum
/// - [CameraResolution] - Resolution presets
/// - [ScanRegion] - Region of interest for scanning
library;

import 'dart:io';
import 'dart:ui';

import 'barcode_format.dart';
import 'barcode_result.dart';
import 'document_result.dart';
import 'generated/messages.g.dart' as pigeon;

/// Camera facing direction
enum CameraFacing {
  back,
  front,
}

/// Camera resolution preset
enum CameraResolution {
  /// 480p
  low,
  /// 720p
  medium,
  /// 1080p
  high,
  /// Maximum available
  max,
}

/// Scan region (normalized 0-1 coordinates)
class ScanRegion {
  const ScanRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  /// Left edge (0-1)
  final double left;
  /// Top edge (0-1)
  final double top;
  /// Width (0-1)
  final double width;
  /// Height (0-1)
  final double height;

  /// Center region (50% of screen, centered)
  static const center = ScanRegion(left: 0.25, top: 0.25, width: 0.5, height: 0.5);

  /// Top half of screen
  static const topHalf = ScanRegion(left: 0, top: 0, width: 1, height: 0.5);

  /// Bottom half of screen
  static const bottomHalf = ScanRegion(left: 0, top: 0.5, width: 1, height: 0.5);
}

/// Main entry point for ScanKit barcode and document scanner
class ScanKit {
  ScanKit._();

  static final _api = pigeon.ScannerHostApi();

  // ============ Barcode Scanning ============

  /// Opens a full-screen scanner and returns the scanned barcode.
  ///
  /// Returns `null` if the user cancels the scan.
  ///
  /// [formats] - List of barcode formats to scan for. Defaults to all formats.
  /// [beepOnScan] - Whether to play a beep sound on successful scan.
  /// [vibrateOnScan] - Whether to vibrate on successful scan.
  /// [showTorchButton] - Whether to show torch toggle button.
  /// [cameraFacing] - Which camera to use (front or back).
  /// [resolution] - Camera resolution preset.
  /// [invertColors] - Enable for white-on-black barcodes.
  /// [scanRegion] - Restrict scanning to a region (null = full frame).
  static Future<BarcodeResult?> scan({
    List<BarcodeFormat>? formats,
    bool beepOnScan = false,
    bool vibrateOnScan = true,
    bool showTorchButton = true,
    CameraFacing cameraFacing = CameraFacing.back,
    CameraResolution resolution = CameraResolution.high,
    bool invertColors = false,
    ScanRegion? scanRegion,
  }) async {
    final config = pigeon.ScannerConfig(
      formats: formats?.map((f) => f.identifier).toList(),
      beepOnScan: beepOnScan,
      vibrateOnScan: vibrateOnScan,
      showTorchButton: showTorchButton,
      cameraFacing: _toPigeonCameraFacing(cameraFacing),
      resolution: _toPigeonResolution(resolution),
      invertColors: invertColors,
      scanRegion: scanRegion != null ? _toPigeonScanRegion(scanRegion) : null,
    );

    final result = await _api.startScan(config);
    if (result == null) return null;

    return _convertBarcodeResult(result);
  }

  /// Checks if the device supports barcode scanning
  static Future<bool> isSupported() => _api.isSupported();

  /// Checks if torch/flash is available on the device
  static Future<bool> isTorchAvailable() => _api.isTorchAvailable();

  /// Sets the torch state (requires active scanner)
  static Future<void> setTorch(bool enabled) => _api.setTorch(enabled);

  /// Gets the current torch state
  static Future<bool> getTorchState() => _api.getTorchState();

  /// Toggles the torch on/off
  static Future<bool> toggleTorch() async {
    final current = await getTorchState();
    await setTorch(!current);
    return !current;
  }

  // ============ Gallery/Image Scanning ============

  /// Opens photo gallery to pick an image and scan barcode from it.
  ///
  /// Returns `null` if the user cancels or no barcode is found.
  ///
  /// [formats] - List of barcode formats to scan for. Defaults to all formats.
  static Future<BarcodeResult?> scanFromGallery({
    List<BarcodeFormat>? formats,
  }) async {
    final result = await _api.scanFromGallery(
      formats?.map((f) => f.identifier).toList(),
    );
    if (result == null) return null;
    return _convertBarcodeResult(result);
  }

  /// Scans barcode from an image file.
  ///
  /// Returns `null` if no barcode is found in the image.
  ///
  /// [file] - The image file to scan.
  /// [formats] - List of barcode formats to scan for. Defaults to all formats.
  static Future<BarcodeResult?> scanFromFile(
    File file, {
    List<BarcodeFormat>? formats,
  }) async {
    final result = await _api.scanFromImagePath(
      file.path,
      formats?.map((f) => f.identifier).toList(),
    );
    if (result == null) return null;
    return _convertBarcodeResult(result);
  }

  // ============ Initialization ============

  /// Pre-initializes the scanner for faster startup.
  ///
  /// Call this during app initialization (e.g., splash screen) to
  /// reduce the time to first scan when the user opens the scanner.
  static Future<void> warmUp() => _api.warmUp();

  // ============ Document Scanning ============

  /// Opens a document scanner and returns scanned pages.
  ///
  /// Returns `null` if the user cancels the scan.
  ///
  /// [maxPages] - Maximum number of pages to scan (null = unlimited).
  /// [allowGalleryImport] - Whether to allow importing from photo gallery.
  static Future<DocumentScanResult?> scanDocument({
    int? maxPages,
    bool allowGalleryImport = true,
  }) async {
    final config = pigeon.DocumentScanConfig(
      maxPages: maxPages,
      allowGalleryImport: allowGalleryImport,
    );

    final result = await _api.startDocumentScan(config);
    if (result == null) return null;

    return _convertDocumentResult(result);
  }

  /// Checks if document scanning is supported on this device
  static Future<bool> isDocumentScanSupported() =>
      _api.isDocumentScanSupported();

  // ============ Private Helpers ============

  static pigeon.CameraFacing _toPigeonCameraFacing(CameraFacing facing) {
    return facing == CameraFacing.front
        ? pigeon.CameraFacing.front
        : pigeon.CameraFacing.back;
  }

  static pigeon.CameraResolution _toPigeonResolution(CameraResolution res) {
    return switch (res) {
      CameraResolution.low => pigeon.CameraResolution.low,
      CameraResolution.medium => pigeon.CameraResolution.medium,
      CameraResolution.high => pigeon.CameraResolution.high,
      CameraResolution.max => pigeon.CameraResolution.max,
    };
  }

  static pigeon.ScanRegion _toPigeonScanRegion(ScanRegion region) {
    return pigeon.ScanRegion(
      left: region.left,
      top: region.top,
      width: region.width,
      height: region.height,
    );
  }

  static BarcodeResult _convertBarcodeResult(pigeon.BarcodeResult result) {
    final format = BarcodeFormat.fromString(result.format) ?? BarcodeFormat.qr;

    Rect? boundingBox;
    if (result.boundingBox != null) {
      final box = result.boundingBox!;
      boundingBox = Rect.fromLTRB(box.left, box.top, box.right, box.bottom);
    }

    List<Offset>? cornerPoints;
    if (result.cornerPoints != null) {
      cornerPoints = result.cornerPoints!
          .map((p) => Offset(p.x, p.y))
          .toList();
    }

    return BarcodeResult(
      value: result.value,
      format: format,
      rawBytes: result.rawBytes,
      boundingBox: boundingBox,
      cornerPoints: cornerPoints,
    );
  }

  static DocumentScanResult _convertDocumentResult(pigeon.DocumentScanResult result) {
    final pages = result.pages.map((p) => ScannedPage(
      imagePath: p.imagePath,
      width: p.width.toInt(),
      height: p.height.toInt(),
    )).toList();

    return DocumentScanResult(
      pages: pages,
      pdfPath: result.pdfPath,
    );
  }
}
