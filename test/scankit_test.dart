import 'package:flutter_test/flutter_test.dart';
import 'package:scankit/scankit.dart';

void main() {
  group('BarcodeFormat', () {
    test('all contains all formats', () {
      expect(BarcodeFormat.all, equals(BarcodeFormat.values));
    });

    test('product contains product formats', () {
      expect(BarcodeFormat.product, containsAll([
        BarcodeFormat.ean8,
        BarcodeFormat.ean13,
        BarcodeFormat.upca,
        BarcodeFormat.upce,
      ]));
    });

    test('qrOnly contains only qr', () {
      expect(BarcodeFormat.qrOnly, equals([BarcodeFormat.qr]));
    });

    test('fromString parses valid format', () {
      expect(BarcodeFormat.fromString('qr'), equals(BarcodeFormat.qr));
      expect(BarcodeFormat.fromString('ean13'), equals(BarcodeFormat.ean13));
    });

    test('fromString returns null for invalid format', () {
      expect(BarcodeFormat.fromString('invalid'), isNull);
    });
  });

  group('BarcodeResult', () {
    test('equality works correctly', () {
      const result1 = BarcodeResult(value: 'test', format: BarcodeFormat.qr);
      const result2 = BarcodeResult(value: 'test', format: BarcodeFormat.qr);
      const result3 = BarcodeResult(value: 'different', format: BarcodeFormat.qr);

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });

    test('toString returns readable string', () {
      const result = BarcodeResult(value: 'hello', format: BarcodeFormat.qr);
      expect(result.toString(), contains('hello'));
      expect(result.toString(), contains('qr'));
    });
  });
}
