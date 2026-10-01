import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Resultado del procesamiento y evaluación del OCR local
class LocalOcrResult {
  final String rawText;
  final String structuredText;
  final OcrQualityScore qualityScore;

  const LocalOcrResult({
    required this.rawText,
    required this.structuredText,
    required this.qualityScore,
  });
}

/// Puntuación heurística de evidencia para determinar si vale la pena
/// enviar el texto a Gemini Texto o si debe activarse el fallback a Visión.
class OcrQualityScore {
  final int totalScore;
  final bool hasAmounts;
  final bool hasTotalKeyword;
  final bool hasCurrency;
  final bool hasDate;
  final bool hasMerchantOrRif;
  final bool hasSufficientLines;
  final int lineCount;

  const OcrQualityScore({
    required this.totalScore,
    required this.hasAmounts,
    required this.hasTotalKeyword,
    required this.hasCurrency,
    required this.hasDate,
    required this.hasMerchantOrRif,
    required this.hasSufficientLines,
    required this.lineCount,
  });

  /// Invariante: Un score >= 6 indica evidencia suficiente para intentar Gemini Texto
  bool get shouldAttemptText => totalScore >= 6;
}

/// Servicio local de reconocimiento óptico de caracteres (OCR on-device)
class LocalOcrService {
  TextRecognizer? _recognizer;

  LocalOcrService({TextRecognizer? recognizer}) : _recognizer = recognizer;

  TextRecognizer _getRecognizer() {
    return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  /// Procesa una imagen en disco, extrayendo el texto y evaluando su calidad
  Future<LocalOcrResult> processImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await _getRecognizer().processImage(inputImage);

      final rawText = recognizedText.text;
      final structuredText = formatSpatialText(recognizedText);
      final score = evaluateQuality(recognizedText);

      return LocalOcrResult(
        rawText: rawText,
        structuredText: structuredText,
        qualityScore: score,
      );
    } catch (e) {
      debugPrint('Error en LocalOcrService.processImage: $e');
      return const LocalOcrResult(
        rawText: '',
        structuredText: '',
        qualityScore: OcrQualityScore(
          totalScore: 0,
          hasAmounts: false,
          hasTotalKeyword: false,
          hasCurrency: false,
          hasDate: false,
          hasMerchantOrRif: false,
          hasSufficientLines: false,
          lineCount: 0,
        ),
      );
    }
  }

  /// Construye una representación espacial ordenada de bloques y líneas
  /// para que el modelo de lenguaje entienda las columnas relativas (descripción | precio).
  String formatSpatialText(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) {
      return recognizedText.text;
    }

    final StringBuffer buffer = StringBuffer();

    // Ordenar bloques de arriba hacia abajo
    final sortedBlocks = List<TextBlock>.from(recognizedText.blocks)
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    for (int bIdx = 0; bIdx < sortedBlocks.length; bIdx++) {
      final block = sortedBlocks[bIdx];
      buffer.writeln('[BLOQUE ${bIdx + 1}]');

      // Ordenar líneas del bloque por coordenada vertical
      final sortedLines = List<TextLine>.from(block.lines)
        ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

      for (final line in sortedLines) {
        // Ordenar elementos de la línea de izquierda a derecha
        final sortedElements = List<TextElement>.from(line.elements)
          ..sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));

        final lineText = sortedElements.map((e) => e.text).join(' ');
        if (lineText.trim().isNotEmpty) {
          buffer.writeln('  [LÍNEA] $lineText');
        }
      }
    }

    return buffer.toString().trim();
  }

  /// Evalúa determinísticamente la calidad y evidencia del texto reconocido
  OcrQualityScore evaluateQuality(RecognizedText recognizedText) {
    final text = recognizedText.text.toUpperCase();

    // 1. Conteo de líneas
    int lineCount = 0;
    for (final block in recognizedText.blocks) {
      lineCount += block.lines.length;
    }
    final hasSufficientLines = lineCount >= 5;

    // 2. Detección de importes numéricos con formato decimal (ej: 12.50 o 12,50)
    final amountRegex = RegExp(r'\b\d+[\.,]\d{2}\b');
    final hasAmounts = amountRegex.hasMatch(text);

    // 3. Palabras clave de total o subtotal
    final hasTotalKeyword = text.contains('TOTAL') ||
        text.contains('SUBTOTAL') ||
        text.contains('TOT.') ||
        text.contains('MONTO');

    // 4. Monedas venezolanas o divisas comunes
    final hasCurrency = text.contains('BS') ||
        text.contains('VES') ||
        text.contains('REF') ||
        text.contains('\$') ||
        text.contains('USD');

    // 5. Fecha (formatos DD/MM/AAAA, AAAA-MM-DD, etc.)
    final dateRegex = RegExp(r'\b(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}|\d{4}[\/\-\.]\d{1,2}[\/\-\.]\d{1,2})\b');
    final hasDate = dateRegex.hasMatch(text);

    // 6. Comercio o RIF (J-, V-, G-, C.A., S.A., INVERSIONES, AUTOMERCADO, etc.)
    final rifRegex = RegExp(r'\b[JVEGP][\-\s]?\d{7,9}[\-\s]?\d?\b');
    final hasMerchantOrRif = rifRegex.hasMatch(text) ||
        text.contains('C.A.') ||
        text.contains('S.A.') ||
        text.contains('RIF') ||
        text.contains('SENIAT') ||
        text.contains('INVERSIONES') ||
        text.contains('FARMACIA') ||
        text.contains('AUTOMERCADO') ||
        text.contains('SUPERMERCADO');

    // Cálculo del Score Ponderado
    int score = 0;
    if (hasAmounts) score += 2;
    if (hasTotalKeyword) score += 2;
    if (hasSufficientLines) score += 2;
    if (hasCurrency) score += 1;
    if (hasDate) score += 1;
    if (hasMerchantOrRif) score += 1;

    return OcrQualityScore(
      totalScore: score,
      hasAmounts: hasAmounts,
      hasTotalKeyword: hasTotalKeyword,
      hasCurrency: hasCurrency,
      hasDate: hasDate,
      hasMerchantOrRif: hasMerchantOrRif,
      hasSufficientLines: hasSufficientLines,
      lineCount: lineCount,
    );
  }

  void dispose() {
    _recognizer?.close();
  }
}
