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
  });
}
