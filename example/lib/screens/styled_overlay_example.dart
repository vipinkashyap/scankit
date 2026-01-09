import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scankit/scankit.dart';

import '../result_card.dart';

/// Example: Styled overlay
///
/// Shows custom colors and sizes for the scanner overlay.
class StyledOverlayExample extends StatefulWidget {
  const StyledOverlayExample({super.key});

  @override
  State<StyledOverlayExample> createState() => _StyledOverlayExampleState();
}

class _StyledOverlayExampleState extends State<StyledOverlayExample> {
  final _controller = ScanKitController();
  BarcodeResult? _result;
  bool _isFrontCamera = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Styled Overlay'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isFrontCamera ? Icons.camera_front : Icons.camera_rear),
            tooltip: 'Switch Camera',
            onPressed: () async {
              await _controller.switchCamera();
              setState(() => _isFrontCamera = !_isFrontCamera);
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
              // Custom styled overlay
              overlay: ScanKitOverlay.corners(
                borderColor: Colors.deepPurple,
                borderWidth: 4,
                cornerLength: 40,
                overlayColor: Colors.black54,
                scanAreaSize: 0.75,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.deepPurple.shade50,
              padding: const EdgeInsets.all(16),
              child: _result == null
                  ? const Center(child: Text('Scan something!'))
                  : ResultCard(result: _result!),
            ),
          ),
        ],
      ),
    );
  }
}
