import 'package:flutter/material.dart';
import 'package:scankit/scankit.dart';

import '../widgets/result_card.dart';

/// Example: Gallery scan
///
/// Pick an image from the gallery and detect barcodes in it.
class GalleryScanExample extends StatefulWidget {
  const GalleryScanExample({super.key});

  @override
  State<GalleryScanExample> createState() => _GalleryScanExampleState();
}

class _GalleryScanExampleState extends State<GalleryScanExample> {
  BarcodeResult? _result;
  bool _loading = false;

  Future<void> _scanFromGallery() async {
    setState(() => _loading = true);

    try {
      final result = await ScanKit.scanFromGallery();

      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });

        if (result == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No barcode found in image')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan from Gallery')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_result != null) ...[
                ResultCard(result: _result!),
                const SizedBox(height: 24),
              ],
              FilledButton.icon(
                onPressed: _loading ? null : _scanFromGallery,
                icon: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library),
                label: Text(_loading ? 'Scanning...' : 'Pick from Gallery'),
              ),
              const SizedBox(height: 16),
              Text(
                'Pick an image containing a barcode.\nWorks with screenshots, photos, etc.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
