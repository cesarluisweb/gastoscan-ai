import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/core/utils/amount_parser.dart';

void main() {
  group('tryParseAmount - formato venezolano e internacional', () {
    test('miles con punto y decimal con coma', () {
      expect(tryParseAmount('1.234,56', isPrice: false), equals(1234.56));
    });

    test('decimal con coma sin miles', () {
      expect(tryParseAmount('1234,56', isPrice: false), equals(1234.56));
    });

    test('formato internacional con miles y decimal', () {
      expect(tryParseAmount('1,234.56', isPrice: false), equals(1234.56));
    });

    test('decimal con punto', () {
      expect(tryParseAmount('1234.56', isPrice: false), equals(1234.56));
    });

    test('entero sin separadores NO aplica regla de precio en formularios', () {
      expect(tryParseAmount('1500', isPrice: false), equals(1500.0));
    });

    test('modo precio OCR conserva regla historica', () {
      expect(tryParseAmount('1500', isPrice: true), equals(15.0));
      expect(tryParseAmount('5', isPrice: true), equals(0.05));
    });

    test('texto invalido da null', () {
      expect(tryParseAmount('abc', isPrice: false), isNull);
    });

    test('vacio da null', () {
      expect(tryParseAmount('', isPrice: false), isNull);
      expect(tryParseAmount('   ', isPrice: false), isNull);
    });

    test('negativo conserva el signo', () {
      expect(tryParseAmount('-50', isPrice: false), equals(-50.0));
      expect(tryParseAmount('-1.234,56', isPrice: false), equals(-1234.56));
    });

    test('simbolo de moneda se ignora', () {
      expect(tryParseAmount('Bs. 1.234,56', isPrice: false), equals(1234.56));
    });
  });
}
