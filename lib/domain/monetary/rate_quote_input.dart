import 'rate_market.dart';

enum QuoteValidationError {
  mercadoIncorrecto,
  fuenteNoAutorizadaParaMercado,
  endpointCampoVacio,
  valorFueraDeDominio,
  fechaSolicitadaNoCoincideConGasto,
  formatoFechaInvalido,
  fechaEfectivaFutura,
  fechaEfectivaAnteriorMinima,
  inconsistenciaExactitudFecha,
  referenciaSinConfirmacionUsuario,
  manualSinConfirmacionUsuario,
}

class RateQuoteInput {
  final RateMarket mercado;
  final RateSourceId sourceId;
  final String endpointOrField;     // Ej. 'worker:/rates#eur', 'dolarapi:/v1/dolares/oficial#promedio', 'manual:input_tasa'
  final double valor;               // VES por 1 unidad de [mercado]
  final String fechaSolicitada;     // YYYY-MM-DD
  final String fechaEfectiva;       // YYYY-MM-DD
  final bool esExacta;              // true solo si es tasa oficial/P2P exacta de la fechaSolicitada
  final bool esReferencia;          // true si proviene de fallback temporal (<= 5 días) o caché no exacta
  final bool confirmadaPorUsuario;  // true si el usuario aceptó explícitamente usar referencia o ingresó tasa manual

  const RateQuoteInput({
    required this.mercado,
    required this.sourceId,
    required this.endpointOrField,
    required this.valor,
    required this.fechaSolicitada,
    required this.fechaEfectiva,
    required this.esExacta,
    required this.esReferencia,
    this.confirmadaPorUsuario = false,
  });

  static final RegExp _isoDateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static const String _minValidDate = '2023-01-03';

  static bool _isValidCalendarDate(String dateStr) {
    if (!_isoDateRegex.hasMatch(dateStr)) return false;
    final parts = dateStr.split('-');
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return false;
    if (m < 1 || m > 12) return false;
    if (d < 1 || d > 31) return false;
    final dt = DateTime(y, m, d);
    return dt.year == y && dt.month == m && dt.day == d;
  }

  QuoteValidationError? validateFor({
    required RateMarket expectedMarket,
    required String fechaGasto,
  }) {
    // 1. Mercado esperado por el slot
    if (mercado != expectedMarket) {
      return QuoteValidationError.mercadoIncorrecto;
    }

    // 2. Fuente autorizada para el mercado concreto
    if (!allowedSourcesForMarket(expectedMarket).contains(sourceId)) {
      return QuoteValidationError.fuenteNoAutorizadaParaMercado;
    }

    // 3. Trazabilidad de endpoint o campo de respuesta
    if (endpointOrField.trim().isEmpty) {
      return QuoteValidationError.endpointCampoVacio;
    }

    // 4. Dominio numérico (D-08: val is num && val.isFinite && val > 1.0)
    if (!isValidMonetaryRate(valor)) {
      return QuoteValidationError.valorFueraDeDominio;
    }

    // 5. Formato de fechas e igualdad fechaSolicitada == fechaGasto
    if (!_isValidCalendarDate(fechaSolicitada) ||
        !_isValidCalendarDate(fechaEfectiva) ||
        !_isValidCalendarDate(fechaGasto)) {
      return QuoteValidationError.formatoFechaInvalido;
    }
    if (fechaSolicitada != fechaGasto) {
      return QuoteValidationError.fechaSolicitadaNoCoincideConGasto;
    }

    // 6. Fecha efectiva nunca futura respecto a la fecha solicitada
    if (fechaEfectiva.compareTo(fechaSolicitada) > 0) {
      return QuoteValidationError.fechaEfectivaFutura;
    }

    // 7. Fecha efectiva >= 2023-01-03 para fuentes automáticas
    if (sourceId != RateSourceId.manualUsuario &&
        fechaEfectiva.compareTo(_minValidDate) < 0) {
      return QuoteValidationError.fechaEfectivaAnteriorMinima;
    }

    // 8. Tratamiento seguro de tasas manuales
    if (sourceId == RateSourceId.manualUsuario) {
      if (!confirmadaPorUsuario) {
        return QuoteValidationError.manualSinConfirmacionUsuario;
      }
      if (esExacta) {
        // Una tasa manual nunca se clasifica como cotización oficial exacta de mercado
        return QuoteValidationError.inconsistenciaExactitudFecha;
      }
      return null;
    }

    // 9. Coherencia entre exactitud, fechaEfectiva y flag de referencia
    if (esExacta) {
      if (fechaEfectiva != fechaSolicitada || esReferencia) {
        return QuoteValidationError.inconsistenciaExactitudFecha;
      }
    } else {
      // Si no es exacta (o esReferencia == true o fechaEfectiva < fechaSolicitada),
      // exige confirmación explícita del usuario antes de construir el tuple.
      if (!confirmadaPorUsuario) {
        return QuoteValidationError.referenciaSinConfirmacionUsuario;
      }
    }

    return null;
  }
}
