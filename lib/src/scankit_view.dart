/// Embedded scanner widget for ScanKit
///
/// Provides a platform view that displays the camera preview with
/// barcode scanning capabilities. Can be embedded anywhere in your
/// widget tree.
///
/// For overlays, see [ScanKitOverlay] and [ScanKitAnimatedOverlay].
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'barcode_format.dart';
import 'barcode_result.dart';
import 'scankit_controller.dart';

// Re-export overlays for convenience
export 'overlay/scan_overlay.dart';
export 'overlay/animated_overlay.dart';
export 'overlay/liquid_glass_overlay.dart';

const String _viewType = 'dev.scankit/scanner';

/// Embedded barcode scanner widget
///
/// Displays a camera preview with real-time barcode scanning. Can be
/// embedded anywhere in your widget tree, unlike the full-screen
/// [ScanKit.scan()] which takes over the entire screen.
///
/// ## Basic Usage
///
/// ```dart
/// ScanKitView(
///   onDetect: (barcode) {
///     print('Scanned: ${barcode.value}');
///   },
/// )
/// ```
///
/// ## With Custom Overlay
///
/// ```dart
/// ScanKitView(
///   overlay: const ScanKitAnimatedOverlay(
///     borderColor: Colors.blue,
///   ),
///   onDetect: (barcode) => handleBarcode(barcode),
/// )
/// ```
///
/// ## With Controller
///
/// ```dart
/// final controller = ScanKitController(
///   formats: [BarcodeFormat.qr],
///   onDetect: (barcode) => handleBarcode(barcode),
/// );
///
/// ScanKitView(
///   controller: controller,
///   overlay: const ScanKitOverlay(),
/// )
///
/// // Later: controller.toggleTorch(), controller.switchCamera(), etc.
/// ```
class ScanKitView extends StatefulWidget {
  const ScanKitView({
    super.key,
    this.controller,
    this.onDetect,
    this.formats,
    this.overlay,
    this.onCreated,
  });

  /// Controller for the scanner (optional - created internally if not provided)
  ///
  /// If provided, you're responsible for disposing it. If not provided,
  /// an internal controller is created and disposed automatically.
  final ScanKitController? controller;

  /// Callback when a barcode is detected
  ///
  /// This is a convenience callback. You can also use [controller.barcodes]
  /// stream or [controller.onDetect] for the same purpose.
  final void Function(BarcodeResult barcode)? onDetect;

  /// Barcode formats to scan for (null = all formats)
  ///
  /// Only used when [controller] is not provided. Otherwise, use
  /// [ScanKitController.formats].
  final List<BarcodeFormat>? formats;

  /// Custom overlay widget to display on top of the camera preview
  ///
  /// Built-in options:
  /// - [ScanKitOverlay] - Static corner brackets
  /// - [ScanKitAnimatedOverlay] - Animated scan line with corners
  ///
  /// Or provide any custom widget.
  final Widget? overlay;

  /// Callback when the scanner view is created and ready
  final VoidCallback? onCreated;

  @override
  State<ScanKitView> createState() => _ScanKitViewState();
}

class _ScanKitViewState extends State<ScanKitView> {
  late ScanKitController _controller;
  bool _ownsController = false;
  StreamSubscription<BarcodeResult>? _subscription;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      // When external controller is provided, listen to its barcode stream
      // to forward detections to the widget's onDetect callback
      if (widget.onDetect != null) {
        _subscription = _controller.barcodes.listen(widget.onDetect);
      }
    } else {
      _controller = ScanKitController(
        formats: widget.formats,
        onDetect: widget.onDetect,
      );
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildPlatformView(),
        if (widget.overlay != null)
          // IgnorePointer allows touch events to pass through to the camera
          // for tap-to-focus and pinch-to-zoom functionality
          IgnorePointer(child: widget.overlay!),
      ],
    );
  }

  Widget _buildPlatformView() {
    final creationParams = <String, dynamic>{
      'formats': widget.formats?.map((f) => f.identifier).toList(),
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: _viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      case TargetPlatform.android:
        // Use standard AndroidView - the native PreviewView is configured to use
        // TextureView (COMPATIBLE mode) which works better with Flutter's composition.
        // The IgnorePointer wrapper on overlays allows touch events to reach the camera.
        return AndroidView(
          viewType: _viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        );
      default:
        return const Center(
          child: Text('ScanKit is only supported on iOS and Android'),
        );
    }
  }

  void _onPlatformViewCreated(int id) {
    widget.onCreated?.call();
  }
}
