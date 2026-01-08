# ScanKit

A modern, lean barcode and QR code scanner for Flutter. iOS and Android only — no compromises.

## Project Philosophy

- **Native-first**: Use the best native APIs available (VisionKit on iOS, ML Kit + CameraX on Android)
- **Lean**: No web, no macOS, no desktop — just mobile done right
- **Modern**: Dart 3 patterns, Pigeon for type-safe platform communication, latest native SDKs
- **Simple API**: Easy things should be easy, complex things should be possible

## Package Name

`scankit` (pub.dev availability TBD, alternatives: `swift_scan`, `native_scanner`, `code_reader`)

## Architecture

```
lib/
├── scankit.dart                    # Main export file
├── src/
│   ├── scankit_controller.dart     # Camera/scanner controller
│   ├── scankit_view.dart           # Scanner widget
│   ├── models/
│   │   ├── barcode.dart            # Barcode result model
│   │   ├── barcode_format.dart     # Supported formats enum
│   │   └── scan_config.dart        # Configuration options
│   ├── overlay/
│   │   ├── scan_overlay.dart       # Base overlay
│   │   └── viewfinder_painter.dart # Custom viewfinder drawing
│   └── platform/
│       └── scankit_platform.dart   # Platform interface

ios/
├── Classes/
│   ├── SwiftScankitPlugin.swift    # Plugin entry point
│   ├── ScannerViewController.swift  # DataScannerViewController wrapper
│   └── LegacyScanner.swift         # AVFoundation fallback for iOS < 16

android/
├── src/main/kotlin/
│   └── com/example/scankit/
│       ├── ScankitPlugin.kt        # Plugin entry point
│       ├── ScannerView.kt          # CameraX PreviewView integration
│       └── BarcodeAnalyzer.kt      # ML Kit analyzer

pigeons/
└── messages.dart                   # Pigeon definitions for platform communication
```

## Native Implementation Details

### iOS

**Primary (iOS 16+): VisionKit DataScannerViewController**
- Built-in camera UI with guidance and highlighting
- Excellent performance, Apple's own implementation
- Supports all standard barcode symbologies
- Minimal code required

```swift
let scanner = DataScannerViewController(
    recognizedDataTypes: [.barcode(symbologies: [.qr, .ean13, .code128])],
    qualityLevel: .accurate,
    recognizesMultipleItems: true,
    isHighFrameRateTrackingEnabled: true,
    isHighlightingEnabled: true
)
```

**Fallback (iOS 13-15): AVFoundation + Vision**
- AVCaptureSession for camera
- VNDetectBarcodesRequest for detection
- Custom UI overlay

### Android

**CameraX + ML Kit**
- LifecycleCameraController for lifecycle-aware camera
- MlKitAnalyzer for seamless integration
- Bundled ML Kit by default (3-10MB), unbundled option available

```kotlin
val options = BarcodeScannerOptions.Builder()
    .setBarcodeFormats(Barcode.FORMAT_QR_CODE, Barcode.FORMAT_EAN_13)
    .build()

cameraController.setImageAnalysisAnalyzer(
    executor,
    MlKitAnalyzer(
        listOf(BarcodeScanning.getClient(options)),
        COORDINATE_SYSTEM_VIEW_REFERENCED,
        executor
    ) { result -> /* handle barcodes */ }
)
```

## Dart API Design

### Simple Usage

```dart
import 'package:scankit/scankit.dart';

// One-shot scan (opens full-screen scanner, returns on first detection)
final result = await ScanKit.scan();
if (result != null) {
  print('Scanned: ${result.value}');
}

// With options
final result = await ScanKit.scan(
  formats: [BarcodeFormat.qr],
  hapticFeedback: true,
);
```

### Embedded Scanner Widget

```dart
ScanKitView(
  controller: _controller,
  onDetect: (barcodes) {
    for (final barcode in barcodes) {
      print('${barcode.format}: ${barcode.value}');
    }
  },
  overlay: ScanKitOverlay.corners(
    borderColor: Colors.white,
    borderWidth: 3,
    cornerLength: 20,
  ),
)
```

### Controller API

```dart
final controller = ScanKitController(
  formats: BarcodeFormat.values,        // All formats
  resolution: Resolution.hd,             // 720p, fullHd, uhd
  detectionMode: DetectionMode.single,   // single, continuous
  cameraFacing: CameraFacing.back,
);

// Lifecycle
await controller.start();
await controller.stop();
await controller.dispose();

// Camera controls
await controller.toggleTorch();
await controller.switchCamera();
await controller.setZoom(2.0);

// Stream of detections
controller.barcodes.listen((List<Barcode> barcodes) {
  // Handle detected barcodes
});

// Current state
controller.torchState;     // ValueNotifier<TorchState>
controller.cameraState;    // ValueNotifier<CameraState>
```

## Models

### Barcode

```dart
sealed class Barcode {
  String get value;
  BarcodeFormat get format;
  Rect? get boundingBox;
  List<Offset>? get cornerPoints;
}

// Typed variants for structured data
class UrlBarcode extends Barcode {
  final Uri url;
}

class WifiBarcode extends Barcode {
  final String ssid;
  final String? password;
  final WifiEncryption encryption;
}

class ContactBarcode extends Barcode {
  final String? name;
  final String? phone;
  final String? email;
}

// ... etc for calendar events, geo, sms, phone
```

### BarcodeFormat

```dart
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
  itf,

  // All formats
  static const all = BarcodeFormat.values;
  
  // Common subsets
  static const product = [ean8, ean13, upca, upce];
  static const qrOnly = [qr];
}
```

## Configuration

### ScanConfig

```dart
class ScanConfig {
  final List<BarcodeFormat> formats;
  final Resolution resolution;
  final DetectionMode detectionMode;
  final CameraFacing cameraFacing;
  final bool hapticFeedback;
  final bool beepOnScan;
  final Duration? debounce;          // Debounce duplicate detections
  final Rect? scanWindow;            // Region of interest (normalized 0-1)
  
  const ScanConfig({
    this.formats = BarcodeFormat.all,
    this.resolution = Resolution.hd,
    this.detectionMode = DetectionMode.continuous,
    this.cameraFacing = CameraFacing.back,
    this.hapticFeedback = true,
    this.beepOnScan = false,
    this.debounce,
    this.scanWindow,
  });
}
```

## Overlays

```dart
// Built-in overlays
ScanKitOverlay.none()
ScanKitOverlay.corners(...)
ScanKitOverlay.box(...)
ScanKitOverlay.adaptive()  // Shows bounding boxes around detected codes

// Custom overlay
ScanKitOverlay.custom(
  builder: (context, barcodes) => CustomPainter(...),
)
```

## Platform Requirements

### iOS
- Minimum iOS 13.0 (VisionKit scanner requires iOS 16+, fallback for older)
- Camera usage description in Info.plist

```xml
<key>NSCameraUsageDescription</key>
<string>Camera access is required to scan barcodes</string>
```

### Android
- Minimum SDK 21 (Android 5.0)
- Camera permission in AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

- Gradle property for unbundled ML Kit (optional):
```properties
# android/gradle.properties
scankit.useUnbundledMlKit=true
```

## Development Commands

```bash
# Generate Pigeon platform code
dart run pigeon --input pigeons/messages.dart

# Run tests
flutter test

# Analyze
flutter analyze

# Format
dart format .

# Build example
cd example && flutter build ios
cd example && flutter build apk
```

## Key Differences from barcode_scan2

| Feature | barcode_scan2 | ScanKit |
|---------|--------------|---------|
| iOS Scanner | MTBBarcodeScanner (old) | VisionKit DataScannerViewController |
| Android Scanner | dm77/barcodescanner | CameraX + ML Kit |
| Communication | Protobuf | Pigeon (type-safe) |
| Dart Version | Old null safety | Dart 3 (sealed classes, records) |
| API Style | Callback-based | Stream + async/await |
| Overlay | Basic | Customizable, animated |
| Structured Data | Limited | Full parsing (WiFi, URL, contact, etc.) |

## Key Differences from mobile_scanner

| Feature | mobile_scanner | ScanKit |
|---------|---------------|---------|
| Platforms | iOS, Android, macOS, Web | iOS, Android only |
| iOS Implementation | AVFoundation | VisionKit (iOS 16+) with fallback |
| Complexity | Higher (multi-platform) | Lower (focused) |
| Bundle Size | Larger | Smaller |
| API | Controller-heavy | Simple + Advanced options |

## TODO

- [ ] Set up Flutter plugin project structure
- [ ] Implement Pigeon message definitions
- [ ] iOS: VisionKit DataScannerViewController implementation
- [ ] iOS: AVFoundation fallback for iOS < 16
- [ ] Android: CameraX + ML Kit implementation
- [ ] Dart: Controller and view implementation
- [ ] Dart: Overlay system
- [ ] Example app
- [ ] Unit tests
- [ ] Integration tests
- [ ] Documentation
- [ ] Publish to pub.dev

## References

- [VisionKit DataScannerViewController](https://developer.apple.com/documentation/visionkit/datascannerviewcontroller)
- [ML Kit Barcode Scanning](https://developers.google.com/ml-kit/vision/barcode-scanning)
- [CameraX MlKitAnalyzer](https://developer.android.com/training/camerax/mlkitanalyzer)
- [Pigeon](https://pub.dev/packages/pigeon)