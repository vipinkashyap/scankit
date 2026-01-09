import 'package:flutter/material.dart';
import 'package:scankit/scankit.dart';

import '../result_card.dart';

/// Example: Basic embedded scanner
///
/// Shows the scanner widget embedded in your UI with a default overlay.
class BasicEmbeddedExample extends StatefulWidget {
  const BasicEmbeddedExample({super.key});

  @override
  State<BasicEmbeddedExample> createState() => _BasicEmbeddedExampleState();
}

class _BasicEmbeddedExampleState extends State<BasicEmbeddedExample> {
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
        title: const Text('Basic Embedded'),
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
          // Scanner takes 60% of screen
          Expanded(
            flex: 6,
            child: ScanKitView(
              controller: _controller,
              onDetect: (result) {
                setState(() => _result = result);
              },
              // Default overlay with corner brackets
              overlay: ScanKitOverlay.corners(),
            ),
          ),
          // Results area
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              color: Colors.grey.shade100,
              padding: const EdgeInsets.all(16),
              child: _result == null
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.qr_code_scanner, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Point camera at a barcode'),
                          SizedBox(height: 4),
                          Text(
                            'Tap to focus \u2022 Pinch to zoom',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ResultCard(result: _result!),
            ),
          ),
        ],
      ),
    );
  }
}
