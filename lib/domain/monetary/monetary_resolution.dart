import '../../data/models/gasto_model.dart';
import 'rate_market.dart';

enum EstadoValorMonetario {
  identidadOrigen,       // Verificado: total_original en su propia moneda (g.moneda == lente)
  persistidoNoVerificado,// Persistido > 0 en columna secundaria coherente; no verificado en v18
  calculadoNoVerificado, // Calculado solo para lente VES desde identidadOrigen * tasaOrigen (> 1 y no ambigua)
  pendiente,             // Faltante (null o <= 0 con original > 0) o tasa origen ambigua/ausente en lente VES
  incoherente,           // Violación de invariante (ej. I5: total_eur == total_usd con tasas distintas; I6: colapso VES)
}

enum EstadoTasaPersistida {
  persistidoNoVerificado,// Tasa > 1.0 sin colisión ambigua; usable solo para calculadoNoVerificado en lente VES
  noVerificadoAmbiguo,   // Colisión sospechosa (ej. tasa_eur == tasa_cambio en gasto VES/EUR sin respaldo)
  ausente,               // null
  invalidoDominio,       // <= 1.0, NaN o infinito
}

class ValorMonetarioResuelto {
  final int? centavos;
  final EstadoValorMonetario estado;
  final String? motivoNoDisponible;

  const ValorMonetarioResuelto({
    required this.centavos,
    required this.estado,
    this.motivoNoDisponible,
  });

  bool get esVerificado => estado == EstadoValorMonetario.identidadOrigen;
  bool get esContabilizableNoVerificado =>
      estado == EstadoValorMonetario.persistidoNoVerificado ||
      estado == EstadoValorMonetario.calculadoNoVerificado;
  double? get display => centavos != null ? centavos! / 100.0 : null;
}

/// Resuelve el valor monetario de un gasto persistido bajo una lente de visualización
/// de acuerdo con el contrato normativo de RM-03 v1.2.
ValorMonetarioResuelto resolvePersistedExpense({
  required GastoModel gasto,
  required String lente,
}) {
  final m0 = gasto.totalOriginal;
  final lenteClean = lente.toUpperCase().trim();
  final monedaGasto = gasto.moneda.toUpperCase().trim();

  // Caso cero o negativo
  if (m0 == 0) {
    return const ValorMonetarioResuelto(
      centavos: 0,
      estado: EstadoValorMonetario.identidadOrigen,
    );
  }
  if (m0 < 0) {
    return const ValorMonetarioResuelto(
      centavos: null,
      estado: EstadoValorMonetario.incoherente,
      motivoNoDisponible: 'Monto original menor a cero',
    );
  }

  // 1. Identidad de origen: la lente coincide con la moneda del gasto
  if (monedaGasto == lenteClean) {
    return ValorMonetarioResuelto(
      centavos: m0,
      estado: EstadoValorMonetario.identidadOrigen,
    );
  }

  // 2. Lente USD
  if (lenteClean == 'USD') {
    // Invariante I6: colapso VES == USD
    if (monedaGasto == 'VES' && gasto.totalUsd == m0) {
      return const ValorMonetarioResuelto(
        centavos: null,
        estado: EstadoValorMonetario.incoherente,
        motivoNoDisponible: 'Invariante I6: total_usd colapsado con total_original en VES',
      );
    }
    if (gasto.totalUsd > 0) {
      return ValorMonetarioResuelto(
        centavos: gasto.totalUsd,
        estado: EstadoValorMonetario.persistidoNoVerificado,
      );
    }
    return const ValorMonetarioResuelto(
      centavos: null,
      estado: EstadoValorMonetario.pendiente,
      motivoNoDisponible: 'Columna total_usd ausente o <= 0',
    );
  }

  // 3. Lente USDT
  if (lenteClean == 'USDT') {
    // Invariante I6: colapso VES == USDT
    if (monedaGasto == 'VES' && gasto.totalUsdt != null && gasto.totalUsdt == m0) {
      return const ValorMonetarioResuelto(
        centavos: null,
        estado: EstadoValorMonetario.incoherente,
        motivoNoDisponible: 'Invariante I6: total_usdt colapsado con total_original en VES',
      );
    }
    if (gasto.totalUsdt != null && gasto.totalUsdt! > 0) {
      return ValorMonetarioResuelto(
        centavos: gasto.totalUsdt,
        estado: EstadoValorMonetario.persistidoNoVerificado,
      );
    }
    return const ValorMonetarioResuelto(
      centavos: null,
      estado: EstadoValorMonetario.pendiente,
      motivoNoDisponible: 'Columna total_usdt ausente o <= 0',
    );
  }

  // 4. Lente EUR
  if (lenteClean == 'EUR') {
    // Invariante I6: colapso VES == EUR
    if (monedaGasto == 'VES' && gasto.totalEur != null && gasto.totalEur == m0) {
      return const ValorMonetarioResuelto(
        centavos: null,
        estado: EstadoValorMonetario.incoherente,
        motivoNoDisponible: 'Invariante I6: total_eur colapsado con total_original en VES',
      );
    }
    if (gasto.totalEur != null && gasto.totalEur! > 0) {
      // Invariante I5: copia ilegítima EUR = USD
      final tEur = gasto.totalEur!;
      final tUsd = gasto.totalUsd;
      if (tEur == tUsd) {
        final rateEur = gasto.tasaEur;
        final rateUsd = gasto.tasaCambio;
        final bool ratesDifieren = rateEur == null ||
            (rateEur - rateUsd).abs() > 1e-6;
        if (ratesDifieren) {
          return const ValorMonetarioResuelto(
            centavos: null,
            estado: EstadoValorMonetario.incoherente,
            motivoNoDisponible: 'Invariante I5: total_eur copiado de total_usd con tasas divergentes',
          );
        }
      }
      return ValorMonetarioResuelto(
        centavos: tEur,
        estado: EstadoValorMonetario.persistidoNoVerificado,
      );
    }
    return const ValorMonetarioResuelto(
      centavos: null,
      estado: EstadoValorMonetario.pendiente,
      motivoNoDisponible: 'Columna total_eur ausente o <= 0',
    );
  }

  // 5. Lente VES (cuando monedaGasto != 'VES')
  if (lenteClean == 'VES') {
    double? rOrig;
    bool esAmbiguo = false;

    if (monedaGasto == 'USD') {
      rOrig = gasto.tasaCambio;
    } else if (monedaGasto == 'USDT') {
      rOrig = gasto.tasaUsdt;
    } else if (monedaGasto == 'EUR') {
      rOrig = gasto.tasaEur;
      // Comprobar colisión ambigua: tasaEur == tasaCambio
      if (rOrig != null && (rOrig - gasto.tasaCambio).abs() <= 1e-6) {
        esAmbiguo = true;
      }
    }

    EstadoTasaPersistida estadoTasa;
    if (rOrig == null) {
      estadoTasa = EstadoTasaPersistida.ausente;
    } else if (!isValidMonetaryRate(rOrig)) {
      estadoTasa = EstadoTasaPersistida.invalidoDominio;
    } else if (esAmbiguo) {
      estadoTasa = EstadoTasaPersistida.noVerificadoAmbiguo;
    } else {
      estadoTasa = EstadoTasaPersistida.persistidoNoVerificado;
    }

    if (estadoTasa == EstadoTasaPersistida.persistidoNoVerificado) {
      return ValorMonetarioResuelto(
        centavos: (m0 * rOrig!).round(),
        estado: EstadoValorMonetario.calculadoNoVerificado,
      );
    }

    return ValorMonetarioResuelto(
      centavos: null,
      estado: EstadoValorMonetario.pendiente,
      motivoNoDisponible: 'Tasa origen ausente, inválida o ambigua ($estadoTasa) para calcular VES',
    );
  }

  // Lente no soportada
  return const ValorMonetarioResuelto(
    centavos: null,
    estado: EstadoValorMonetario.incoherente,
    motivoNoDisponible: 'Lente no soportada',
  );
}

/// Comprueba si dos instancias de [GastoModel] poseen contenido de negocio idéntico,
/// excluyendo metadatos transaccionales y locales de sincronización (`synced`, `firestoreId`,
/// `rutaFotoLocal`, `ocrText`, `id`, `creadoEn`, `actualizadoEn`).
///
/// Utilizado para idempotencia post-crash y control de concurrencia optimista conforme
/// al contrato normativo de RM-03 v1.2 §4.
bool sonContenidoNegocioIdentico(GastoModel a, GastoModel b) {
  if (a.uuid != b.uuid) return false;
  if (a.fecha != b.fecha) return false;
  if (a.comercio.trim().toLowerCase() != b.comercio.trim().toLowerCase()) return false;
  if (a.moneda.toUpperCase().trim() != b.moneda.toUpperCase().trim()) return false;
  if (a.totalOriginal != b.totalOriginal) return false;
  if (a.totalUsd != b.totalUsd) return false;
  if (a.totalUsdt != b.totalUsdt) return false;
  if (a.totalEur != b.totalEur) return false;
  if ((a.tasaCambio - b.tasaCambio).abs() > 0.0001) return false;
  final aTasaUsdt = a.tasaUsdt ?? 0.0;
  final bTasaUsdt = b.tasaUsdt ?? 0.0;
  if ((aTasaUsdt - bTasaUsdt).abs() > 0.0001) return false;
  final aTasaEur = a.tasaEur ?? 0.0;
  final bTasaEur = b.tasaEur ?? 0.0;
  if ((aTasaEur - bTasaEur).abs() > 0.0001) return false;
  if (a.categoria.trim().toLowerCase() != b.categoria.trim().toLowerCase()) return false;
  if (a.eliminadoEn != b.eliminadoEn) return false;

  final itemsA = a.items;
  final itemsB = b.items;
  if (itemsA.length != itemsB.length) return false;
  for (int i = 0; i < itemsA.length; i++) {
    final itA = itemsA[i];
    final itB = itemsB[i];
    if (itA.descripcion.trim().toLowerCase() != itB.descripcion.trim().toLowerCase()) return false;
    if (itA.cantidad != itB.cantidad) return false;
    if (itA.precioUnitario != itB.precioUnitario) return false;
    if (itA.total != itB.total) return false;
    if (itA.categoria.trim().toLowerCase() != itB.categoria.trim().toLowerCase()) return false;
  }

  return true;
}
