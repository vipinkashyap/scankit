## 0.1.3

- Improved Android one-shot scanner button visibility with dark circular backgrounds

## 0.1.2

- Fixed Android torch control in embedded scanner
- Added `LiquidGlassOverlay` with frosted glass effect
- Upgraded example app with production-grade architecture (Riverpod, GoRouter, Drift/sqlite3)
- Added domain-specific examples: WiFi Connect, Event Check-in, Inventory scanning
- Improved scan result display with category detection and context-aware actions

## 0.1.1

- Updated package description to highlight QR code, barcode & document scanning capabilities
- Improved documentation and README

## 0.1.0

Initial release - QR code, barcode & document scanner for Flutter.

### Features

- **QR & Barcode Scanning**: 13 formats including QR, EAN, UPC, Code 128, Data Matrix
- **Document Scanning**: Multi-page capture with automatic edge detection
- **Multiple Modes**: One-shot (`ScanKit.scan()`), embedded widget (`ScanKitView`), gallery/image scanning
- **Camera Controls**: Torch, zoom, front/back camera switching
- **Customizable Overlays**: `ScanKitOverlay` and `ScanKitAnimatedOverlay`
- **Rich Configuration**: Format filtering, scan regions, debounce, auto-zoom
- **Validation Callbacks**: Filter unwanted results before emission

### Supported Barcode Formats

- 2D: QR, Aztec, Data Matrix, PDF417
- 1D Product: EAN-8, EAN-13, UPC-A, UPC-E
- 1D Industrial: Code 39, Code 93, Code 128, Codabar, ITF-14

### Platform Support

- iOS 13.0+ (VisionKit on iOS 16+, AVFoundation fallback)
- Android API 21+ (ML Kit + CameraX)
