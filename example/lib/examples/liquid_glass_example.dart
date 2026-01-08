import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scankit/scankit.dart';

/// Example: Liquid Glass UI
///
/// Demonstrates the premium iOS-inspired liquid glass overlay
/// with frosted blur effect, animated scan line, and glass morphism buttons.
class LiquidGlassExample extends StatefulWidget {
  const LiquidGlassExample({super.key});

  @override
  State<LiquidGlassExample> createState() => _LiquidGlassExampleState();
}

class _LiquidGlassExampleState extends State<LiquidGlassExample> {
  final _controller = ScanKitController();
  BarcodeResult? _result;
  bool _torchEnabled = false;
  Color _accentColor = Colors.white;

  // Color options for customization
  final _colorOptions = [
    Colors.white,
    Colors.cyan,
    Colors.blue,
    Colors.purple,
    Colors.green,
    Colors.amber,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeResult result) {
    HapticFeedback.mediumImpact();
    setState(() => _result = result);

    // Show result in bottom sheet
    _showResultSheet(result);
  }

  void _showResultSheet(BarcodeResult result) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.format.name.toUpperCase(),
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.white54),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              result.value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue Scanning',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Liquid Glass',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // Color picker
          PopupMenuButton<Color>(
            icon: Icon(Icons.palette_rounded, color: _accentColor),
            tooltip: 'Change accent color',
            onSelected: (color) => setState(() => _accentColor = color),
            itemBuilder: (context) => _colorOptions.map((color) {
              return PopupMenuItem(
                value: color,
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == _accentColor
                              ? Colors.white
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _colorName(color),
                      style: TextStyle(
                        fontWeight: color == _accentColor
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner with liquid glass overlay
          ScanKitView(
            controller: _controller,
            onDetect: _handleDetection,
            overlay: LiquidGlassOverlay(
              accentColor: _accentColor,
              scanAreaSize: 0.7,
              blurStrength: 12.0,
              overlayOpacity: 0.5,
              cornerRadius: 20.0,
              cornerLength: 45.0,
              borderWidth: 3.0,
              showScanLine: true,
              showPulse: true,
              showCloseButton: false, // Using AppBar instead
              showTorchButton: true,
              torchEnabled: _torchEnabled,
              onTorchToggle: (enabled) async {
                await _controller.setTorch(enabled);
                setState(() => _torchEnabled = enabled);
              },
              hint: 'Align QR code or barcode within the frame',
            ),
          ),

          // Last result indicator (top)
          if (_result != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () => _showResultSheet(_result!),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: _accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _result!.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _colorName(Color color) {
    if (color == Colors.white) return 'White';
    if (color == Colors.cyan) return 'Cyan';
    if (color == Colors.blue) return 'Blue';
    if (color == Colors.purple) return 'Purple';
    if (color == Colors.green) return 'Green';
    if (color == Colors.amber) return 'Amber';
    return 'Custom';
  }
}
