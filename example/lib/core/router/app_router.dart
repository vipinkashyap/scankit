import 'package:go_router/go_router.dart';

import '../../screens/home_screen.dart';
import '../../screens/scanner_screen.dart';
import '../../screens/history_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/wifi_scanner_screen.dart';
import '../../screens/checkin_screen.dart';
import '../../screens/inventory_screen.dart';
import '../../screens/simple_one_shot_example.dart';
import '../../screens/qr_only_example.dart';
import '../../screens/product_barcode_example.dart';
import '../../screens/basic_embedded_example.dart';
import '../../screens/styled_overlay_example.dart';
import '../../screens/liquid_glass_example.dart';
import '../../screens/continuous_scan_example.dart';
import '../../screens/custom_ui_example.dart';
import '../../screens/gallery_scan_example.dart';
import '../../screens/document_scan_example.dart';

/// App route paths
class AppRoutes {
  static const home = '/';
  static const scanner = '/scanner';
  static const history = '/history';
  static const settings = '/settings';
  static const wifiScanner = '/wifi';
  static const checkin = '/checkin';
  static const inventory = '/inventory';

  // Code examples
  static const simpleOneShot = '/examples/one-shot';
  static const qrOnly = '/examples/qr-only';
  static const productBarcode = '/examples/product';
  static const basicEmbedded = '/examples/embedded';
  static const styledOverlay = '/examples/styled';
  static const liquidGlass = '/examples/glass';
  static const continuous = '/examples/continuous';
  static const customUI = '/examples/custom';
  static const gallery = '/examples/gallery';
  static const document = '/examples/document';
}

/// GoRouter configuration
final appRouter = GoRouter(
  initialLocation: AppRoutes.home,
  routes: [
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: AppRoutes.scanner,
      builder: (context, state) => const ScannerScreen(),
    ),
    GoRoute(
      path: AppRoutes.history,
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: AppRoutes.wifiScanner,
      builder: (context, state) => const WifiScannerScreen(),
    ),
    GoRoute(
      path: AppRoutes.checkin,
      builder: (context, state) => const CheckinScreen(),
    ),
    GoRoute(
      path: AppRoutes.inventory,
      builder: (context, state) => const InventoryScreen(),
    ),
    // Code examples
    GoRoute(
      path: AppRoutes.simpleOneShot,
      builder: (context, state) => const SimpleOneShotExample(),
    ),
    GoRoute(
      path: AppRoutes.qrOnly,
      builder: (context, state) => const QrOnlyExample(),
    ),
    GoRoute(
      path: AppRoutes.productBarcode,
      builder: (context, state) => const ProductBarcodeExample(),
    ),
    GoRoute(
      path: AppRoutes.basicEmbedded,
      builder: (context, state) => const BasicEmbeddedExample(),
    ),
    GoRoute(
      path: AppRoutes.styledOverlay,
      builder: (context, state) => const StyledOverlayExample(),
    ),
    GoRoute(
      path: AppRoutes.liquidGlass,
      builder: (context, state) => const LiquidGlassExample(),
    ),
    GoRoute(
      path: AppRoutes.continuous,
      builder: (context, state) => const ContinuousScanExample(),
    ),
    GoRoute(
      path: AppRoutes.customUI,
      builder: (context, state) => const CustomUIExample(),
    ),
    GoRoute(
      path: AppRoutes.gallery,
      builder: (context, state) => const GalleryScanExample(),
    ),
    GoRoute(
      path: AppRoutes.document,
      builder: (context, state) => const DocumentScanExample(),
    ),
  ],
);
