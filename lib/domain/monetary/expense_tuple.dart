import 'metodo_liquidacion.dart';
import 'rate_market.dart';
import 'rate_quote_input.dart';

/// Tupla inmutable que representa los importes congelados y tasas de un nuevo gasto.
class ExpenseTuple {
  final String monedaOriginal;
  final String monedaPersistida;
  final int totalOriginalCentavos;
  final int totalUsdCentavos;
  final int totalUsdtCentavos;
  final int totalEurCentavos;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;
  final String fuenteTasaCambio;
  final String fechaTasaCambio;
  final MetodoLiquidacion metodoLiquidacion;

  const ExpenseTuple({
    required this.monedaOriginal,
    required this.monedaPersistida,
    required this.totalOriginalCentavos,
    required this.totalUsdCentavos,
    required this.totalUsdtCentavos,
    required this.totalEurCentavos,
    required this.tasaCambio,
    required this.tasaEur,
    required this.tasaUsdt,
    required this.fuenteTasaCambio,
    required this.fechaTasaCambio,
    required this.metodoLiquidacion,
  });

  double get totalOriginalDisplay => totalOriginalCentavos / 100.0;
  double get totalUsdDisplay => totalUsdCentavos / 100.0;
  double get totalUsdtDisplay => totalUsdtCentavos / 100.0;
  double get totalEurDisplay => totalEurCentavos / 100.0;
}

enum TupleFailureCode {
  cotizacionInvalida,
  combinacionMonedaLiquidacionNoSoportada,
  montoInvalido,
  monedaNoSoportada,
}

sealed class TupleBuildResult {
  const TupleBuildResult();
}

class TupleBuildSuccess extends TupleBuildResult {
  final ExpenseTuple tuple;
  const TupleBuildSuccess(this.tuple);
}

class TupleBuildFailure extends TupleBuildResult {
  final TupleFailureCode code;
  final String userMessage;
  final RateMarket? failedMarket;
  final QuoteValidationError? quoteError;

  const TupleBuildFailure({
    required this.code,
    required this.userMessage,
    this.failedMarket,
    this.quoteError,
  });
}

/// Construye la tupla inmutable de un nuevo gasto aplicando estrictamente las fórmulas y
/// validaciones normativas de RM-03 v1.2.
TupleBuildResult buildNewExpenseTuple({
  required String monedaOriginal,
  required int montoOriginalCentavos,
  required MetodoLiquidacion metodo,
  required String fechaGasto,
  required RateQuoteInput cotizacionUsd,
  required RateQuoteInput cotizacionEur,
  required RateQuoteInput cotizacionUsdt,
  int? montoVesManualCentavos,
}) {
  // 1. Validación de monto
  if (montoOriginalCentavos <= 0) {
    return const TupleBuildFailure(
      code: TupleFailureCode.montoInvalido,
      userMessage: 'El monto original debe ser mayor a cero.',
    );
  }

  // 2. Validación de cotizaciones obligatorias
  final errUsd = cotizacionUsd.validateFor(
    expectedMarket: RateMarket.usdOficial,
    fechaGasto: fechaGasto,
  );
  if (errUsd != null) {
    return TupleBuildFailure(
      code: TupleFailureCode.cotizacionInvalida,
      userMessage: 'Cotización USD inválida para la fecha: $errUsd',
      failedMarket: RateMarket.usdOficial,
      quoteError: errUsd,
    );
  }

  final errEur = cotizacionEur.validateFor(
    expectedMarket: RateMarket.eurOficial,
    fechaGasto: fechaGasto,
  );
  if (errEur != null) {
    return TupleBuildFailure(
      code: TupleFailureCode.cotizacionInvalida,
      userMessage: 'Cotización EUR inválida para la fecha: $errEur',
      failedMarket: RateMarket.eurOficial,
      quoteError: errEur,
    );
  }

  final errUsdt = cotizacionUsdt.validateFor(
    expectedMarket: RateMarket.usdtP2p,
    fechaGasto: fechaGasto,
  );
  if (errUsdt != null) {
    return TupleBuildFailure(
      code: TupleFailureCode.cotizacionInvalida,
      userMessage: 'Cotización USDT inválida para la fecha: $errUsdt',
      failedMarket: RateMarket.usdtP2p,
      quoteError: errUsdt,
    );
  }

  final rUsd = cotizacionUsd.valor;
  final rEur = cotizacionEur.valor;
  final rUsdt = cotizacionUsdt.valor;
  final fechaTasa = fechaGasto;

  final monedaClean = monedaOriginal.toUpperCase().trim();

  // 3. Bloqueo normativo en Fase 0A: EUR + BS_USDT
  if (monedaClean == 'EUR' && metodo == MetodoLiquidacion.bsUsdt) {
    return const TupleBuildFailure(
      code: TupleFailureCode.combinacionMonedaLiquidacionNoSoportada,
      userMessage: 'El pago en Bs. indexado a USDT solo aplica a precios en USD/USDT. '
          'Si el precio estaba en EUR y pagaste en Bs. a otra tasa, registra el monto pagado en Bs. (VES).',
    );
  }

  // 4. Casos operativos de RM-03 v1.2
  switch (monedaClean) {
    case 'VES':
      if (metodo != MetodoLiquidacion.divisa) {
        return const TupleBuildFailure(
          code: TupleFailureCode.combinacionMonedaLiquidacionNoSoportada,
          userMessage: 'Los gastos en Bolívares (VES) solo admiten registro directo.',
        );
      }
      return TupleBuildSuccess(
        ExpenseTuple(
          monedaOriginal: 'VES',
          monedaPersistida: 'VES',
          totalOriginalCentavos: montoOriginalCentavos,
          totalUsdCentavos: (montoOriginalCentavos / rUsd).round(),
          totalEurCentavos: (montoOriginalCentavos / rEur).round(),
          totalUsdtCentavos: (montoOriginalCentavos / rUsdt).round(),
          tasaCambio: rUsd,
          tasaEur: rEur,
          tasaUsdt: rUsdt,
          fuenteTasaCambio: 'VES_DIRECTO',
          fechaTasaCambio: fechaTasa,
          metodoLiquidacion: metodo,
        ),
      );

    case 'USD':
      switch (metodo) {
        case MetodoLiquidacion.divisa:
          // Caso 2: USD en Divisa directa (paridad 1:1 USD/USDT en DIVISA)
          return TupleBuildSuccess(
            ExpenseTuple(
              monedaOriginal: 'USD',
              monedaPersistida: 'USD',
              totalOriginalCentavos: montoOriginalCentavos,
              totalUsdCentavos: montoOriginalCentavos,
              totalUsdtCentavos: montoOriginalCentavos,
              totalEurCentavos: ((montoOriginalCentavos * rUsd) / rEur).round(),
              tasaCambio: rUsd,
              tasaEur: rEur,
              tasaUsdt: rUsdt,
              fuenteTasaCambio: 'DIVISA_DIRECTA',
              fechaTasaCambio: fechaTasa,
              metodoLiquidacion: metodo,
            ),
          );

        case MetodoLiquidacion.bsBcv:
          // Caso 4: USD indexado a BCV
          final totalBs = (montoVesManualCentavos != null && montoVesManualCentavos > 0)
              ? montoVesManualCentavos
              : (montoOriginalCentavos * rUsd).round();
          return TupleBuildSuccess(
            ExpenseTuple(
              monedaOriginal: 'USD',
              monedaPersistida: 'VES',
              totalOriginalCentavos: totalBs,
              totalUsdCentavos: montoOriginalCentavos,
              totalEurCentavos: (totalBs / rEur).round(),
              totalUsdtCentavos: (totalBs / rUsdt).round(),
              tasaCambio: rUsd,
              tasaEur: rEur,
              tasaUsdt: rUsdt,
              fuenteTasaCambio: 'USD_BCV_INDEXADO',
              fechaTasaCambio: fechaTasa,
              metodoLiquidacion: metodo,
            ),
          );

        case MetodoLiquidacion.bsUsdt:
          // Caso 6: USD indexado a USDT P2P
          final totalBs = (montoVesManualCentavos != null && montoVesManualCentavos > 0)
              ? montoVesManualCentavos
              : (montoOriginalCentavos * rUsdt).round();
          return TupleBuildSuccess(
            ExpenseTuple(
              monedaOriginal: 'USD',
              monedaPersistida: 'VES',
              totalOriginalCentavos: totalBs,
              totalUsdCentavos: (totalBs / rUsd).round(),
              totalEurCentavos: (totalBs / rEur).round(),
              totalUsdtCentavos: montoOriginalCentavos,
              tasaCambio: rUsd,
              tasaEur: rEur,
              tasaUsdt: rUsdt,
              fuenteTasaCambio: 'USDT_INDEXADO',
              fechaTasaCambio: fechaTasa,
              metodoLiquidacion: metodo,
            ),
          );
      }

    case 'EUR':
      switch (metodo) {
        case MetodoLiquidacion.divisa:
          // Caso 7: EUR en Divisa directa
          final equivVes = (montoOriginalCentavos * rEur).round();
          return TupleBuildSuccess(
            ExpenseTuple(
              monedaOriginal: 'EUR',
              monedaPersistida: 'EUR',
              totalOriginalCentavos: montoOriginalCentavos,
              totalUsdCentavos: (equivVes / rUsd).round(),
              totalEurCentavos: montoOriginalCentavos,
              totalUsdtCentavos: (equivVes / rUsdt).round(),
              tasaCambio: rUsd,
              tasaEur: rEur,
              tasaUsdt: rUsdt,
              fuenteTasaCambio: 'DIVISA_DIRECTA',
              fechaTasaCambio: fechaTasa,
              metodoLiquidacion: metodo,
            ),
          );

        case MetodoLiquidacion.bsBcv:
          // Caso 5: EUR indexado a BCV
          final totalBs = (montoVesManualCentavos != null && montoVesManualCentavos > 0)
              ? montoVesManualCentavos
              : (montoOriginalCentavos * rEur).round();
          return TupleBuildSuccess(
            ExpenseTuple(
              monedaOriginal: 'EUR',
              monedaPersistida: 'VES',
              totalOriginalCentavos: totalBs,
              totalUsdCentavos: (totalBs / rUsd).round(),
              totalEurCentavos: montoOriginalCentavos,
              totalUsdtCentavos: (totalBs / rUsdt).round(),
              tasaCambio: rUsd,
              tasaEur: rEur,
              tasaUsdt: rUsdt,
              fuenteTasaCambio: 'EUR_BCV_INDEXADO',
              fechaTasaCambio: fechaTasa,
              metodoLiquidacion: metodo,
            ),
          );

        case MetodoLiquidacion.bsUsdt:
          return const TupleBuildFailure(
            code: TupleFailureCode.combinacionMonedaLiquidacionNoSoportada,
            userMessage: 'El pago en Bs. indexado a USDT solo aplica a precios en USD/USDT.',
          );
      }

    case 'USDT':
      switch (metodo) {
        case MetodoLiquidacion.divisa:
          // Caso 3: USDT en Divisa directa (paridad 1:1 USD/USDT en DIVISA)
          return TupleBuildSuccess(
            ExpenseTuple(
              monedaOriginal: 'USDT',
              monedaPersistida: 'USDT',
              totalOriginalCentavos: montoOriginalCentavos,
              totalUsdCentavos: montoOriginalCentavos,
              totalUsdtCentavos: montoOriginalCentavos,
              totalEurCentavos: ((montoOriginalCentavos * rUsd) / rEur).round(),
              tasaCambio: rUsd,
              tasaEur: rEur,
              tasaUsdt: rUsdt,
              fuenteTasaCambio: 'USDT_DIRECTO',
              fechaTasaCambio: fechaTasa,
              metodoLiquidacion: metodo,
            ),
          );

        case MetodoLiquidacion.bsUsdt:
          // Caso 8: USDT indexado a USDT P2P
          final totalBs = (montoVesManualCentavos != null && montoVesManualCentavos > 0)
              ? montoVesManualCentavos
              : (montoOriginalCentavos * rUsdt).round();
          return TupleBuildSuccess(
            ExpenseTuple(
              monedaOriginal: 'USDT',
              monedaPersistida: 'VES',
              totalOriginalCentavos: totalBs,
              totalUsdCentavos: (totalBs / rUsd).round(),
              totalEurCentavos: (totalBs / rEur).round(),
              totalUsdtCentavos: montoOriginalCentavos,
              tasaCambio: rUsd,
              tasaEur: rEur,
              tasaUsdt: rUsdt,
              fuenteTasaCambio: 'USDT_INDEXADO',
              fechaTasaCambio: fechaTasa,
              metodoLiquidacion: metodo,
            ),
          );

        case MetodoLiquidacion.bsBcv:
          return const TupleBuildFailure(
            code: TupleFailureCode.combinacionMonedaLiquidacionNoSoportada,
            userMessage: 'El método BCV no aplica a precios en USDT. Utiliza pago en divisa o indexado a USDT.',
          );
      }

    default:
      return TupleBuildFailure(
        code: TupleFailureCode.monedaNoSoportada,
        userMessage: 'Moneda no soportada: $monedaOriginal',
      );
  }
}
