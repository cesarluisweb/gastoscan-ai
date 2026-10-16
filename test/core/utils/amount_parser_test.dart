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
      expect(tryParseAmount('25', isPrice: false), equals(25.0));
    });

    test('valores numéricos (int y double) se preservan directamente sin alterar decimales', () {
      expect(tryParseAmount(25), equals(25.0));
      expect(tryParseAmount(25.0), equals(25.0));
      expect(tryParseAmount(100), equals(100.0));
      expect(tryParseAmount(0.25), equals(0.25));
    });

    test('monto con coma decimal en formato español (\$25,00)', () {
      expect(tryParseAmount('25,00', isPrice: false), equals(25.0));
      expect(tryParseAmount('\$25,00 USD', isPrice: false), equals(25.0));
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

  group('tryParsePositiveAmount - FIN-08', () {
    test('acepta valores estrictamente mayores a 0', () {
      expect(tryParsePositiveAmount('10.5'), equals(10.5));
      expect(tryParsePositiveAmount('1500', isPrice: false), equals(1500.0));
      expect(tryParsePositiveAmount('1.234,56', isPrice: false), equals(1234.56));
      expect(tryParsePositiveAmount('0.01'), equals(0.01));
    });

    test('rechaza cero y negativos', () {
      expect(tryParsePositiveAmount('0'), isNull);
      expect(tryParsePositiveAmount('0,00'), isNull);
      expect(tryParsePositiveAmount('-50'), isNull);
      expect(tryParsePositiveAmount('-1.234,56'), isNull);
    });

    test('rechaza texto no numérico o vacío', () {
      expect(tryParsePositiveAmount(''), isNull);
      expect(tryParsePositiveAmount('abc'), isNull);
      expect(tryParsePositiveAmount(null), isNull);
    });
  });

  group('validatePositiveAmount - FIN-08', () {
    test('retorna null para montos validos mayores a 0', () {
      expect(validatePositiveAmount('100'), isNull);
      expect(validatePositiveAmount('1.234,56'), isNull);
      expect(validatePositiveAmount('0.50'), isNull);
    });

    test('retorna mensaje de error para valores vacios', () {
      expect(validatePositiveAmount(''), equals('Requerido'));
      expect(validatePositiveAmount('   '), equals('Requerido'));
      expect(validatePositiveAmount(null), equals('Requerido'));
    });

    test('retorna mensaje de error para texto no numerico', () {
      expect(validatePositiveAmount('invalido'), equals('Monto inválido'));
      expect(validatePositiveAmount('abc'), equals('Monto inválido'));
    });

    test('retorna mensaje de error para 0 y negativos', () {
      expect(validatePositiveAmount('0'), equals('Debe ser mayor a 0'));
      expect(validatePositiveAmount('0,00'), equals('Debe ser mayor a 0'));
      expect(validatePositiveAmount('-10'), equals('Debe ser mayor a 0'));
      expect(validatePositiveAmount('-100.50'), equals('Debe ser mayor a 0'));
    });
  });
}
