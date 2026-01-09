import 'package:flutter/material.dart';
import 'package:scankit/scankit.dart';

import '../result_card.dart';

/// Example: Simple one-shot scan
///
/// Opens a full-screen scanner and returns the result on first detection.
class SimpleOneShotExample extends StatefulWidget {
  const SimpleOneShotExample({super.key});

  @override
  State<SimpleOneShotExample> createState() => _SimpleOneShotExampleState();
}

class _SimpleOneShotExampleState extends State<SimpleOneShotExample> {
  BarcodeResult? _result;

  Future<void> _scan() async {
    // Simple! Just call scan() and get the result
    final result = await ScanKit.scan();

    if (result != null && mounted) {
      setState(() => _result = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simple One-Shot')),
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
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan Barcode'),
              ),
              const SizedBox(height: 16),
              Text(
                'Opens full-screen scanner.\nReturns result on first detection.',
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
