import 'dart:ui';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
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
      final line1 = TextLine(
        text: 'AUTOMERCADOS PLAZA C.A.',
        elements: [
          TextElement(text: 'AUTOMERCADOS', boundingBox: const Rect.fromLTWH(0, 0, 100, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
          TextElement(text: 'PLAZA', boundingBox: const Rect.fromLTWH(110, 0, 80, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
        ],
        boundingBox: const Rect.fromLTWH(0, 0, 200, 20),
        cornerPoints: [],
        recognizedLanguages: ['es'],
      );

      final line2 = TextLine(
        text: 'RIF J-30123456-7',
        elements: [
          TextElement(text: 'RIF', boundingBox: const Rect.fromLTWH(0, 25, 40, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
          TextElement(text: 'J-30123456-7', boundingBox: const Rect.fromLTWH(45, 25, 100, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
        ],
        boundingBox: const Rect.fromLTWH(0, 25, 150, 20),
        cornerPoints: [],
        recognizedLanguages: ['es'],
      );

      final line3 = TextLine(
        text: 'FECHA: 25/09/2026',
        elements: [
          TextElement(text: 'FECHA:', boundingBox: const Rect.fromLTWH(0, 50, 60, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
          TextElement(text: '25/09/2026', boundingBox: const Rect.fromLTWH(65, 50, 80, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
        ],
        boundingBox: const Rect.fromLTWH(0, 50, 150, 20),
        cornerPoints: [],
        recognizedLanguages: ['es'],
      );

      final line4 = TextLine(
        text: 'HARINA PAN 1.00 45.00 BS',
        elements: [
          TextElement(text: 'HARINA', boundingBox: const Rect.fromLTWH(0, 75, 60, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
          TextElement(text: 'PAN', boundingBox: const Rect.fromLTWH(65, 75, 40, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
          TextElement(text: '45.00', boundingBox: const Rect.fromLTWH(110, 75, 50, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
          TextElement(text: 'BS', boundingBox: const Rect.fromLTWH(165, 75, 30, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
        ],
        boundingBox: const Rect.fromLTWH(0, 75, 200, 20),
        cornerPoints: [],
        recognizedLanguages: ['es'],
      );

      final line5 = TextLine(
        text: 'TOTAL A PAGAR: 45.00 BS',
        elements: [
          TextElement(text: 'TOTAL', boundingBox: const Rect.fromLTWH(0, 100, 50, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
          TextElement(text: '45.00', boundingBox: const Rect.fromLTWH(60, 100, 50, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
          TextElement(text: 'BS', boundingBox: const Rect.fromLTWH(115, 100, 30, 20), cornerPoints: [], recognizedLanguages: ['es'], symbols: []),
        ],
        boundingBox: const Rect.fromLTWH(0, 100, 150, 20),
        cornerPoints: [],
        recognizedLanguages: ['es'],
      );

      final block = TextBlock(
        text: 'AUTOMERCADOS PLAZA C.A.\nRIF J-30123456-7\nFECHA: 25/09/2026\nHARINA PAN 1.00 45.00 BS\nTOTAL A PAGAR: 45.00 BS',
        lines: [line1, line2, line3, line4, line5],
        boundingBox: const Rect.fromLTWH(0, 0, 200, 120),
        cornerPoints: [],
        recognizedLanguages: ['es'],
      );

      final recognizedText = RecognizedText(
        text: block.text,
        blocks: [block],
      );

      final score = ocrService.evaluateQuality(recognizedText);

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
      final line1 = TextLine(
        text: 'HOLA MUNDO',
        elements: [],
        boundingBox: const Rect.fromLTWH(0, 0, 100, 20),
        cornerPoints: [],
        recognizedLanguages: ['es'],
      );

      final block = TextBlock(
        text: 'HOLA MUNDO',
        lines: [line1],
        boundingBox: const Rect.fromLTWH(0, 0, 100, 20),
        cornerPoints: [],
        recognizedLanguages: ['es'],
      );

      final recognizedText = RecognizedText(
        text: 'HOLA MUNDO',
        blocks: [block],
      );

      final score = ocrService.evaluateQuality(recognizedText);

      expect(score.hasAmounts, isFalse);
      expect(score.hasTotalKeyword, isFalse);
      expect(score.shouldAttemptText, isFalse);
    });
  });
}
