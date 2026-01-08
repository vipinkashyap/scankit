/// Static scan overlay with corner brackets
///
/// Provides a customizable overlay for the scanner view with:
/// - Semi-transparent background outside the scan area
/// - Corner bracket markers to indicate the scan region
///
/// This is a static overlay without animation. For an animated version
/// with a moving scan line, see [ScanKitAnimatedOverlay].
library;

import 'package:flutter/material.dart';

/// Default overlay with corner brackets
///
/// Creates a semi-transparent overlay with a clear scan area in the center,
/// marked by corner brackets. The scan area is always square and sized
/// relative to the shorter dimension of the available space.
///
/// Example usage:
/// ```dart
/// ScanKitView(
///   overlay: const ScanKitOverlay(
///     borderColor: Colors.blue,
///     scanAreaSize: 0.8,
///   ),
///   onDetect: (barcode) => print(barcode.value),
/// )
/// ```
class ScanKitOverlay extends StatelessWidget {
  const ScanKitOverlay({
    super.key,
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.cornerLength = 30.0,
    this.overlayColor = const Color(0x80000000),
    this.scanAreaSize = 0.7,
  });

  /// Factory constructor for corner bracket overlay (same as default)
  const factory ScanKitOverlay.corners({
    Key? key,
    Color borderColor,
    double borderWidth,
    double cornerLength,
    Color overlayColor,
    double scanAreaSize,
  }) = ScanKitOverlay;

  /// Color of the corner brackets
  final Color borderColor;

  /// Width of the corner bracket lines
  final double borderWidth;

  /// Length of each corner bracket arm
  final double cornerLength;

  /// Color of the overlay outside the scan area (semi-transparent)
  final Color overlayColor;

  /// Size of the scan area as a fraction of the smaller dimension (0-1)
  ///
  /// A value of 0.7 means the scan area will be 70% of the widget's
  /// shorter side (width or height).
  final double scanAreaSize;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScanOverlayPainter(
        borderColor: borderColor,
        borderWidth: borderWidth,
        cornerLength: cornerLength,
        overlayColor: overlayColor,
        scanAreaSize: scanAreaSize,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Custom painter for the static scan overlay
class _ScanOverlayPainter extends CustomPainter {
  _ScanOverlayPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.cornerLength,
    required this.overlayColor,
    required this.scanAreaSize,
  });

  final Color borderColor;
  final double borderWidth;
  final double cornerLength;
  final Color overlayColor;
  final double scanAreaSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    // Calculate scan area (square, centered)
    final scanSize = size.shortestSide * scanAreaSize;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);

    // Draw overlay with hole (even-odd fill)
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanRect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    // Draw corner brackets
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    _drawCornerBrackets(canvas, scanRect, cornerPaint);
  }

  void _drawCornerBrackets(Canvas canvas, Rect scanRect, Paint paint) {
    // Top-left corner
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top + cornerLength),
      Offset(scanRect.left, scanRect.top),
      paint,
    );
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top),
      Offset(scanRect.left + cornerLength, scanRect.top),
      paint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(scanRect.right - cornerLength, scanRect.top),
      Offset(scanRect.right, scanRect.top),
      paint,
    );
    canvas.drawLine(
      Offset(scanRect.right, scanRect.top),
      Offset(scanRect.right, scanRect.top + cornerLength),
      paint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom - cornerLength),
      Offset(scanRect.left, scanRect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom),
      Offset(scanRect.left + cornerLength, scanRect.bottom),
      paint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(scanRect.right - cornerLength, scanRect.bottom),
      Offset(scanRect.right, scanRect.bottom),
      paint,
    );
    canvas.drawLine(
      Offset(scanRect.right, scanRect.bottom),
      Offset(scanRect.right, scanRect.bottom - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.scanAreaSize != scanAreaSize;
  }
}
