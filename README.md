# ScanKit

A modern Flutter plugin for **QR codes**, **barcodes**, and **document scanning**. Native implementations only - iOS uses VisionKit/Vision, Android uses ML Kit + CameraX.

## Features

- **QR & Barcode Scanning**: 13 formats including QR, EAN, UPC, Code 128, Data Matrix, and more
- **Document Scanning**: Multi-page capture with automatic edge detection
- **Multiple Modes**: One-shot, embedded widget, or scan from gallery/images
- **Native Performance**: Platform-native APIs for fast, accurate results
- **Camera Controls**: Torch, zoom, front/back camera switching
- **Customizable Overlays**: Built-in animated overlays or bring your own

## Platform Support

| Platform | Minimum Version | Scanner Technology |
|----------|-----------------|-------------------|
| iOS | 13.0 | VisionKit (iOS 16+), AVFoundation + Vision fallback |
| Android | API 21 | ML Kit Barcode Scanning + CameraX |

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  scankit: ^0.1.0
```

### iOS Setup

Add camera permission to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan barcodes</string>
```

### Android Setup

Add camera permission to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

## Quick Start

### One-Shot Scanning

The simplest way to scan - opens a full-screen scanner and returns the result:

```dart
import 'package:scankit/scankit.dart';

final result = await ScanKit.scan();
if (result != null) {
  print('Scanned: ${result.value} (${result.format})');
}
```

With options:

```dart
final result = await ScanKit.scan(
  formats: [BarcodeFormat.qr, BarcodeFormat.ean13],
  vibrateOnScan: true,
  showTorchButton: true,
);
```

### Embedded Scanner Widget

Embed a scanner anywhere in your widget tree:

```dart
ScanKitView(
  onDetect: (barcode) {
    print('Scanned: ${barcode.value}');
  },
  overlay: const ScanKitAnimatedOverlay(),
)
```

With a controller for more control:

```dart
final controller = ScanKitController(
  formats: [BarcodeFormat.qr],
  onDetect: (barcode) => handleBarcode(barcode),
);

// In your widget
ScanKitView(
  controller: controller,
  overlay: const ScanKitOverlay(
    borderColor: Colors.blue,
  ),
)

// Control the scanner
await controller.toggleTorch();
await controller.setZoom(2.0);
await controller.switchCamera();

// Don't forget to dispose
controller.dispose();
```

### Scan from Gallery/Image

```dart
// Pick from gallery
final result = await ScanKit.scanFromGallery(
  formats: [BarcodeFormat.qr],
);

// Scan from file path
final result = await ScanKit.scanFromFile('/path/to/image.jpg');
```

### Document Scanning

Capture multi-page documents with edge detection:

```dart
final result = await ScanKit.scanDocument(
  maxPages: 10,
  allowGalleryImport: true,
);

if (result != null) {
  print('Scanned ${result.pageCount} pages');
  for (final page in result.pages) {
    print('Page: ${page.imagePath}');
  }
}
```

## Supported Barcode Formats

### 2D Codes
- `BarcodeFormat.qr` - QR Code
- `BarcodeFormat.aztec` - Aztec
- `BarcodeFormat.dataMatrix` - Data Matrix
- `BarcodeFormat.pdf417` - PDF417

### 1D Product Codes
- `BarcodeFormat.ean8` - EAN-8
- `BarcodeFormat.ean13` - EAN-13
- `BarcodeFormat.upca` - UPC-A
- `BarcodeFormat.upce` - UPC-E

### 1D Industrial Codes
- `BarcodeFormat.code39` - Code 39
- `BarcodeFormat.code93` - Code 93
- `BarcodeFormat.code128` - Code 128
- `BarcodeFormat.codabar` - Codabar (iOS 15+)
- `BarcodeFormat.itf` - ITF-14

### Format Presets

```dart
BarcodeFormat.all      // All supported formats
BarcodeFormat.product  // EAN-8, EAN-13, UPC-A, UPC-E
BarcodeFormat.qrOnly   // QR Code only
```

## Overlays

### Built-in Overlays

```dart
// Static corner brackets
ScanKitOverlay(
  borderColor: Colors.white,
  borderWidth: 3,
  cornerLength: 24,
  overlayColor: Colors.black54,
  scanAreaSize: 280,
)

// Animated scan line
ScanKitAnimatedOverlay(
  borderColor: Colors.blue,
  scanLineColor: Colors.blue,
  animationDuration: Duration(seconds: 2),
)
```

### Custom Overlay

Pass any widget as an overlay:

```dart
ScanKitView(
  onDetect: handleBarcode,
  overlay: MyCustomOverlay(),
)
```

## Controller API

`ScanKitController` provides full control over embedded scanning:

```dart
final controller = ScanKitController(
  formats: [BarcodeFormat.qr],
  cameraFacing: CameraFacing.back,
  resolution: CameraResolution.high,
  debounceMs: 500,
  autoZoom: false,
  onDetect: (barcode) => print(barcode.value),
  onScanError: (error) => print('Error: $error'),
  validator: (barcode) => barcode.value.length > 5,
);
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `formats` | `List<BarcodeFormat>?` | Formats to scan (null = all) |
| `cameraFacing` | `CameraFacing` | Front or back camera |
| `resolution` | `CameraResolution` | low, medium, high, max |
| `debounceMs` | `int` | Delay between same-value detections |
| `autoZoom` | `bool` | Auto-zoom toward detected barcodes |
| `scanRegion` | `ScanRegion?` | Region of interest for scanning |
| `validator` | `Function?` | Filter unwanted barcodes |

### Methods

```dart
await controller.toggleTorch();
await controller.setTorch(true);
await controller.switchCamera();
await controller.setZoom(2.0);
await controller.updateConfig(debounceMs: 1000);
final hasTorch = await controller.isTorchAvailable();
```

### Streams & Notifiers

```dart
controller.barcodes.listen((barcode) => ...);
controller.errors.listen((error) => ...);
controller.torchState;        // ValueListenable<bool>
controller.cameraFacingState; // ValueListenable<CameraFacing>
controller.zoomLevel;         // ValueListenable<double>
```

## Warm-up

Pre-initialize the scanner for faster first scan:

```dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ScanKit.warmUp();
  runApp(MyApp());
}
```

## Error Handling

ScanKit provides typed exceptions:

```dart
try {
  final result = await ScanKit.scan();
} on CameraPermissionDeniedException {
  // User denied camera permission
} on ScannerUnavailableException {
  // Scanner not available on this device
} on ScanKitException catch (e) {
  // Other scanner errors
  print('Error: ${e.message}');
}
```

## BarcodeResult

Scan results include:

```dart
class BarcodeResult {
  final String value;           // Barcode content
  final BarcodeFormat format;   // Detected format
  final Uint8List? rawBytes;    // Raw byte data
  final Rect? boundingBox;      // Normalized 0-1 coordinates
  final List<Offset>? cornerPoints; // Four corner points
}
```

## Example App

See the [example](example/) directory for a complete demo app showcasing all features.

## Architecture

ScanKit uses [Pigeon](https://pub.dev/packages/pigeon) for type-safe platform communication:

```
Flutter (Dart)
    ↕ Pigeon (type-safe messages)
┌───────────┬───────────┐
│   iOS     │  Android  │
│ VisionKit │  ML Kit   │
│  Vision   │  CameraX  │
└───────────┴───────────┘
```

## License

MIT License - see [LICENSE](LICENSE) for details.
