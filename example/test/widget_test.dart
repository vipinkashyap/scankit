import 'package:flutter_test/flutter_test.dart';

import 'package:scankit_example/main.dart';

void main() {
  testWidgets('ScanKit demo UI loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Verify that the app bar title is shown
    expect(find.text('ScanKit Demo'), findsOneWidget);

    // Verify that the scan buttons are present
    expect(find.text('Scan Any Barcode'), findsOneWidget);
    expect(find.text('Scan QR Code Only'), findsOneWidget);
    expect(find.text('Embedded Scanner'), findsOneWidget);
  });
}
