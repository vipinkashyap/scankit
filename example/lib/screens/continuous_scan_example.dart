import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scankit/scankit.dart';

/// Example: Continuous scanning (inventory use case)
///
/// Scans multiple items and adds them to a list. Useful for inventory.
class ContinuousScanExample extends StatefulWidget {
  const ContinuousScanExample({super.key});

  @override
  State<ContinuousScanExample> createState() => _ContinuousScanExampleState();
}

class _ContinuousScanExampleState extends State<ContinuousScanExample> {
  final _controller = ScanKitController(formats: BarcodeFormat.product);
  final List<BarcodeResult> _scannedItems = [];
  final Set<String> _scannedValues = {}; // Avoid duplicates
  bool _isFrontCamera = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeResult result) {
    // Only add if not already scanned
    if (!_scannedValues.contains(result.value)) {
      HapticFeedback.lightImpact();
      setState(() {
        _scannedValues.add(result.value);
        _scannedItems.insert(0, result); // Add to top
      });
    }
  }

  void _clearAll() {
    setState(() {
      _scannedItems.clear();
      _scannedValues.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Scanned: ${_scannedItems.length} items'),
        actions: [
          IconButton(
            icon: Icon(_isFrontCamera ? Icons.camera_front : Icons.camera_rear),
            tooltip: 'Switch Camera',
            onPressed: () async {
              await _controller.switchCamera();
              setState(() => _isFrontCamera = !_isFrontCamera);
            },
          ),
          if (_scannedItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
            ),
        ],
      ),
      body: Column(
        children: [
          // Smaller scanner for inventory mode
          SizedBox(
            height: 250,
            child: ScanKitView(
              controller: _controller,
              onDetect: _onDetect,
              overlay: ScanKitOverlay.corners(
                borderColor: Colors.green,
                scanAreaSize: 0.8,
              ),
            ),
          ),
          // Scanned items list
          Expanded(
            child: _scannedItems.isEmpty
                ? const Center(
                    child: Text('Scan products to add them to the list'),
                  )
                : ListView.builder(
                    itemCount: _scannedItems.length,
                    itemBuilder: (context, index) {
                      final item = _scannedItems[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${index + 1}'),
                        ),
                        title: Text(item.value),
                        subtitle: Text(item.format.name.toUpperCase()),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: item.value));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied!')),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
