import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:scankit/scankit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isSupported test', (WidgetTester tester) async {
    // Just verify the API is callable - actual scanning needs camera
    final bool isSupported = await ScanKit.isSupported();
    expect(isSupported, isA<bool>());
  });
}
