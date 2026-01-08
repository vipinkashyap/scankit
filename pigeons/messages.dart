import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/generated/messages.g.dart',
  kotlinOut: 'android/src/main/kotlin/dev/scankit/scankit/Messages.g.kt',
  kotlinOptions: KotlinOptions(package: 'dev.scankit.scankit'),
  swiftOut: 'ios/Classes/Messages.g.swift',
  swiftOptions: SwiftOptions(),
))

/// Bounding box of a detected barcode (normalized 0-1 coordinates)
class BoundingBox {
  BoundingBox({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
}

/// Corner point of a barcode (normalized 0-1 coordinates)
class Point {
  Point({required this.x, required this.y});
  final double x;
  final double y;
}

/// Represents a scanned barcode result
class BarcodeResult {
  BarcodeResult({
    required this.value,
    required this.format,
    this.rawBytes,
    this.boundingBox,
    this.cornerPoints,
  });

  /// The decoded string value of the barcode
  final String value;

  /// The format of the barcode (e.g., "qr", "ean13", "code128")
  final String format;

  /// Raw bytes of the barcode (if available)
  final Uint8List? rawBytes;

  /// Bounding box of the barcode (normalized 0-1 coordinates)
  final BoundingBox? boundingBox;

  /// Corner points of the barcode (normalized 0-1 coordinates)
  final List<Point>? cornerPoints;
}

/// Camera facing direction
enum CameraFacing {
  back,
  front,
}

/// Camera resolution preset
enum CameraResolution {
  low,      // 480p
  medium,   // 720p
  high,     // 1080p
  max,      // Highest available
}

/// Scan region (normalized 0-1 coordinates, relative to view)
class ScanRegion {
  ScanRegion({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

/// Configuration for the scanner
class ScannerConfig {
  ScannerConfig({
    this.formats,
    this.beepOnScan = false,
    this.vibrateOnScan = true,
    this.showTorchButton = true,
    this.cameraFacing = CameraFacing.back,
    this.resolution = CameraResolution.high,
    this.invertColors = false,
    this.scanRegion,
  });

  /// List of barcode formats to scan for. Null means all formats.
  final List<String>? formats;

  /// Whether to play a beep sound on successful scan
  final bool beepOnScan;

  /// Whether to vibrate on successful scan
  final bool vibrateOnScan;

  /// Whether to show torch toggle button in the scanner UI
  final bool showTorchButton;

  /// Which camera to use (front or back)
  final CameraFacing cameraFacing;

  /// Camera resolution preset
  final CameraResolution resolution;

  /// Whether to invert colors for scanning white-on-black barcodes
  final bool invertColors;

  /// Region of interest for scanning (null = full frame)
  final ScanRegion? scanRegion;
}

/// Configuration for embedded scanner view
class EmbeddedScannerConfig {
  EmbeddedScannerConfig({
    this.formats,
    this.cameraFacing = CameraFacing.back,
    this.resolution = CameraResolution.high,
    this.invertColors = false,
    this.scanRegion,
    this.debounceMs = 500,
    this.autoZoom = false,
  });

  /// List of barcode formats to scan for. Null means all formats.
  final List<String>? formats;

  /// Which camera to use (front or back)
  final CameraFacing cameraFacing;

  /// Camera resolution preset
  final CameraResolution resolution;

  /// Whether to invert colors for scanning white-on-black barcodes
  final bool invertColors;

  /// Region of interest for scanning (null = full frame)
  final ScanRegion? scanRegion;

  /// Debounce delay in milliseconds between same-value detections
  final int debounceMs;

  /// Whether to auto-zoom toward detected barcodes
  final bool autoZoom;
}

/// Configuration for document scanning
class DocumentScanConfig {
  DocumentScanConfig({
    this.maxPages,
    this.allowGalleryImport = true,
  });

  /// Maximum number of pages to scan (null = unlimited)
  final int? maxPages;

  /// Whether to allow importing from photo gallery
  final bool allowGalleryImport;
}

/// Represents a scanned document page
class ScannedPage {
  ScannedPage({
    required this.imagePath,
    required this.width,
    required this.height,
  });

  /// Path to the scanned image file
  final String imagePath;

  /// Width of the image in pixels
  final int width;

  /// Height of the image in pixels
  final int height;
}

/// Result of document scanning
class DocumentScanResult {
  DocumentScanResult({
    required this.pages,
    this.pdfPath,
  });

  /// List of scanned pages
  final List<ScannedPage> pages;

  /// Path to combined PDF (if generated)
  final String? pdfPath;
}

/// Host API - methods called from Dart to native
@HostApi()
abstract class ScannerHostApi {
  /// Opens the scanner and returns the scanned barcode, or null if cancelled
  @async
  BarcodeResult? startScan(ScannerConfig config);

  /// Checks if the device supports barcode scanning
  bool isSupported();

  /// Checks if torch/flash is available
  bool isTorchAvailable();

  /// Sets the torch state for the embedded scanner
  void setTorch(bool enabled);

  /// Gets current torch state
  bool getTorchState();

  /// Checks if document scanning is supported
  bool isDocumentScanSupported();

  /// Opens the document scanner and returns scanned pages, or null if cancelled
  @async
  DocumentScanResult? startDocumentScan(DocumentScanConfig config);

  /// Scans barcode from an image file path
  @async
  BarcodeResult? scanFromImagePath(String imagePath, List<String>? formats);

  /// Opens gallery to pick an image and scan barcode from it
  @async
  BarcodeResult? scanFromGallery(List<String>? formats);

  /// Pre-initializes the scanner for faster startup
  void warmUp();

  /// Updates embedded scanner configuration at runtime
  void updateEmbeddedConfig(EmbeddedScannerConfig config);

  /// Switches camera (front/back) on embedded scanner
  void switchCamera();

  /// Sets zoom level (1.0 = no zoom)
  void setZoom(double zoom);
}

/// Flutter API - methods called from native to Dart (for streaming results)
@FlutterApi()
abstract class ScannerFlutterApi {
  /// Called when a barcode is detected in embedded scanner mode
  void onBarcodeDetected(BarcodeResult barcode);

  /// Called when torch state changes
  void onTorchStateChanged(bool enabled);

  /// Called when an error occurs
  void onError(String code, String message);

  /// Called when camera is switched
  void onCameraSwitched(CameraFacing facing);

  /// Called when zoom level changes
  void onZoomChanged(double zoom);
}
