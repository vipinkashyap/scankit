/// Barcode scan result model
///
/// Contains the decoded value, format, raw bytes, and position
/// information (bounding box, corner points) for a scanned barcode.
library;

import 'dart:typed_data';
import 'dart:ui';
import 'barcode_format.dart';

/// Represents a scanned barcode result
///
/// Contains all information about a detected barcode including:
/// - [value] - The decoded string content
/// - [format] - The barcode symbology (QR, EAN13, etc.)
/// - [rawBytes] - Raw byte data (if available)
/// - [boundingBox] - Position in normalized coordinates (0-1)
/// - [cornerPoints] - Corner positions for perspective-aware rendering
class BarcodeResult {
  const BarcodeResult({
    required this.value,
    required this.format,
    this.rawBytes,
    this.boundingBox,
    this.cornerPoints,
  });

  /// The decoded string value of the barcode
  final String value;

  /// The format of the barcode
  final BarcodeFormat format;

  /// Raw bytes of the barcode (if available)
  final Uint8List? rawBytes;

  /// Bounding box of the barcode in normalized coordinates (0-1)
  /// Use with the scanner view size to get actual pixel coordinates
  final Rect? boundingBox;

  /// Corner points of the barcode in normalized coordinates (0-1)
  /// Typically 4 points for QR codes, may vary for 1D barcodes
  final List<Offset>? cornerPoints;

  @override
  String toString() => 'BarcodeResult(value: $value, format: $format)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BarcodeResult &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          format == other.format;

  @override
  int get hashCode => value.hashCode ^ format.hashCode;
}
