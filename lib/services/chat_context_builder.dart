import '../data/datasources/local/database_helper.dart';
import '../data/models/gasto_model.dart';
import '../data/models/shopping_item_model.dart';
import '../domain/finance/savings_health_models.dart';
import 'chat_signal_selector.dart';

/// Constructor determinista único del contexto financiero del Asistente IA (Etapa 0).
/// Garantiza:
/// - Fecha y período en hora de Venezuela (UTC-4, sin horario de verano).
/// - Normalización fiscal AI-06 y agrupación canónica de productos (`normalizeProductText`).
/// - Guarda `proyeccion_confiable` que bloquea extrapolaciones en días 1–3, con < 3 gastos
///   o en meses cerrados.
/// - Reutilización sin duplicación entre Inicio (`insight_inicio`), `Consultar ->` y Chat normal.
class ChatContextBuilder {
  static const Duration venezuelaOffset = Duration(hours: 4);
  static const int minDaysForReliableProjection = 3;
  static const int minExpensesForReliableProjection = 3;

  static final RegExp _trailingFiscalSuffix = RegExp(
    r'(?:\s*\([GERgerExX]+\)|\s*-(?:G|E|R))\s*$',
    caseSensitive: false,
  );

  /// Convierte un instante absoluto a fecha/hora calendario de Venezuela (UTC-4).
  static DateTime venezuelaDateFromInstant(DateTime instant) {
    final vet = instant.toUtc().subtract(venezuelaOffset);
    return DateTime(
      vet.year,
      vet.month,
      vet.day,
      vet.hour,
      vet.minute,
      vet.second,
    );
  }

  /// Resuelve la fecha calendario en hora de Venezuela (UTC-4).
  /// - Sin parámetro: convierte `DateTime.now()` a UTC-4.
  /// - Con `DateTime.utc(...)`: convierte ese instante UTC a UTC-4.
  /// - Con `DateTime(y, m, d)` local (p. ej. fechas fijas en tests): respeta su fecha calendario.
  static DateTime resolveVenezuelaDate({DateTime? currentDate}) {
    if (currentDate == null) {
      return venezuelaDateFromInstant(DateTime.now());
    }
    if (currentDate.isUtc) {
      return venezuelaDateFromInstant(currentDate);
    }
    return currentDate;
  }

  /// Formatea una fecha como ISO `YYYY-MM-DD`.
  static String formatIsoDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Formatea un mes como `YYYY-MM`.
  static String formatYearMonth(int year, int month) {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    return '$y-$m';
  }

  /// Calcula la fecha exacta de Black Friday (viernes posterior al 4.º jueves de noviembre).
  static DateTime calculateBlackFriday(int year) {
    final novFirst = DateTime.utc(year, 11, 1);
    final daysUntilFirstThursday = (DateTime.thursday - novFirst.weekday + 7) % 7;
    final fourthThursdayDay = 1 + daysUntilFirstThursday + 21;
    return DateTime(year, 11, fourthThursdayDay + 1);
  }

  /// Calcula hitos puramente deterministas de calendario (preparado para Etapa 1).
  static List<Map<String, dynamic>> computeCalculableMilestones(DateTime vetDate) {
    final milestones = <Map<String, dynamic>>[];
    final daysInMonth = DateTime(vetDate.year, vetDate.month + 1, 0).day;
    final remaining = (daysInMonth - vetDate.day).clamp(0, daysInMonth);
    if (remaining <= 3) {
      milestones.add({
        'id': 'cierre_de_mes',
        'dias_restantes': remaining,
      });
    }

    final blackFriday = calculateBlackFriday(vetDate.year);
    final diffBf = DateTime.utc(blackFriday.year, blackFriday.month, blackFriday.day)
        .difference(DateTime.utc(vetDate.year, vetDate.month, vetDate.day))
        .inDays;
    if (diffBf >= 0 && diffBf <= 7) {
      milestones.add({
        'id': 'black_friday',
        'fecha': formatIsoDate(blackFriday),
        'dias_para_evento': diffBf,
      });
    }

    return milestones;
  }

  /// Construye `contexto_temporal` con fuente única sobre `SavingsHealthSnapshot` y hora VE.
  static Map<String, dynamic> buildTemporalContext({
    required int selectedYear,
    required int selectedMonth,
    required int cantidadComprasMes,
    required SavingsHealthSnapshot savingsSnapshot,
    DateTime? currentDate,
  }) {
    final vetNow = resolveVenezuelaDate(currentDate: currentDate);
    final isCurrentMonth =
        selectedYear == vetNow.year && selectedMonth == vetNow.month;
    final diasTotalesMes = DateTime(selectedYear, selectedMonth + 1, 0).day;
    final diasTranscurridos =
        isCurrentMonth ? vetNow.day.clamp(1, diasTotalesMes) : diasTotalesMes;
    final diasRestantes = isCurrentMonth
        ? (diasTotalesMes - diasTranscurridos).clamp(0, diasTotalesMes)
        : 0;
    final porcentajeMes =
        ((diasTranscurridos / diasTotalesMes) * 100).round().clamp(0, 100);
    final gastoDiarioPromedio = diasTranscurridos > 0
        ? savingsSnapshot.gastoAcumulado / diasTranscurridos
        : 0.0;

    String? motivoSinProyeccion;
    if (!isCurrentMonth) {
      motivoSinProyeccion = 'mes_cerrado';
    } else if (diasTranscurridos <= minDaysForReliableProjection) {
      motivoSinProyeccion = 'inicio_de_mes';
    } else if (cantidadComprasMes < minExpensesForReliableProjection) {
      motivoSinProyeccion = 'pocos_gastos';
    }

    final bool proyeccionConfiable = motivoSinProyeccion == null;
    final double? gastoProyectadoFinMes = proyeccionConfiable
        ? double.parse((gastoDiarioPromedio * diasTotalesMes).toStringAsFixed(2))
        : null;

    return {
      'fecha_hoy_ve': formatIsoDate(vetNow),
      'periodo_consultado': formatYearMonth(selectedYear, selectedMonth),
      'es_mes_actual': isCurrentMonth,
      'dias_transcurridos': diasTranscurridos,
      'dias_totales_mes': diasTotalesMes,
      'porcentaje_mes_transcurrido': porcentajeMes,
      'dias_restantes_mes': diasRestantes,
      'es_cierre_de_mes': isCurrentMonth && diasRestantes <= 3,
      'cantidad_compras_mes': cantidadComprasMes,
      'moneda_presupuesto': savingsSnapshot.moneda,
      'gasto_diario_promedio':
          double.parse(gastoDiarioPromedio.toStringAsFixed(2)),
      'proyeccion_confiable': proyeccionConfiable,
      'gasto_proyectado_fin_mes': gastoProyectadoFinMes,
      'motivo_sin_proyeccion': motivoSinProyeccion,
    };
  }

  static String _cleanDisplayProductName(String rawName) {
    final trimmed = rawName.trim();
    final cleaned = trimmed.replaceAll(_trailingFiscalSuffix, '').trim();
    return cleaned.isNotEmpty ? cleaned : trimmed;
  }

  /// Construye el ranking de productos más relevantes ordenados por `total_usd` descendente,
  /// agrupando con `DatabaseHelper.normalizeProductText` y aplicando el factor fiscal `AI-06`
  /// (`shelfPriceFactorForCurrentItems`) para no subestimar facturas legadas en base.
  static List<Map<String, dynamic>> buildTopProducts(
    List<GastoModel> gastos, {
    int limit = 10,
    bool includeQuantity = true,
  }) {
    final Map<String, Map<String, dynamic>> productMap = {};

    for (final g in gastos) {
      final double gastoUsd = g.totalUsd / 100.0;
      for (final item in g.items) {
        final rawName = item.descripcion.trim();
        if (rawName.isEmpty || DatabaseHelper.isTaxItem(rawName)) continue;

        final norm = DatabaseHelper.normalizeProductText(rawName);
        final key = norm.isNotEmpty ? norm : rawName.toLowerCase();
        final displayName = _cleanDisplayProductName(rawName);

        final double taxFactor = DatabaseHelper.shelfPriceFactorForCurrentItems(
          targetItem: item,
          allItems: g.items,
        );
        final double rawItemUsd = (g.totalOriginal > 0)
            ? (item.total / g.totalOriginal) * gastoUsd
            : (item.total / 100.0);
        final double itemUsd = rawItemUsd * taxFactor;

        final existing = productMap[key] ??
            {
              'producto': displayName,
              'cantidad': 0.0,
              'total_usd': 0.0,
              'veces': 0,
            };

        existing['cantidad'] = (existing['cantidad'] as double) + item.cantidad;
        existing['total_usd'] = (existing['total_usd'] as double) + itemUsd;
        existing['veces'] = (existing['veces'] as int) + 1;
        productMap[key] = existing;
      }
    }

    final sorted = productMap.values.toList()
      ..sort((a, b) {
        final byUsd =
            (b['total_usd'] as double).compareTo(a['total_usd'] as double);
        if (byUsd != 0) return byUsd;
        return (b['cantidad'] as double).compareTo(a['cantidad'] as double);
      });

    return sorted.take(limit).map((p) {
      if (includeQuantity) {
        return {
          'producto': p['producto'],
          'cantidad': double.parse((p['cantidad'] as double).toStringAsFixed(1)),
          'total_usd':
              double.parse((p['total_usd'] as double).toStringAsFixed(2)),
          'veces_comprado': p['veces'],
        };
      }
      return {
        'producto': p['producto'],
        'veces': p['veces'],
        'total_usd': double.parse((p['total_usd'] as double).toStringAsFixed(2)),
      };
    }).toList();
  }

  /// Construye el top de comercios del mes ordenados por `total_usd` descendente.
  static List<Map<String, dynamic>> buildTopComercios(
    List<GastoModel> gastos, {
    int limit = 3,
  }) {
    final Map<String, Map<String, dynamic>> comerciosMap = {};

    for (final g in gastos) {
      final comName = DatabaseHelper.formatCommerceDisplay(g.comercio);
      final lower = comName.toLowerCase();
      if (comName.isEmpty || lower == 'varios' || lower == 'otro comercio') {
        continue;
      }
      final normKey = DatabaseHelper.normalizeCommerce(comName);
      final key = normKey.isNotEmpty ? normKey : lower;
      final entry = comerciosMap[key] ??
          {
            'comercio': comName,
            'visitas': 0,
            'total_usd': 0.0,
          };
      entry['visitas'] = (entry['visitas'] as int) + 1;
      entry['total_usd'] = (entry['total_usd'] as double) + (g.totalUsd / 100.0);
      comerciosMap[key] = entry;
    }

    final sorted = comerciosMap.values.toList()
      ..sort((a, b) =>
          (b['total_usd'] as double).compareTo(a['total_usd'] as double));

    return sorted
        .take(limit)
        .map((c) => {
              'comercio': c['comercio'],
              'visitas': c['visitas'],
              'total_usd':
                  double.parse((c['total_usd'] as double).toStringAsFixed(2)),
            })
        .toList();
  }

  /// Construye el payload semántico unificado para Chat normal y `Consultar ->`.
  static Map<String, dynamic> buildSemanticChatContext({
    required List<GastoModel> gastos,
    required int selectedYear,
    required int selectedMonth,
    required double totalMesUsd,
    required double totalMesUsdt,
    required double totalMesVes,
    required double tasaCambioVesUsd,
    required double tasaCambioVesEur,
    required double tasaCambioVesUsdt,
    required double presupuestoGeneral,
    required double metaAhorro,
    required String monedaPresupuesto,
    required String monedaPrincipal,
    required Map<String, double> presupuestosPorCategoria,
    required SavingsHealthSnapshot savingsSnapshot,
    required List<ShoppingItemModel> shoppingItems,
    required ChatSignalSelection selection,
    Map<String, dynamic>? hiddenSignalsJson,
    DateTime? currentDate,
  }) {
    final vetNow = resolveVenezuelaDate(currentDate: currentDate);
    final temporalContext = buildTemporalContext(
      selectedYear: selectedYear,
      selectedMonth: selectedMonth,
      cantidadComprasMes: gastos.length,
      savingsSnapshot: savingsSnapshot,
      currentDate: vetNow,
    );

    // 1. Totales acumulados por categoría en USD
    final Map<String, double> totalesCategoria = {};
    for (final g in gastos) {
      totalesCategoria[g.categoria] =
          (totalesCategoria[g.categoria] ?? 0.0) + (g.totalUsd / 100.0);
    }

    // 2. Top 10 productos normalizados (AI-06) ordenados por impacto en USD
    final top10Productos = buildTopProducts(
      gastos,
      limit: 10,
      includeQuantity: true,
    );

    // 3. Últimas 5 compras del mes
    final sortedGastos = List<GastoModel>.from(gastos)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));
    final ultimasCompras = sortedGastos
        .take(5)
        .map((g) => {
              'fecha': g.fecha,
              'comercio': g.comercio,
              'categoria': g.categoria,
              'moneda': g.moneda,
              'monto_original':
                  double.parse((g.totalOriginal / 100.0).toStringAsFixed(2)),
              'total_usd':
                  double.parse((g.totalUsd / 100.0).toStringAsFixed(2)),
              'total_usdt': double.parse(
                ((g.totalUsdt ?? g.totalUsd) / 100.0).toStringAsFixed(2),
              ),
            })
        .toList();

    final double totalEurBcv = (tasaCambioVesEur > 0 && totalMesVes > 0)
        ? double.parse((totalMesVes / tasaCambioVesEur).toStringAsFixed(2))
        : (tasaCambioVesEur > 0
            ? double.parse(
                (totalMesUsd * tasaCambioVesUsd / tasaCambioVesEur)
                    .toStringAsFixed(2),
              )
            : totalMesUsd);

    final effectiveMainCurrency = monedaPrincipal.trim().isNotEmpty
        ? monedaPrincipal.trim()
        : (monedaPresupuesto.trim().isNotEmpty
            ? monedaPresupuesto.trim()
            : 'USD');

    final bool proyeccionConfiable =
        temporalContext['proyeccion_confiable'] == true;
    final String estadoMetaEfectivo = (!proyeccionConfiable &&
            savingsSnapshot.status == SavingsGoalStatus.enRiesgo)
        ? SavingsGoalStatus.protegida.name
        : savingsSnapshot.status.name;

    final contextMap = <String, dynamic>{
      'fecha_hoy': formatIsoDate(vetNow),
      'periodo_consultado': formatYearMonth(selectedYear, selectedMonth),
      'moneda_principal': effectiveMainCurrency,
      'tasa_bcv_usd': tasaCambioVesUsd,
      'tasa_bcv_eur': tasaCambioVesEur,
      'tasa_usdt': tasaCambioVesUsdt,
      'totales_categoria': totalesCategoria
          .map((k, v) => MapEntry(k, double.parse(v.toStringAsFixed(2)))),
      'top_productos_mes': top10Productos,
      'ultimas_compras': ultimasCompras,
      'total_usd': totalMesUsd,
      'total_usd_bcv': totalMesUsd,
      'total_usdt_p2p': totalMesUsdt,
      'total_eur_bcv': totalEurBcv,
      'total_ves': totalMesVes,
      'presupuesto_general': presupuestoGeneral,
      'meta_ahorro': metaAhorro,
      'limite_para_gastar': savingsSnapshot.limiteParaGastar,
      'gasto_proyectado_fin_mes': temporalContext['gasto_proyectado_fin_mes'],
      'estado_meta_ahorro': estadoMetaEfectivo,
      'moneda_presupuesto': monedaPresupuesto,
      'presupuestos_categoria': presupuestosPorCategoria,
      'lista_compras': shoppingItems
          .map((e) => {
                'id': e.id,
                'nombre': e.name,
                'comprado': e.isPurchased == 1,
              })
          .toList(),
    };

    if (selection.includeTemporalContext) {
      contextMap['contexto_temporal'] = temporalContext;
    }

    if (selection.includeTopComercios) {
      final topComercios = buildTopComercios(gastos, limit: 3);
      if (topComercios.isNotEmpty) {
        contextMap['top_comercios'] = topComercios;
      }
    }

    if (hiddenSignalsJson != null) {
      if (selection.includePrevMonthComparison &&
          hiddenSignalsJson.containsKey('comparativa_mes_anterior')) {
        contextMap['comparativa_mes_anterior'] =
            hiddenSignalsJson['comparativa_mes_anterior'];
      }
      if (selection.includePriceFindings &&
          hiddenSignalsJson.containsKey('diferencias_precios')) {
        contextMap['diferencias_precios'] =
            hiddenSignalsJson['diferencias_precios'];
      }
      if (selection.includeAntExpenses &&
          hiddenSignalsJson.containsKey('gastos_hormiga')) {
        contextMap['gastos_hormiga'] = hiddenSignalsJson['gastos_hormiga'];
      }
    }

    return contextMap;
  }
}
