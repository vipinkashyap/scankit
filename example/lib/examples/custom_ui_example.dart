import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scankit/scankit.dart';

/// Example: Custom UI (no overlay)
///
/// Full control over the UI with no default overlay.
class CustomUIExample extends StatefulWidget {
  const CustomUIExample({super.key});

  @override
  State<CustomUIExample> createState() => _CustomUIExampleState();
}

class _CustomUIExampleState extends State<CustomUIExample> {
  final _controller = ScanKitController();
  BarcodeResult? _result;
  bool _torchOn = false;
  bool _isFrontCamera = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    await _controller.toggleTorch();
    final state = await ScanKit.getTorchState();
    setState(() => _torchOn = state);
  }

  Future<void> _switchCamera() async {
    await _controller.switchCamera();
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      // Torch is not available on front camera
      if (_isFrontCamera) _torchOn = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen scanner, no overlay
          ScanKitView(
            controller: _controller,
            onDetect: (result) {
              HapticFeedback.heavyImpact();
              setState(() => _result = result);
            },
            // No overlay - completely custom UI
          ),

          // Custom top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Row(
                      children: [
                        // Camera switch button
                        IconButton(
                          icon: Icon(
                            _isFrontCamera ? Icons.camera_front : Icons.camera_rear,
                            color: Colors.white,
                          ),
                          onPressed: _switchCamera,
                        ),
                        // Torch button (only show for back camera)
                        if (!_isFrontCamera)
                          IconButton(
                            icon: Icon(
                              _torchOn ? Icons.flash_on : Icons.flash_off,
                              color: _torchOn ? Colors.yellow : Colors.white,
                            ),
                            onPressed: _toggleTorch,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Custom center crosshair
          Center(
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white30, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.center_focus_strong,
                color: Colors.white30,
                size: 40,
              ),
            ),
          ),

          // Result popup at bottom
          if (_result != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _result!.format.name.toUpperCase(),
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _result!.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _result!.value));
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy'),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _result = null),
                          icon: const Icon(Icons.close),
                          label: const Text('Dismiss'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          // Instruction text
          if (_result == null)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Text(
                'Point at a barcode\nTap to focus \u2022 Pinch to zoom',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
