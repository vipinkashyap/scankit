/// Animated scan overlay with moving scan line
///
/// Provides a scanner overlay with:
/// - Corner bracket markers
/// - Animated scan line that moves up and down
/// - Optional gradient glow effect around the scan line
///
/// The animation provides visual feedback that scanning is active.
library;

import 'package:flutter/material.dart';

/// Animated overlay with moving scan line effect
///
/// This overlay combines corner brackets with an animated scan line
/// that moves up and down within the scan area, providing visual
/// feedback that scanning is active.
///
/// Example usage:
/// ```dart
/// ScanKitView(
///   overlay: const ScanKitAnimatedOverlay(),
///   onDetect: (barcode) => print(barcode.value),
/// )
/// ```
///
/// Customization:
/// ```dart
/// ScanKitAnimatedOverlay(
///   borderColor: Colors.blue,
///   scanLineColor: Colors.blue,
///   animationDuration: const Duration(seconds: 3),
///   showGradient: true,
/// )
/// ```
class ScanKitAnimatedOverlay extends StatefulWidget {
  const ScanKitAnimatedOverlay({
    super.key,
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.cornerLength = 30.0,
    this.overlayColor = const Color(0x80000000),
    this.scanAreaSize = 0.7,
    this.scanLineColor,
    this.scanLineWidth = 2.0,
    this.animationDuration = const Duration(seconds: 2),
    this.showGradient = true,
  });

  /// Color of the corner brackets
  final Color borderColor;

  /// Width of the corner bracket lines
  final double borderWidth;

  /// Length of each corner bracket arm
  final double cornerLength;

  /// Color of the overlay outside the scan area
  final Color overlayColor;

  /// Size of the scan area as a fraction of the smaller dimension (0-1)
  final double scanAreaSize;

  /// Color of the scan line (defaults to [borderColor] if null)
  final Color? scanLineColor;

  /// Width of the scan line
  final double scanLineWidth;

  /// Duration for one complete scan animation cycle (up and down)
  final Duration animationDuration;

  /// Whether to show a gradient glow effect around the scan line
  final bool showGradient;

  @override
  State<ScanKitAnimatedOverlay> createState() => _ScanKitAnimatedOverlayState();
}

class _ScanKitAnimatedOverlayState extends State<ScanKitAnimatedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    // Create a smooth back-and-forth animation
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          painter: _AnimatedScanOverlayPainter(
            borderColor: widget.borderColor,
            borderWidth: widget.borderWidth,
            cornerLength: widget.cornerLength,
            overlayColor: widget.overlayColor,
            scanAreaSize: widget.scanAreaSize,
            scanLineColor: widget.scanLineColor ?? widget.borderColor,
            scanLineWidth: widget.scanLineWidth,
            scanLinePosition: _animation.value,
            showGradient: widget.showGradient,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

/// Custom painter for the animated scan overlay
class _AnimatedScanOverlayPainter extends CustomPainter {
  _AnimatedScanOverlayPainter({
    required this.borderColor,
    required this.borderWidth,
    required this.cornerLength,
    required this.overlayColor,
    required this.scanAreaSize,
    required this.scanLineColor,
    required this.scanLineWidth,
    required this.scanLinePosition,
    required this.showGradient,
  });

  final Color borderColor;
  final double borderWidth;
  final double cornerLength;
  final Color overlayColor;
  final double scanAreaSize;
  final Color scanLineColor;
  final double scanLineWidth;
  final double scanLinePosition; // 0.0 to 1.0
  final bool showGradient;

  @override
  void paint(Canvas canvas, Size size) {
    final scanSize = size.shortestSide * scanAreaSize;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);

    // Draw overlay with hole
    _drawOverlay(canvas, size, scanRect);

    // Draw corner brackets
    _drawCornerBrackets(canvas, scanRect);

    // Draw animated scan line
    _drawScanLine(canvas, scanRect);
  }

  void _drawOverlay(Canvas canvas, Size size, Rect scanRect) {
    final overlayPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(scanRect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);
  }

  void _drawCornerBrackets(Canvas canvas, Rect scanRect) {
    final cornerPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top + cornerLength),
      Offset(scanRect.left, scanRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left, scanRect.top),
      Offset(scanRect.left + cornerLength, scanRect.top),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(scanRect.right - cornerLength, scanRect.top),
      Offset(scanRect.right, scanRect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right, scanRect.top),
      Offset(scanRect.right, scanRect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom - cornerLength),
      Offset(scanRect.left, scanRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.left, scanRect.bottom),
      Offset(scanRect.left + cornerLength, scanRect.bottom),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(scanRect.right - cornerLength, scanRect.bottom),
      Offset(scanRect.right, scanRect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(scanRect.right, scanRect.bottom),
      Offset(scanRect.right, scanRect.bottom - cornerLength),
      cornerPaint,
    );
  }

  void _drawScanLine(Canvas canvas, Rect scanRect) {
    // Calculate scan line Y position with padding from edges
    final padding = scanRect.height * 0.05;
    final availableHeight = scanRect.height - (padding * 2);
    final lineY = scanRect.top + padding + (availableHeight * scanLinePosition);

    // Horizontal padding for the scan line
    final horizontalPadding = scanRect.width * 0.05;
    final lineLeft = scanRect.left + horizontalPadding;
    final lineRight = scanRect.right - horizontalPadding;

    if (showGradient) {
      _drawGradientGlow(canvas, scanRect, lineY, lineLeft, lineRight);
    }

    // Draw the main scan line
    final linePaint = Paint()
      ..color = scanLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = scanLineWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(lineLeft, lineY),
      Offset(lineRight, lineY),
      linePaint,
    );
  }

  void _drawGradientGlow(
    Canvas canvas,
    Rect scanRect,
    double lineY,
    double lineLeft,
    double lineRight,
  ) {
    const gradientHeight = 30.0;

    // Gradient above the line
    final gradientAbovePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scanLineColor.withValues(alpha: 0.0),
          scanLineColor.withValues(alpha: 0.3),
        ],
      ).createShader(
        Rect.fromLTRB(lineLeft, lineY - gradientHeight, lineRight, lineY),
      );

    canvas.drawRect(
      Rect.fromLTRB(
        lineLeft,
        (lineY - gradientHeight).clamp(scanRect.top, scanRect.bottom),
        lineRight,
        lineY,
      ),
      gradientAbovePaint,
    );

    // Gradient below the line
    final gradientBelowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          scanLineColor.withValues(alpha: 0.3),
          scanLineColor.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromLTRB(lineLeft, lineY, lineRight, lineY + gradientHeight),
      );

    canvas.drawRect(
      Rect.fromLTRB(
        lineLeft,
        lineY,
        lineRight,
        (lineY + gradientHeight).clamp(scanRect.top, scanRect.bottom),
      ),
      gradientBelowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AnimatedScanOverlayPainter oldDelegate) {
    return oldDelegate.scanLinePosition != scanLinePosition ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.scanAreaSize != scanAreaSize ||
        oldDelegate.scanLineColor != scanLineColor ||
        oldDelegate.scanLineWidth != scanLineWidth ||
        oldDelegate.showGradient != showGradient;
  }
}
