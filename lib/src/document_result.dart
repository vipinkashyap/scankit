/// Document scanning result models
///
/// Contains [ScannedPage] for individual pages and [DocumentScanResult]
/// for the complete scan result including optional PDF output.
library;

import 'dart:io';

/// Represents a single scanned document page
///
/// Each page contains the path to the image file and its dimensions.
class ScannedPage {
  const ScannedPage({
    required this.imagePath,
    required this.width,
    required this.height,
  });

  /// Path to the scanned image file
  final String imagePath;

  /// Width of the image in pixels
  final int width;

  /// Height of the image in pixels
  final int height;

  /// Get the image file
  File get imageFile => File(imagePath);
}

/// Result of document scanning
class DocumentScanResult {
  const DocumentScanResult({
    required this.pages,
    this.pdfPath,
  });

  /// List of scanned pages
  final List<ScannedPage> pages;

  /// Path to combined PDF (if generated)
  final String? pdfPath;

  /// Get the PDF file (if available)
  File? get pdfFile => pdfPath != null ? File(pdfPath!) : null;

  /// Number of pages scanned
  int get pageCount => pages.length;

  /// Whether this result has any pages
  bool get isNotEmpty => pages.isNotEmpty;
}
