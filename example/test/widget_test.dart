import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:scankit_example/main.dart';

void main() {
  testWidgets('ScanKit demo UI loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ScanKitApp()));
    await tester.pumpAndSettle();

    // Verify that the app bar title is shown
    expect(find.text('ScanKit'), findsOneWidget);

    // Verify key sections are present
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Use Cases'), findsOneWidget);
  });
}
