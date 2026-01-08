import 'package:flutter/material.dart';
import 'package:scankit/scankit.dart';

import 'examples/examples.dart';
import 'widgets/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Pre-warm scanner for instant startup
  ScanKit.warmUp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ScanKit Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ScanKit Examples'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick Scan Section
          const SectionHeader('Quick Scan'),
          ExampleCard(
            title: 'Simple One-Shot Scan',
            subtitle: 'Opens scanner, returns result',
            icon: Icons.qr_code_scanner,
            onTap: () => _navigate(context, const SimpleOneShotExample()),
          ),
          ExampleCard(
            title: 'QR Code Only',
            subtitle: 'Restricted to QR format',
            icon: Icons.qr_code,
            onTap: () => _navigate(context, const QrOnlyExample()),
          ),
          ExampleCard(
            title: 'Product Barcodes',
            subtitle: 'EAN-8, EAN-13, UPC-A, UPC-E',
            icon: Icons.shopping_cart,
            onTap: () => _navigate(context, const ProductBarcodeExample()),
          ),

          // Embedded Scanner Section
          const SizedBox(height: 24),
          const SectionHeader('Embedded Scanner'),
          ExampleCard(
            title: 'Basic Embedded',
            subtitle: 'Scanner widget in your UI',
            icon: Icons.crop_free,
            onTap: () => _navigate(context, const BasicEmbeddedExample()),
          ),
          ExampleCard(
            title: 'Styled Overlay',
            subtitle: 'Custom colors and sizes',
            icon: Icons.palette,
            onTap: () => _navigate(context, const StyledOverlayExample()),
          ),
          ExampleCard(
            title: 'Liquid Glass',
            subtitle: 'Premium iOS-inspired UI',
            icon: Icons.blur_on,
            onTap: () => _navigate(context, const LiquidGlassExample()),
          ),
          ExampleCard(
            title: 'Continuous Scanning',
            subtitle: 'Scan multiple items',
            icon: Icons.repeat,
            onTap: () => _navigate(context, const ContinuousScanExample()),
          ),
          ExampleCard(
            title: 'Custom UI',
            subtitle: 'Full control, no overlay',
            icon: Icons.dashboard_customize,
            onTap: () => _navigate(context, const CustomUIExample()),
          ),

          // Image Scanning Section
          const SizedBox(height: 24),
          const SectionHeader('Image Scanning'),
          ExampleCard(
            title: 'Scan from Gallery',
            subtitle: 'Pick image and detect barcode',
            icon: Icons.photo_library,
            onTap: () => _navigate(context, const GalleryScanExample()),
          ),

          // Document Scanning Section
          const SizedBox(height: 24),
          const SectionHeader('Document Scanning'),
          ExampleCard(
            title: 'Scan Documents',
            subtitle: 'Multi-page document capture',
            icon: Icons.document_scanner,
            onTap: () => _navigate(context, const DocumentScanExample()),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}
