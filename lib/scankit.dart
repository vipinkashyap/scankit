/// ScanKit - Modern barcode and QR code scanner for Flutter
///
/// A native-first barcode scanner using VisionKit on iOS and ML Kit on Android.
/// Supports both embedded and full-screen scanning modes.
///
/// ## Quick Start
///
/// One-shot scan (opens full-screen scanner):
/// ```dart
/// final result = await ScanKit.scan();
/// if (result != null) {
///   print('Scanned: ${result.value}');
/// }
/// ```
///
/// Embedded scanner widget:
/// ```dart
/// ScanKitView(
///   onDetect: (barcode) => print(barcode.value),
///   overlay: const ScanKitOverlay.corners(),
/// )
/// ```
///
/// Document scanning:
/// ```dart
/// final result = await ScanKit.scanDocument();
/// if (result != null) {
///   print('Scanned ${result.pageCount} pages');
/// }
/// ```
library;

export 'src/scankit.dart';
export 'src/barcode_format.dart';
export 'src/barcode_result.dart';
export 'src/document_result.dart';
export 'src/scankit_controller.dart';
export 'src/scankit_exception.dart';
export 'src/scankit_view.dart';
// Overlays are re-exported from scankit_view.dart
