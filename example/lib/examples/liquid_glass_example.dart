import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scankit/scankit.dart';

import '../widgets/result_card.dart';

/// Example: Liquid Glass Overlay
///
/// Demonstrates the premium frosted glass overlay with subtle
/// blur effects and refined corner brackets.
class LiquidGlassExample extends StatefulWidget {
  const LiquidGlassExample({super.key});

  @override
  State<LiquidGlassExample> createState() => _LiquidGlassExampleState();
}

class _LiquidGlassExampleState extends State<LiquidGlassExample> {
  final _controller = ScanKitController();
  BarcodeResult? _result;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Frosted Glass'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
              color: _torchEnabled ? Colors.amber : Colors.white,
            ),
            tooltip: 'Toggle torch',
            onPressed: () async {
              final newState = !_torchEnabled;
              await _controller.setTorch(newState);
              setState(() => _torchEnabled = newState);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 7,
            child: ScanKitView(
              controller: _controller,
              onDetect: (result) {
                HapticFeedback.mediumImpact();
                setState(() => _result = result);
              },
              // Subtle frosted glass overlay
              overlay: const LiquidGlassOverlay(
                // Default values are already subtle
                // Uncomment below to customize:
                // accentColor: Color(0xAAFFFFFF),
                // blurStrength: 8.0,
                // overlayOpacity: 0.5,
                // cornerRadius: 12.0,
                // showScanLine: true,  // Enable for animated line
                // showPulse: true,     // Enable for pulsing glow
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade900,
              padding: const EdgeInsets.all(16),
              child: _result == null
                  ? const Center(
                      child: Text(
                        'Point camera at a barcode',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : Theme(
                      data: ThemeData.dark(),
                      child: ResultCard(result: _result!),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
