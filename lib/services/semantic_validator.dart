import '../data/models/gemini_extraction_result.dart';

/// Validador semántico multicriterio para comprobar si la extracción
/// estructurada devuelta por Gemini Texto es plausible y coherente
/// antes de aceptarla, o si debe activarse el fallback a Gemini Visión.
class SemanticValidator {
  final double tolerancePercentage;

  const SemanticValidator({this.tolerancePercentage = 0.15});

  /// Evalúa una lista de resultados de extracción.
  /// Retorna [SemanticValidationResult] con el veredicto y el motivo si falla.
  SemanticValidationResult validate(List<GeminiExtractionResult> results) {
    if (results.isEmpty) {
      return const SemanticValidationResult(
        isValid: false,
        reason: 'La extracción no devolvió ninguna factura.',
      );
    }

    for (int i = 0; i < results.length; i++) {
      final factura = results[i];

      // 1. Plausibilidad básica: Debe tener al menos comercio o un monto total válido
      final hasComercio = factura.comercio.trim().isNotEmpty &&
          factura.comercio.toLowerCase() != 'comercio desconocido' &&
          factura.comercio.toLowerCase() != 'null';

      final hasValidTotal = factura.totalOriginal > 0;

      if (!hasComercio && !hasValidTotal) {
        return SemanticValidationResult(
          isValid: false,
          reason: 'Factura #${i + 1} no tiene comercio ni total válidos.',
        );
      }

      // 2. Si la factura tiene ítems detallados, validar coherencia numérica
      if (factura.items.isNotEmpty) {
        double itemsSum = 0.0;
        for (final item in factura.items) {
          itemsSum += (item.total / 100.0);
        }

        // Si hay impuesto desglosado, sumarlo
        final totalWithTax = itemsSum + (factura.impuestoIva ?? 0.0);

        if (factura.totalOriginal > 0 && totalWithTax > 0) {
          final diff = (factura.totalOriginal - totalWithTax).abs();
          final maxAllowedDiff = factura.totalOriginal * tolerancePercentage;

          // Se permite discrepancia si la diferencia es menor al porcentaje de tolerancia
          // o si es una diferencia pequeña por redondeo de centavos (<= 1.0)
          if (diff > maxAllowedDiff && diff > 1.0) {
            return SemanticValidationResult(
              isValid: false,
              reason: 'Discrepancia en factura #${i + 1}: Total (${factura.totalOriginal}) difiere de suma de ítems ($totalWithTax) por $diff (límite: $maxAllowedDiff).',
            );
          }
        }
      }
    }

    return const SemanticValidationResult(isValid: true);
  }
}

class SemanticValidationResult {
  final bool isValid;
  final String? reason;

  const SemanticValidationResult({
    required this.isValid,
    this.reason,
  });
}
