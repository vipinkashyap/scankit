import 'package:flutter/material.dart';
import 'package:scankit/scankit.dart';

import '../result_card.dart';

/// Example: QR code only scan
///
/// Restricts scanning to QR codes only.
class QrOnlyExample extends StatefulWidget {
  const QrOnlyExample({super.key});

  @override
  State<QrOnlyExample> createState() => _QrOnlyExampleState();
}

class _QrOnlyExampleState extends State<QrOnlyExample> {
  BarcodeResult? _result;

  Future<void> _scan() async {
    // Restrict to QR codes only
    final result = await ScanKit.scan(
      formats: BarcodeFormat.qrOnly,
    );

    if (result != null && mounted) {
      setState(() => _result = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Code Only')),
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
                icon: const Icon(Icons.qr_code),
                label: const Text('Scan QR Code'),
              ),
              const SizedBox(height: 16),
              const Text(
                'formats: BarcodeFormat.qrOnly',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
