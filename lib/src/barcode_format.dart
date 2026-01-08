/// Barcode format definitions for ScanKit
///
/// Defines all supported barcode symbologies including 2D codes
/// (QR, Aztec, DataMatrix, PDF417) and 1D codes (EAN, UPC, Code128, etc).
library;

/// Supported barcode formats
///
/// Use [BarcodeFormat.all] for all formats, or specify a subset
/// like [BarcodeFormat.product] for retail scanning.
enum BarcodeFormat {
  // 2D
  qr,
  aztec,
  dataMatrix,
  pdf417,

  // 1D Product
  ean8,
  ean13,
  upca,
  upce,

  // 1D Industrial
  code39,
  code93,
  code128,
  codabar,
  itf;

  /// All supported formats
  static const List<BarcodeFormat> all = BarcodeFormat.values;

  /// Common product barcodes
  static const List<BarcodeFormat> product = [ean8, ean13, upca, upce];

  /// QR code only
  static const List<BarcodeFormat> qrOnly = [qr];

  /// Convert to string identifier used by platform APIs
  String get identifier => name;

  /// Parse from platform string
  static BarcodeFormat? fromString(String value) {
    for (final format in values) {
      if (format.name == value) return format;
    }
    return null;
  }
}
