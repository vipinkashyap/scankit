import 'package:flutter/material.dart';
import 'package:scankit/scankit.dart';

import '../widgets/result_card.dart';

/// Example: Product barcode scan
///
/// Scans product barcodes: EAN-8, EAN-13, UPC-A, UPC-E.
class ProductBarcodeExample extends StatefulWidget {
  const ProductBarcodeExample({super.key});

  @override
  State<ProductBarcodeExample> createState() => _ProductBarcodeExampleState();
}

class _ProductBarcodeExampleState extends State<ProductBarcodeExample> {
  BarcodeResult? _result;

  Future<void> _scan() async {
    // Product barcodes: EAN-8, EAN-13, UPC-A, UPC-E
    final result = await ScanKit.scan(
      formats: BarcodeFormat.product,
      vibrateOnScan: true,
    );

    if (result != null && mounted) {
      setState(() => _result = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Barcodes')),
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
                onPressed: _scan,
                icon: const Icon(Icons.shopping_cart),
                label: const Text('Scan Product'),
              ),
              const SizedBox(height: 16),
              const Text(
                'formats: BarcodeFormat.product\n(EAN-8, EAN-13, UPC-A, UPC-E)',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
