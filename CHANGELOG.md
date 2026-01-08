## 0.1.0

Initial release.

### Features

- **One-shot scanning**: Full-screen scanner with `ScanKit.scan()`
- **Embedded scanner**: `ScanKitView` widget for embedding in any layout
- **Gallery scanning**: `ScanKit.scanFromGallery()` and `ScanKit.scanFromFile()`
- **Document scanning**: Multi-page document capture with `ScanKit.scanDocument()`
- **Camera controls**: Torch, zoom, front/back camera switching
- **Customizable overlays**: `ScanKitOverlay` and `ScanKitAnimatedOverlay`
- **Rich configuration**: Format filtering, scan regions, debounce, auto-zoom
- **Validation callbacks**: Filter unwanted barcodes before emission

### Supported Formats

- 2D: QR, Aztec, Data Matrix, PDF417
- 1D Product: EAN-8, EAN-13, UPC-A, UPC-E
- 1D Industrial: Code 39, Code 93, Code 128, Codabar, ITF-14

### Platform Support

- iOS 13.0+ (VisionKit on iOS 16+, AVFoundation fallback)
- Android API 21+ (ML Kit + CameraX)
