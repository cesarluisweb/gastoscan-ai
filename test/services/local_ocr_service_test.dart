import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/services/local_ocr_service.dart';

void main() {
  group('LocalOcrService Quality Scoring Tests', () {
    late LocalOcrService ocrService;

    setUp(() {
      ocrService = LocalOcrService();
    });

    tearDown(() {
      ocrService.dispose();
    });

    test('factura completa con comercio, fecha, ítems y total supera umbral de score', () {
      const fullReceiptText = '''
AUTOMERCADOS PLAZA C.A.
RIF J-30123456-7
FECHA: 25/09/2026
HARINA PAN 1.00 45.00 BS
TOTAL A PAGAR: 45.00 BS
''';

      final score = ocrService.evaluateRawText(fullReceiptText);

      expect(score.hasAmounts, isTrue);
      expect(score.hasTotalKeyword, isTrue);
      expect(score.hasCurrency, isTrue);
      expect(score.hasDate, isTrue);
      expect(score.hasMerchantOrRif, isTrue);
      expect(score.hasSufficientLines, isTrue);
      expect(score.totalScore, greaterThanOrEqualTo(8));
      expect(score.shouldAttemptText, isTrue);
    });

    test('texto borroso o escaso de 2 líneas no supera el umbral de score', () {
      const blurReceiptText = '''
HOLA MUNDO
GRACIAS
''';

      final score = ocrService.evaluateRawText(blurReceiptText);

      expect(score.hasAmounts, isFalse);
      expect(score.hasTotalKeyword, isFalse);
      expect(score.shouldAttemptText, isFalse);
    });

    test('sanitizeOcrLine elimina espacios accidentales en decimales térmicos', () {
      expect(LocalOcrService.sanitizeOcrLine('PAN CANILLA 11 . 56 BS'), equals('PAN CANILLA 11.56 BS'));
      expect(LocalOcrService.sanitizeOcrLine('QUESO BLANCO 12 , 50'), equals('QUESO BLANCO 12.50'));
      expect(LocalOcrService.sanitizeOcrLine('LECHE 4. 20'), equals('LECHE 4.20'));
      expect(LocalOcrService.sanitizeOcrLine('HARINA 3 ,50'), equals('HARINA 3.50'));
    });
  });
}
