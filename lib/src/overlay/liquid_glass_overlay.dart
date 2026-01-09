/// Liquid Glass overlay with iOS-inspired frosted glass aesthetic
///
/// Provides a premium scanner overlay with:
/// - Frosted glass blur effect on the masked areas
/// - Smooth rounded corner brackets with subtle glow
/// - Animated pulse effect on the scan area border
/// - Optional animated scan line
/// - Built-in control buttons (close, torch) with glass morphism
///
/// This overlay provides a consistent, polished look across both
/// iOS and Android platforms.
library;

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium liquid glass overlay with iOS-inspired design
///
/// Creates a frosted glass effect with smooth animations and
/// refined visual details that look great on both platforms.
///
/// ## Basic Usage
/// ```dart
/// ScanKitView(
///   overlay: const LiquidGlassOverlay(),
///   onDetect: (barcode) => print(barcode.value),
/// )
/// ```
///
/// ## With Controls
/// ```dart
/// LiquidGlassOverlay(
///   showCloseButton: true,
///   showTorchButton: true,
///   onClose: () => Navigator.pop(context),
///   onTorchToggle: (isOn) => controller.setTorch(isOn),
/// )
/// ```
///
/// ## Customization
/// ```dart
/// LiquidGlassOverlay(
///   accentColor: Colors.cyan,
///   scanAreaSize: 0.75,
///   blurStrength: 15.0,
///   showScanLine: true,
///   cornerRadius: 24.0,
/// )
/// ```
class LiquidGlassOverlay extends StatefulWidget {
  const LiquidGlassOverlay({
    super.key,
    this.accentColor = const Color(0xCCFFFFFF), // Subtle white (80% opacity)
    this.scanAreaSize = 0.7,
    this.blurStrength = 8.0,
    this.overlayOpacity = 0.5,
    this.cornerLength = 35.0,
    this.cornerRadius = 12.0,
    this.borderWidth = 2.5,
    this.showScanLine = false, // Disabled by default for cleaner look
    this.showPulse = false, // Disabled by default for subtlety
    this.scanLineDuration = const Duration(seconds: 3),
    this.pulseDuration = const Duration(milliseconds: 2000),
    this.showCloseButton = false,
    this.showTorchButton = false,
    this.torchEnabled = false,
    this.onClose,
    this.onTorchToggle,
    this.hint,
  });

  /// Primary accent color for borders, scan line, and highlights
  final Color accentColor;

  /// Size of the scan area as a fraction of the smaller dimension (0-1)
  final double scanAreaSize;

  /// Blur strength for the frosted glass effect (0-30)
  final double blurStrength;

  /// Opacity of the dark overlay (0-1)
  final double overlayOpacity;

  /// Length of each corner bracket arm
  final double cornerLength;

  /// Radius of the rounded corners
  final double cornerRadius;

  /// Width of the corner bracket lines
  final double borderWidth;

  /// Whether to show the animated scan line
  final bool showScanLine;

  /// Whether to show the pulsing glow effect on the border
  final bool showPulse;

  /// Duration for one complete scan line animation cycle
  final Duration scanLineDuration;

  /// Duration for one complete pulse animation cycle
  final Duration pulseDuration;

  /// Whether to show the close button (top-left)
  final bool showCloseButton;

  /// Whether to show the torch toggle button (top-right)
  final bool showTorchButton;

  /// Current torch state
  final bool torchEnabled;

  /// Callback when close button is pressed
  final VoidCallback? onClose;

  /// Callback when torch button is toggled
  final ValueChanged<bool>? onTorchToggle;

  /// Optional hint text to display below the scan area
  final String? hint;

  @override
  State<LiquidGlassOverlay> createState() => _LiquidGlassOverlayState();
}

class _LiquidGlassOverlayState extends State<LiquidGlassOverlay>
    with TickerProviderStateMixin {
  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late Animation<double> _scanLineAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _scanLineController = AnimationController(
      vsync: this,
      duration: widget.scanLineDuration,
    );
    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    if (widget.showScanLine) {
      _scanLineController.repeat(reverse: true);
    }

    _pulseController = AnimationController(
      vsync: this,
      duration: widget.pulseDuration,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.showPulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(LiquidGlassOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.showScanLine != oldWidget.showScanLine) {
      if (widget.showScanLine) {
        _scanLineController.repeat(reverse: true);
      } else {
        _scanLineController.stop();
      }
    }

    if (widget.showPulse != oldWidget.showPulse) {
      if (widget.showPulse) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Frosted glass overlay with scan area cutout
        AnimatedBuilder(
          animation: Listenable.merge([_scanLineAnimation, _pulseAnimation]),
          builder: (context, child) {
            return CustomPaint(
              painter: _LiquidGlassPainter(
                accentColor: widget.accentColor,
                scanAreaSize: widget.scanAreaSize,
                overlayOpacity: widget.overlayOpacity,
                cornerLength: widget.cornerLength,
                cornerRadius: widget.cornerRadius,
                borderWidth: widget.borderWidth,
                scanLinePosition:
                    widget.showScanLine ? _scanLineAnimation.value : null,
                pulseValue: widget.showPulse ? _pulseAnimation.value : 0.0,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),

        // Blur effect layer (applied to areas outside scan region)
        if (widget.blurStrength > 0) _buildBlurLayer(),

        // Control buttons
        if (widget.showCloseButton || widget.showTorchButton)
          _buildControlButtons(),

        // Hint text
        if (widget.hint != null) _buildHint(),
      ],
    );
  }

  Widget _buildBlurLayer() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final scanSize = size.shortestSide * widget.scanAreaSize;
        final left = (size.width - scanSize) / 2;
        final top = (size.height - scanSize) / 2;

        return Stack(
          children: [
            // Top blur region
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: top,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blurStrength,
                    sigmaY: widget.blurStrength,
                  ),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Bottom blur region
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: top,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blurStrength,
                    sigmaY: widget.blurStrength,
                  ),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Left blur region
            Positioned(
              top: top,
              left: 0,
              width: left,
              height: scanSize,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blurStrength,
                    sigmaY: widget.blurStrength,
                  ),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            // Right blur region
            Positioned(
              top: top,
              right: 0,
              width: left,
              height: scanSize,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.blurStrength,
                    sigmaY: widget.blurStrength,
                  ),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showCloseButton)
              _GlassButton(
                icon: Icons.close_rounded,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onClose?.call();
                },
              )
            else
              const SizedBox(width: 48),
            if (widget.showTorchButton)
              _GlassButton(
                icon: widget.torchEnabled
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                isActive: widget.torchEnabled,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onTorchToggle?.call(!widget.torchEnabled);
                },
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildHint() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Text(
            widget.hint!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass morphism button for overlay controls
class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.yellow : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for the liquid glass overlay
class _LiquidGlassPainter extends CustomPainter {
  _LiquidGlassPainter({
    required this.accentColor,
    required this.scanAreaSize,
    required this.overlayOpacity,
    required this.cornerLength,
    required this.cornerRadius,
    required this.borderWidth,
    this.scanLinePosition,
    this.pulseValue = 0.0,
  });

  final Color accentColor;
  final double scanAreaSize;
  final double overlayOpacity;
  final double cornerLength;
  final double cornerRadius;
  final double borderWidth;
  final double? scanLinePosition;
  final double pulseValue;

  @override
  void paint(Canvas canvas, Size size) {
    final scanSize = size.shortestSide * scanAreaSize;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;
    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, scanSize, scanSize),
      Radius.circular(cornerRadius),
    );

    // Draw dark overlay with rounded cutout
    _drawOverlay(canvas, size, scanRect);

    // Draw pulsing glow
    if (pulseValue > 0) {
      _drawPulseGlow(canvas, scanRect);
    }

    // Draw rounded corner brackets
    _drawCornerBrackets(canvas, scanRect);

    // Draw scan line
    if (scanLinePosition != null) {
      _drawScanLine(canvas, scanRect);
    }
  }

  void _drawOverlay(Canvas canvas, Size size, RRect scanRect) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: overlayOpacity)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(scanRect);
    path.fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);
  }

  void _drawPulseGlow(Canvas canvas, RRect scanRect) {
    // Subtle pulse - reduced opacity and smaller expansion
    final glowOpacity = 0.15 * pulseValue;
    final glowWidth = borderWidth + (2 * pulseValue);

    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: glowOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = glowWidth
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawRRect(scanRect, glowPaint);
  }

  void _drawCornerBrackets(Canvas canvas, RRect scanRect) {
    final paint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final rect = scanRect.outerRect;
    final radius = cornerRadius;

    // Top-left corner
    final topLeftPath = Path()
      ..moveTo(rect.left, rect.top + cornerLength)
      ..lineTo(rect.left, rect.top + radius)
      ..arcToPoint(
        Offset(rect.left + radius, rect.top),
        radius: Radius.circular(radius),
      )
      ..lineTo(rect.left + cornerLength, rect.top);
    canvas.drawPath(topLeftPath, paint);

    // Top-right corner
    final topRightPath = Path()
      ..moveTo(rect.right - cornerLength, rect.top)
      ..lineTo(rect.right - radius, rect.top)
      ..arcToPoint(
        Offset(rect.right, rect.top + radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(rect.right, rect.top + cornerLength);
    canvas.drawPath(topRightPath, paint);

    // Bottom-left corner
    final bottomLeftPath = Path()
      ..moveTo(rect.left, rect.bottom - cornerLength)
      ..lineTo(rect.left, rect.bottom - radius)
      ..arcToPoint(
        Offset(rect.left + radius, rect.bottom),
        radius: Radius.circular(radius),
      )
      ..lineTo(rect.left + cornerLength, rect.bottom);
    canvas.drawPath(bottomLeftPath, paint);

    // Bottom-right corner
    final bottomRightPath = Path()
      ..moveTo(rect.right - cornerLength, rect.bottom)
      ..lineTo(rect.right - radius, rect.bottom)
      ..arcToPoint(
        Offset(rect.right, rect.bottom - radius),
        radius: Radius.circular(radius),
        clockwise: false,
      )
      ..lineTo(rect.right, rect.bottom - cornerLength);
    canvas.drawPath(bottomRightPath, paint);
  }

  void _drawScanLine(Canvas canvas, RRect scanRect) {
    final rect = scanRect.outerRect;
    final padding = rect.height * 0.1;
    final availableHeight = rect.height - (padding * 2);
    final lineY = rect.top + padding + (availableHeight * scanLinePosition!);

    final horizontalPadding = rect.width * 0.1;
    final lineLeft = rect.left + horizontalPadding;
    final lineRight = rect.right - horizontalPadding;

    // Subtle gradient glow above the line
    final gradientHeight = 25.0;
    final gradientPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentColor.withValues(alpha: 0.0),
          accentColor.withValues(alpha: 0.08),
        ],
      ).createShader(
        Rect.fromLTRB(lineLeft, lineY - gradientHeight, lineRight, lineY),
      );

    canvas.drawRect(
      Rect.fromLTRB(
        lineLeft,
        math.max(lineY - gradientHeight, rect.top + padding),
        lineRight,
        lineY,
      ),
      gradientPaint,
    );

    // Main scan line with subtle glow
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawLine(
      Offset(lineLeft, lineY),
      Offset(lineRight, lineY),
      glowPaint,
    );

    // Crisp scan line
    final linePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(lineLeft, lineY),
      Offset(lineRight, lineY),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassPainter oldDelegate) {
    return oldDelegate.scanLinePosition != scanLinePosition ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.scanAreaSize != scanAreaSize ||
        oldDelegate.overlayOpacity != overlayOpacity ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.borderWidth != borderWidth;
  }
}
