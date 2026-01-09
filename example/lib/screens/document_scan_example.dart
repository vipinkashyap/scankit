import 'dart:io';

import 'package:flutter/material.dart';
import 'package:scankit/scankit.dart';

/// Example: Document scanning
///
/// Multi-page document capture with edge detection.
class DocumentScanExample extends StatefulWidget {
  const DocumentScanExample({super.key});

  @override
  State<DocumentScanExample> createState() => _DocumentScanExampleState();
}

class _DocumentScanExampleState extends State<DocumentScanExample> {
  DocumentScanResult? _result;
  bool _loading = false;

  Future<void> _scanDocument() async {
    setState(() => _loading = true);

    try {
      final result = await ScanKit.scanDocument(
        maxPages: 10,
        allowGalleryImport: true,
      );

      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
        });
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
      appBar: AppBar(title: const Text('Document Scanner')),
      body: _result != null
          ? Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    '${_result!.pageCount} page(s) scanned',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _result!.pages.length,
                    itemBuilder: (context, index) {
                      final page = _result!.pages[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(page.imagePath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    onPressed: _scanDocument,
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Scan More'),
                  ),
                ),
              ],
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.document_scanner,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loading ? null : _scanDocument,
                      icon: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.document_scanner),
                      label: Text(_loading ? 'Opening...' : 'Scan Document'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Captures documents with edge detection.\nSupports multi-page scanning.',
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
