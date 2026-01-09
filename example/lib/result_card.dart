import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scankit/scankit.dart';

/// Card widget displaying barcode scan results
class ResultCard extends StatelessWidget {
  final BarcodeResult result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.format.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: result.value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied to clipboard'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              result.value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (result.boundingBox != null) ...[
              const SizedBox(height: 8),
              Text(
                'Position: ${_formatRect(result.boundingBox!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatRect(Rect rect) {
    return '(${(rect.left * 100).toStringAsFixed(0)}%, ${(rect.top * 100).toStringAsFixed(0)}%)';
  }
}
