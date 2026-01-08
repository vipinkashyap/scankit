/// Controller for embedded scanner widget
///
/// Provides programmatic control over the scanner including:
/// - Camera controls (torch, zoom, switch camera)
/// - Configuration updates at runtime
/// - Barcode detection streams and callbacks
/// - Validation callback for filtering results
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'barcode_format.dart';
import 'barcode_result.dart';
import 'scankit.dart';
import 'scankit_exception.dart';
import 'generated/messages.g.dart' as pigeon;

// ============================================================================
// MARK: - ScanKitController
// ============================================================================

/// Controller for the embedded ScanKitView
///
/// Manages the scanner lifecycle and provides:
/// - [barcodes] stream for continuous scanning
/// - [onDetect] callback for single-shot handling
/// - [validator] for filtering unwanted barcodes
/// - Camera controls: [toggleTorch], [switchCamera], [setZoom]
/// - Runtime config updates via [updateConfig]
///
/// ## Basic Usage
///
/// ```dart
/// final controller = ScanKitController(
///   formats: [BarcodeFormat.qr],
///   onDetect: (barcode) => print(barcode.value),
/// );
///
/// // Use with ScanKitView
/// ScanKitView(controller: controller)
///
/// // Control the scanner
/// await controller.toggleTorch();
/// await controller.setZoom(2.0);
///
/// // Don't forget to dispose
/// controller.dispose();
/// ```
class ScanKitController extends ChangeNotifier implements pigeon.ScannerFlutterApi {
  ScanKitController({
    this.formats,
    this.onDetect,
    this.onScanError,
    this.validator,
    this.cameraFacing = CameraFacing.back,
    this.resolution = CameraResolution.high,
    this.invertColors = false,
    this.scanRegion,
    this.debounceMs = 500,
    this.autoZoom = false,
  }) {
    pigeon.ScannerFlutterApi.setUp(this);
  }

  /// Barcode formats to scan for (null = all formats)
  final List<BarcodeFormat>? formats;

  /// Callback when a barcode is detected (after validation passes)
  final void Function(BarcodeResult barcode)? onDetect;

  /// Callback when an error occurs
  final void Function(ScanKitException error)? onScanError;

  /// Optional validator - return false to reject the barcode
  final bool Function(BarcodeResult barcode)? validator;

  /// Which camera to use (front or back)
  CameraFacing cameraFacing;

  /// Camera resolution preset
  CameraResolution resolution;

  /// Whether to invert colors for white-on-black barcodes
  bool invertColors;

  /// Region of interest for scanning (null = full frame)
  ScanRegion? scanRegion;

  /// Debounce delay in milliseconds between same-value detections
  int debounceMs;

  /// Whether to auto-zoom toward detected barcodes
  bool autoZoom;

  // --------------------------------------------------------------------------
  // MARK: - Private State
  // --------------------------------------------------------------------------

  final _api = pigeon.ScannerHostApi();

  final _barcodeController = StreamController<BarcodeResult>.broadcast();
  final _errorController = StreamController<ScanKitException>.broadcast();
  final _torchState = ValueNotifier<bool>(false);
  final _cameraFacingNotifier = ValueNotifier<CameraFacing>(CameraFacing.back);
  final _zoomLevel = ValueNotifier<double>(1.0);

  /// Stream of detected barcodes (after validation passes)
  Stream<BarcodeResult> get barcodes => _barcodeController.stream;

  /// Stream of errors from the scanner
  Stream<ScanKitException> get errors => _errorController.stream;

  /// Current torch state
  ValueListenable<bool> get torchState => _torchState;

  /// Current camera facing direction
  ValueListenable<CameraFacing> get cameraFacingState => _cameraFacingNotifier;

  /// Current zoom level
  ValueListenable<double> get zoomLevel => _zoomLevel;

  // --------------------------------------------------------------------------
  // MARK: - Camera Controls
  // --------------------------------------------------------------------------

  /// Toggle the torch on/off
  Future<void> toggleTorch() async {
    try {
      final newState = !_torchState.value;
      await _api.setTorch(newState);
    } on PlatformException catch (e) {
      _handleError(ScanKitException.fromPlatformException(e));
    }
  }

  /// Set torch state explicitly
  Future<void> setTorch(bool enabled) async {
    try {
      await _api.setTorch(enabled);
    } on PlatformException catch (e) {
      _handleError(ScanKitException.fromPlatformException(e));
    }
  }

  /// Check if torch is available
  Future<bool> isTorchAvailable() async {
    try {
      return await _api.isTorchAvailable();
    } on PlatformException {
      return false;
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    try {
      await _api.switchCamera();
    } on PlatformException catch (e) {
      _handleError(ScanKitException.fromPlatformException(e));
    }
  }

  /// Set zoom level (1.0 = no zoom)
  Future<void> setZoom(double zoom) async {
    try {
      await _api.setZoom(zoom);
    } on PlatformException catch (e) {
      _handleError(ScanKitException.fromPlatformException(e));
    }
  }

  // --------------------------------------------------------------------------
  // MARK: - Configuration
  // --------------------------------------------------------------------------

  /// Update scanner configuration at runtime
  Future<void> updateConfig({
    List<BarcodeFormat>? formats,
    CameraFacing? cameraFacing,
    CameraResolution? resolution,
    bool? invertColors,
    ScanRegion? scanRegion,
    int? debounceMs,
    bool? autoZoom,
  }) async {
    if (cameraFacing != null) this.cameraFacing = cameraFacing;
    if (resolution != null) this.resolution = resolution;
    if (invertColors != null) this.invertColors = invertColors;
    if (scanRegion != null) this.scanRegion = scanRegion;
    if (debounceMs != null) this.debounceMs = debounceMs;
    if (autoZoom != null) this.autoZoom = autoZoom;

    try {
      await _api.updateEmbeddedConfig(_buildConfig());
    } on PlatformException catch (e) {
      _handleError(ScanKitException.fromPlatformException(e));
    }
  }

  pigeon.EmbeddedScannerConfig _buildConfig() {
    return pigeon.EmbeddedScannerConfig(
      formats: formats?.map((f) => f.identifier).toList(),
      cameraFacing: cameraFacing == CameraFacing.front
          ? pigeon.CameraFacing.front
          : pigeon.CameraFacing.back,
      resolution: _toPigeonResolution(resolution),
      invertColors: invertColors,
      scanRegion: scanRegion != null
          ? pigeon.ScanRegion(
              left: scanRegion!.left,
              top: scanRegion!.top,
              width: scanRegion!.width,
              height: scanRegion!.height,
            )
          : null,
      debounceMs: debounceMs,
      autoZoom: autoZoom,
    );
  }

  pigeon.CameraResolution _toPigeonResolution(CameraResolution res) {
    return switch (res) {
      CameraResolution.low => pigeon.CameraResolution.low,
      CameraResolution.medium => pigeon.CameraResolution.medium,
      CameraResolution.high => pigeon.CameraResolution.high,
      CameraResolution.max => pigeon.CameraResolution.max,
    };
  }

  void _handleError(ScanKitException error) {
    _errorController.add(error);
    onScanError?.call(error);
  }

  // --------------------------------------------------------------------------
  // MARK: - Pigeon Callbacks (ScannerFlutterApi)
  // --------------------------------------------------------------------------

  @override
  void onBarcodeDetected(pigeon.BarcodeResult barcode) {
    final result = _convertResult(barcode);

    // Run validation if provided
    if (validator != null && !validator!(result)) {
      return; // Validation failed, don't emit
    }

    _barcodeController.add(result);
    onDetect?.call(result);
  }

  @override
  void onTorchStateChanged(bool enabled) {
    _torchState.value = enabled;
  }

  @override
  void onError(String code, String message) {
    final exception = ScanKitException.fromPlatformException(
      PlatformException(code: code, message: message),
    );
    _handleError(exception);
  }

  @override
  void onCameraSwitched(pigeon.CameraFacing facing) {
    final newFacing = facing == pigeon.CameraFacing.front
        ? CameraFacing.front
        : CameraFacing.back;
    cameraFacing = newFacing;
    _cameraFacingNotifier.value = newFacing;
  }

  @override
  void onZoomChanged(double zoom) {
    _zoomLevel.value = zoom;
  }

  // --------------------------------------------------------------------------
  // MARK: - Private Helpers
  // --------------------------------------------------------------------------

  BarcodeResult _convertResult(pigeon.BarcodeResult result) {
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

  @override
  void dispose() {
    _barcodeController.close();
    _errorController.close();
    _torchState.dispose();
    _cameraFacingNotifier.dispose();
    _zoomLevel.dispose();
    pigeon.ScannerFlutterApi.setUp(null);
    super.dispose();
  }
}
