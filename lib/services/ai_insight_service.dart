import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/date_formatter.dart';
import '../data/datasources/local/database_helper.dart';
import '../data/datasources/remote/gemini_service.dart';
import '../data/models/gasto_model.dart';
import '../domain/finance/savings_health_calculator.dart';
import '../domain/finance/savings_health_models.dart';

/// Señales financieras ocultas precalculadas desde los datos locales y SQLite
/// que no se ven a simple vista en `SummaryCard` ni en `CategoryChart`.
class AiHiddenSignals {
  final Map<String, dynamic>? prevMonthComparison;
  final List<Map<String, dynamic>> priceFindings;
  final Map<String, dynamic>? antExpenses;
  final Map<String, dynamic>? exchangeBenefit;

  const AiHiddenSignals({
    this.prevMonthComparison,
    this.priceFindings = const [],
    this.antExpenses,
    this.exchangeBenefit,
  });

  bool get hasAnySignal =>
      prevMonthComparison != null ||
      priceFindings.isNotEmpty ||
      antExpenses != null ||
      exchangeBenefit != null;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (prevMonthComparison != null) {
      map['comparativa_mes_anterior'] = prevMonthComparison;
    }
    if (priceFindings.isNotEmpty) {
      map['diferencias_precios'] = priceFindings;
    }
    if (antExpenses != null) {
      map['gastos_hormiga'] = antExpenses;
    }
    if (exchangeBenefit != null) {
      map['rendimiento_cambiario'] = exchangeBenefit;
    }
    return map;
  }
}

/// Modelo inmutable que representa el consejo único mostrado en la tarjeta de Inicio.
class AiDashboardInsight {
  final String text;
  final String source;

  const AiDashboardInsight({
    required this.text,
    this.source = 'curated',
  });
}

/// Servicio encargado de:
/// 1. Precalcular señales ocultas de alto valor (comparativa vs. mes pasado,
///    diferencias de precios entre comercios, gastos hormiga y brecha BCV/USDT).
/// 2. Generar en segundo plano (máx. 1 vez cada 24 h con >= 3 gastos) un consejo
///    personalizado con Gemini en formato JSON estricto (`{"consejo": "..."}`).
/// 3. Proveer un respaldo local inteligente cuando no hay conexión o aún no hay caché IA.
class AiInsightService {
  // Claves vigentes v2 (purgan la caché v1 donde un Worker viejo pudo guardar texto plano)
  static const String prefTextKey = 'ai_insight_cached_text_v2';
  static const String prefLastFetchDateKey = 'ai_insight_last_fetch_date_v2';
  static const String prefSignatureKey = 'ai_insight_signature_v2';
  static const String prefYearMonthKey = 'ai_insight_year_month_v2';

  static const List<String> _legacyV1Keys = [
    'ai_insight_cached_short_v1',
    'ai_insight_cached_detailed_v1',
    'ai_insight_last_fetch_date_v1',
    'ai_insight_signature_v1',
    'ai_insight_year_month_v1',
  ];

  /// Mínimo de gastos en el mes actual para disparar generación en segundo plano con Gemini.
  static const int minExpensesForBackgroundGemini = 3;

  static bool _isFetchingBackground = false;

  /// Banco curado de consejos sustanciosos (3 líneas) para usuarios con poco historial
  /// o cuando aún no existen señales ocultas suficientes en SQLite.
  static const List<AiDashboardInsight> kCuratedValueInsights = [
    AiDashboardInsight(
      source: 'curated',
      text:
          'Comprar en el sitio correcto estira tu presupuesto sin sacrificar calidad. Cada factura que registras alimenta tu **comparador de precios** para avisarte **dónde te salió más barato** cada producto en los últimos **60 días**.',
    ),
    AiDashboardInsight(
      source: 'curated',
      text:
          'En Venezuela no cuesta igual pagar en efectivo que en bolívares a tasa oficial. Al marcar **Bs. a BCV**, **USDT** o **Efectivo** en cada compra, podrás ver cuánto te rindió realmente el mes frente a la **brecha cambiaria**.',
    ),
    AiDashboardInsight(
      source: 'curated',
      text:
          'La tinta de las facturas térmicas se borra en pocos días y pierdes la referencia de precios. Tómales una foto rápida al salir del local, incluso sin internet, para guardar el detalle de **cada producto** y detectar subidas a tiempo.',
    ),
    AiDashboardInsight(
      source: 'curated',
      text:
          'Los pagos pequeños del día a día suelen pasar desapercibidos hasta que suman más del **15%** del mes. Dictarlos **por voz en 5 segundos** te permite descubrir qué compras frecuentes están fugando tu efectivo.',
    ),
    AiDashboardInsight(
      source: 'curated',
      text:
          'Salir al mercado con tu **lista de compras** evita gastos impulsivos y viajes extra. Puedes dictármela en el chat y Rinde Más tachará automáticamente cada artículo cuando escanees o registres la factura.',
    ),
  ];

  /// Calcula el índice de día calendario del año de forma inmune a cambios de horario de verano (DST).
  static int _dayOfYearUtc(DateTime date) {
    final normalizedUtc = DateTime.utc(date.year, date.month, date.day);
    final startOfYearUtc = DateTime.utc(date.year, 1, 1);
    return normalizedUtc.difference(startOfYearUtc).inDays.abs();
  }

  /// Selecciona de forma determinista el consejo curado del día.
  static AiDashboardInsight getCuratedInsightForDate(DateTime date) {
    final dayOfYear = _dayOfYearUtc(date);
    final index = dayOfYear % kCuratedValueInsights.length;
    return kCuratedValueInsights[index];
  }

  /// Genera una firma ligera del estado de gastos del mes para detectar si hubo cambios reales.
  static String buildExpenseSignature({
    required int year,
    required int month,
    required List<GastoModel> gastos,
    required double totalMesUsd,
  }) {
    final totalCents = (totalMesUsd * 100).round();
    final latestUuid = gastos.isNotEmpty ? gastos.first.uuid : 'none';
    return '${year}_${month}_${gastos.length}_${totalCents}_$latestUuid';
  }

  /// Extrae el día del mes de una fecha ISO (`YYYY-MM-DD...`).
  static int _extractDay(String fecha) {
    if (fecha.length >= 10) {
      final parsed = int.tryParse(fecha.substring(8, 10));
      if (parsed != null && parsed >= 1 && parsed <= 31) return parsed;
    }
    return 1;
  }

  /// Calcula las 4 señales financieras ocultas a partir de los gastos del mes actual
  /// y consultas ligeras a SQLite (con tolerancia total a entornos de test sin DB).
  static Future<AiHiddenSignals> computeHiddenSignals({
    required List<GastoModel> gastos,
    required int selectedYear,
    required int selectedMonth,
    required double totalMesUsd,
    required double totalMesUsdt,
    DateTime? currentDate,
    DatabaseHelper? dbHelper,
  }) async {
    final now = currentDate ?? DateTime.now();
    final isCurrentMonth = selectedYear == now.year && selectedMonth == now.month;
    if (gastos.isEmpty) {
      return const AiHiddenSignals();
    }

    // 1. Señal en memoria: Gastos hormiga (compras individuales < $10 USD)
    Map<String, dynamic>? antExpenses;
    {
      int smallCount = 0;
      double smallTotalUsd = 0.0;
      final Map<String, int> smallCommerceCounts = {};

      for (final g in gastos) {
        final usd = g.totalUsd / 100.0;
        if (usd <= 0 || usd >= 10.0) continue;

        // Ignorar si todos los ítems del gasto fuesen estrictamente impuestos
        final hasNonTaxItem = g.items.isEmpty ||
            g.items.any((it) => !DatabaseHelper.isTaxItem(it.descripcion));
        if (!hasNonTaxItem) continue;

        smallCount++;
        smallTotalUsd += usd;
        final com = DatabaseHelper.formatCommerceDisplay(g.comercio);
        if (com.isNotEmpty && com.toLowerCase() != 'varios') {
          smallCommerceCounts[com] = (smallCommerceCounts[com] ?? 0) + 1;
        }
      }

      if (smallCount >= 4 && totalMesUsd > 0) {
        final pct = ((smallTotalUsd / totalMesUsd) * 100).round().clamp(1, 100);
        if (pct >= 12 || smallTotalUsd >= 20.0) {
          String? topSmallCommerce;
          int topSmallVisits = 0;
          for (final entry in smallCommerceCounts.entries) {
            if (entry.value > topSmallVisits) {
              topSmallVisits = entry.value;
              topSmallCommerce = entry.key;
            }
          }
          antExpenses = {
            'cantidad_compras': smallCount,
            'total_usd': double.parse(smallTotalUsd.toStringAsFixed(2)),
            'porcentaje_del_mes': pct,
            if (topSmallCommerce != null && topSmallVisits >= 2)
              'comercio_mas_repetido': topSmallCommerce,
          };
        }
      }
    }

    // 2. Señal en memoria: Rendimiento cambiario real BCV vs USDT P2P
    Map<String, dynamic>? exchangeBenefit;
    if (totalMesUsd > 0 && totalMesUsdt > 0) {
      final diffUsd = totalMesUsd - totalMesUsdt;
      final diffPct = ((diffUsd / totalMesUsd) * 100).round();
      if (diffUsd >= 5.0 && diffPct >= 5) {
        exchangeBenefit = {
          'total_usd_bcv': double.parse(totalMesUsd.toStringAsFixed(2)),
          'total_usdt_p2p': double.parse(totalMesUsdt.toStringAsFixed(2)),
          'ahorro_brecha_usd': double.parse(diffUsd.toStringAsFixed(2)),
          'ahorro_brecha_pct': diffPct,
        };
      }
    }

    if (!isCurrentMonth) {
      return AiHiddenSignals(
        antExpenses: antExpenses,
        exchangeBenefit: exchangeBenefit,
      );
    }

    final db = dbHelper ?? DatabaseHelper.instance;

    // 3. Señal SQLite: Comparativa vs. mes anterior a la misma altura del mes (días 1..hoy)
    Map<String, dynamic>? prevMonthComparison;
    try {
      final prevYear = selectedMonth == 1 ? selectedYear - 1 : selectedYear;
      final prevMonth = selectedMonth == 1 ? 12 : selectedMonth - 1;
      final prevGastosAll = await db.getGastosByMonth(prevYear, prevMonth);

      final prevGastosToDate = prevGastosAll
          .where((g) => _extractDay(g.fecha) <= now.day)
          .toList();

      if (prevGastosToDate.isNotEmpty) {
        final double prevTotalUsd = prevGastosToDate.fold(
          0.0,
          (sum, g) => sum + (g.totalUsd / 100.0),
        );

        final Map<String, double> curByCat = {};
        for (final g in gastos) {
          curByCat[g.categoria] = (curByCat[g.categoria] ?? 0.0) + (g.totalUsd / 100.0);
        }
        final Map<String, double> prevByCat = {};
        for (final g in prevGastosToDate) {
          prevByCat[g.categoria] = (prevByCat[g.categoria] ?? 0.0) + (g.totalUsd / 100.0);
        }

        Map<String, dynamic>? biggestSpike;
        int biggestSpikePct = 0;
        Map<String, dynamic>? biggestSaving;
        int biggestSavingPct = 0;

        final allCats = <String>{...curByCat.keys, ...prevByCat.keys};
        for (final cat in allCats) {
          final curVal = curByCat[cat] ?? 0.0;
          final prevVal = prevByCat[cat] ?? 0.0;
          if (prevVal < 10.0) continue;

          final deltaUsd = curVal - prevVal;
          final deltaPct = ((deltaUsd / prevVal) * 100).round();

          if (deltaPct >= 20 && deltaUsd >= 10.0 && deltaPct > biggestSpikePct) {
            biggestSpikePct = deltaPct;
            biggestSpike = {
              'categoria': cat,
              'actual_usd': double.parse(curVal.toStringAsFixed(2)),
              'mes_anterior_usd': double.parse(prevVal.toStringAsFixed(2)),
              'variacion_pct': deltaPct,
            };
          } else if (deltaPct <= -15 && (-deltaUsd) >= 10.0 && (-deltaPct) > biggestSavingPct) {
            biggestSavingPct = -deltaPct;
            biggestSaving = {
              'categoria': cat,
              'actual_usd': double.parse(curVal.toStringAsFixed(2)),
              'mes_anterior_usd': double.parse(prevVal.toStringAsFixed(2)),
              'ahorro_pct': -deltaPct,
            };
          }
        }

        final int? totalDeltaPct = prevTotalUsd >= 15.0
            ? (((totalMesUsd - prevTotalUsd) / prevTotalUsd) * 100).round()
            : null;

        if (biggestSpike != null ||
            biggestSaving != null ||
            (totalDeltaPct != null && totalDeltaPct.abs() >= 15)) {
          prevMonthComparison = {
            'mes_anterior': DateFormatter.getMonthName(prevMonth),
            'dia_corte': now.day,
            'actual_a_la_fecha_usd': double.parse(totalMesUsd.toStringAsFixed(2)),
            'anterior_a_la_fecha_usd': double.parse(prevTotalUsd.toStringAsFixed(2)),
            if (totalDeltaPct != null) 'variacion_total_pct': totalDeltaPct,
            if (biggestSpike != null) 'categoria_en_alza': biggestSpike,
            if (biggestSaving != null) 'categoria_con_ahorro': biggestSaving,
          };
        }
      }
    } catch (e) {
      debugPrint('AiInsightService: Comparativa mes anterior omitida: $e');
    }

    // 4. Señal SQLite: Diferencias de precios entre comercios o subidas en los últimos 60 días
    final List<Map<String, dynamic>> priceFindings = [];
    try {
      final Map<String, String> normToDisplayName = {};
      for (final g in gastos) {
        for (final item in g.items) {
          final clean = item.descripcion.trim();
          if (clean.length <= 2 || DatabaseHelper.isTaxItem(clean)) continue;
          final norm = DatabaseHelper.normalizeProductText(clean);
          if (norm.length > 2 && !normToDisplayName.containsKey(norm)) {
            normToDisplayName[norm] = clean;
          }
        }
      }

      if (normToDisplayName.isNotEmpty) {
        final historyMap = await db.findPriceHistory(
          normToDisplayName.keys.take(40).toList(),
          diasVentana: 60,
          referenceDate: now,
        );

        for (final entry in historyMap.entries) {
          final history = entry.value;
          if (history.entradas.length < 2) continue;

          // Entradas vienen ordenadas por fecha DESC desde SQLite
          final latest = history.entradas.first;
          final best = history.mejorPrecio;
          final displayName = normToDisplayName[entry.key] ?? entry.key;

          if (best != null &&
              best.precioUsd > 0 &&
              latest.precioUsd > best.precioUsd &&
              best.comercioNorm.isNotEmpty &&
              latest.comercioNorm.isNotEmpty &&
              best.comercioNorm != latest.comercioNorm) {
            final diffUsd = latest.precioUsd - best.precioUsd;
            final diffPct = ((diffUsd / best.precioUsd) * 100).round();
            if (diffPct >= 10 && diffUsd >= 0.30) {
              priceFindings.add({
                'tipo': 'otro_comercio_mas_barato',
                'producto': displayName,
                'comercio_reciente': DatabaseHelper.formatCommerceDisplay(latest.comercio),
                'precio_reciente_usd': double.parse(latest.precioUsd.toStringAsFixed(2)),
                'comercio_mas_barato': DatabaseHelper.formatCommerceDisplay(best.comercio),
                'precio_mas_barato_usd': double.parse(best.precioUsd.toStringAsFixed(2)),
                'diferencia_pct': diffPct,
              });
              continue;
            }
          }

          // Fallback: subida notable en el mismo comercio
          final prevSame = history.entradas.skip(1).firstWhere(
            (e) => e.comercioNorm == latest.comercioNorm && e.precioUsd > 0,
            orElse: () => const UnitPriceRef(
              precioUsd: 0,
              fecha: '',
              comercio: '',
              comercioNorm: '',
              cantidad: 0,
            ),
          );
          if (prevSame.precioUsd > 0 && latest.precioUsd > prevSame.precioUsd) {
            final diffUsd = latest.precioUsd - prevSame.precioUsd;
            final diffPct = ((diffUsd / prevSame.precioUsd) * 100).round();
            if (diffPct >= 12 && diffUsd >= 0.30) {
              priceFindings.add({
                'tipo': 'subida_mismo_comercio',
                'producto': displayName,
                'comercio': DatabaseHelper.formatCommerceDisplay(latest.comercio),
                'precio_reciente_usd': double.parse(latest.precioUsd.toStringAsFixed(2)),
                'precio_anterior_usd': double.parse(prevSame.precioUsd.toStringAsFixed(2)),
                'variacion_pct': diffPct,
              });
            }
          }
        }

        priceFindings.sort((a, b) {
          final pctA = (a['diferencia_pct'] ?? a['variacion_pct'] ?? 0) as int;
          final pctB = (b['diferencia_pct'] ?? b['variacion_pct'] ?? 0) as int;
          return pctB.compareTo(pctA);
        });
      }
    } catch (e) {
      debugPrint('AiInsightService: Historial de precios omitido: $e');
    }

    return AiHiddenSignals(
      prevMonthComparison: prevMonthComparison,
      priceFindings: priceFindings.take(3).toList(),
      antExpenses: antExpenses,
      exchangeBenefit: exchangeBenefit,
    );
  }

  /// Construye un consejo local de alto valor (2 a 4 líneas) a partir de las señales
  /// ocultas precalculadas, en orden de mayor impacto real (nunca repite `SummaryCard`).
  static AiDashboardInsight? _buildLocalSmartInsight({
    required AiHiddenSignals? signals,
    required Map<String, double> totalesPorCategoria,
    required Map<String, double> presupuestosPorCategoria,
    required String monedaPresupuesto,
  }) {
    // 1. Diferencia de precios entre comercios o subida fuerte de un producto
    if (signals != null && signals.priceFindings.isNotEmpty) {
      final top = signals.priceFindings.first;
      final prod = top['producto']?.toString() ?? 'un producto';
      if (top['tipo'] == 'otro_comercio_mas_barato') {
        final comCaro = top['comercio_reciente']?.toString() ?? 'tu última compra';
        final pCaro = CurrencyFormatter.formatUsd((top['precio_reciente_usd'] as num).toDouble());
        final comBarato = top['comercio_mas_barato']?.toString() ?? 'otro comercio';
        final pBarato = CurrencyFormatter.formatUsd((top['precio_mas_barato_usd'] as num).toDouble());
        final pct = top['diferencia_pct'];
        return AiDashboardInsight(
          source: 'price_diff',
          text:
              'Pagaste **$pCaro** por **$prod** en **$comCaro**, un **$pct%** más que los **$pBarato** que te costó en **$comBarato**. Si lo repones allí la próxima vez, estiras el mes sin sacrificar calidad.',
        );
      } else {
        final com = top['comercio']?.toString() ?? 'el mismo local';
        final pActual = CurrencyFormatter.formatUsd((top['precio_reciente_usd'] as num).toDouble());
        final pPrev = CurrencyFormatter.formatUsd((top['precio_anterior_usd'] as num).toDouble());
        final pct = top['variacion_pct'];
        return AiDashboardInsight(
          source: 'price_diff',
          text:
              '**$prod** subió un **$pct%** en **$com** (pasó de **$pPrev** a **$pActual**). Vale la pena comparar su precio en otro comercio antes de tu próxima compra.',
        );
      }
    }

    // 2. Presupuesto específico de categoría al >= 80%
    if (presupuestosPorCategoria.isNotEmpty) {
      String? alertCat;
      double highestRatio = 0.0;
      double catSpent = 0.0;
      double catBudget = 0.0;

      for (final entry in presupuestosPorCategoria.entries) {
        final b = entry.value;
        if (b <= 0) continue;
        final s = totalesPorCategoria[entry.key] ?? 0.0;
        final ratio = s / b;
        if (ratio >= 0.80 && ratio > highestRatio) {
          highestRatio = ratio;
          alertCat = entry.key;
          catSpent = s;
          catBudget = b;
        }
      }

      if (alertCat != null) {
        final pct = (highestRatio * 100).round();
        final fSpent = CurrencyFormatter.formatAmount(catSpent, monedaPresupuesto);
        final fBudget = CurrencyFormatter.formatAmount(catBudget, monedaPresupuesto);
        final msg = highestRatio > 1.0
            ? 'En **$alertCat** superaste el tope que asignaste (**$fSpent** de **$fBudget**). Revisa si puedes compensar ese desfase moderando otra categoría esta semana.'
            : 'Atención en **$alertCat**: ya usaste el **$pct%** de su presupuesto asignado (**$fSpent** de **$fBudget**). Aún estás a tiempo de ajustar el ritmo antes de cerrar el mes.';
        return AiDashboardInsight(
          source: 'category_budget',
          text: msg,
        );
      }
    }

    // 3. Gastos hormiga acumulados (< $10)
    if (signals?.antExpenses != null) {
      final ant = signals!.antExpenses!;
      final cant = ant['cantidad_compras'];
      final totalStr = CurrencyFormatter.formatUsd((ant['total_usd'] as num).toDouble());
      final pct = ant['porcentaje_del_mes'];
      final com = ant['comercio_mas_repetido']?.toString();
      final comExtra = com != null ? ', con varias visitas en **$com**' : '';
      return AiDashboardInsight(
        source: 'ant_expenses',
        text:
            'Llevas **$cant compras pequeñas** menores a **\$ 10,00** que ya suman **$totalStr** (**$pct%** de tu gasto mensual)$comExtra. Agrupar esas compras puntuales suele evitar fugas invisibles.',
      );
    }

    // 4. Comparativa vs. mes pasado a la misma fecha (alza o felicitación ganada por ahorro real)
    if (signals?.prevMonthComparison != null) {
      final cmp = signals!.prevMonthComparison!;
      final prevName = cmp['mes_anterior']?.toString() ?? 'el mes pasado';

      if (cmp['categoria_con_ahorro'] is Map) {
        final sav = cmp['categoria_con_ahorro'] as Map;
        final cat = sav['categoria']?.toString() ?? 'tus compras';
        final pct = sav['ahorro_pct'];
        final curStr = CurrencyFormatter.formatUsd((sav['actual_usd'] as num).toDouble());
        final prevStr = CurrencyFormatter.formatUsd((sav['mes_anterior_usd'] as num).toDouble());
        return AiDashboardInsight(
          source: 'prev_month',
          text:
              '¡Buen ritmo en **$cat**! A esta altura del mes llevas un **$pct%** menos que en $prevName (**$curStr** frente a **$prevStr**). Mantener ese control te dejará un margen extra real.',
        );
      }

      if (cmp['categoria_en_alza'] is Map) {
        final spike = cmp['categoria_en_alza'] as Map;
        final cat = spike['categoria']?.toString() ?? 'una categoría';
        final pct = spike['variacion_pct'];
        final curStr = CurrencyFormatter.formatUsd((spike['actual_usd'] as num).toDouble());
        final prevStr = CurrencyFormatter.formatUsd((spike['mes_anterior_usd'] as num).toDouble());
        return AiDashboardInsight(
          source: 'prev_month',
          text:
              'Tu gasto en **$cat** va un **$pct%** por encima de $prevName a esta misma fecha (**$curStr** frente a **$prevStr**). Vale la pena revisar si se debe a subidas de precios o compras adelantadas.',
        );
      }

      final totalDelta = cmp['variacion_total_pct'] as int?;
      if (totalDelta != null && totalDelta <= -15) {
        return AiDashboardInsight(
          source: 'prev_month',
          text:
              '¡Buen desempeño este mes! A esta fecha llevas un **${totalDelta.abs()}%** menos gastado que en $prevName. Ese margen a favor te ayuda a cerrar con mayor tranquilidad.',
        );
      } else if (totalDelta != null && totalDelta >= 20) {
        return AiDashboardInsight(
          source: 'prev_month',
          text:
              'A esta altura del mes tu ritmo de gasto va un **$totalDelta%** más acelerado que en $prevName. Revisa en el chat qué categorías están impulsando esa diferencia.',
        );
      }
    }

    // 5. Rendimiento por brecha cambiaria BCV vs USDT
    if (signals?.exchangeBenefit != null) {
      final fx = signals!.exchangeBenefit!;
      final ahorroStr = CurrencyFormatter.formatUsd((fx['ahorro_brecha_usd'] as num).toDouble());
      final pct = fx['ahorro_brecha_pct'];
      return AiDashboardInsight(
        source: 'exchange_benefit',
        text:
            'Pagar en bolívares a tasa oficial jugó a tu favor: al medir tus compras en **USDT P2P** el costo real bajó **$ahorroStr** (**$pct%**). Elegir bien cómo liquidar cada compra está estirando tu presupuesto.',
      );
    }

    return null;
  }

  /// Resuelve de forma síncrona el consejo único a mostrar en `AiInsightCard`.
  static AiDashboardInsight resolveInsight({
    required List<GastoModel> gastos,
    required double presupuestoGeneral,
    double metaAhorro = 0.0,
    required Map<String, double> totalesPorCategoria,
    Map<String, double> presupuestosPorCategoria = const {},
    required double totalGastadoMes,
    String monedaPresupuesto = 'USD',
    double tasaCambio = 1.0,
    int? mes,
    int? anio,
    DateTime? currentDate,
    String? cachedGeminiText,
    AiHiddenSignals? hiddenSignals,
  }) {
    final now = currentDate ?? DateTime.now();
    final targetYear = anio ?? now.year;
    final targetMonth = mes ?? now.month;
    final diasEnMes = DateTime(targetYear, targetMonth + 1, 0).day;
    final isPastMonth = targetYear < now.year ||
        (targetYear == now.year && targetMonth < now.month);
    final isCurrentMonth = targetYear == now.year && targetMonth == now.month;
    final diasRestantes = isCurrentMonth
        ? (diasEnMes - now.day).clamp(1, diasEnMes)
        : 1;
    final mesActualNombre = DateFormatter.getMonthName(targetMonth);
    final curatedTip = getCuratedInsightForDate(now);

    final hasValidGeminiTip = isCurrentMonth &&
        cachedGeminiText != null &&
        cachedGeminiText.trim().isNotEmpty &&
        !_hasMalformedPrefix(cachedGeminiText);

    // 1. Caso: Sin gastos registrados en el mes
    if (gastos.isEmpty) {
      if (now.day <= 5 && presupuestoGeneral > 0 && isCurrentMonth) {
        return AiDashboardInsight(
          source: 'welcome',
          text:
              '¡Nuevo mes! Tu presupuesto de **$mesActualNombre** ya está listo para aplicar lo aprendido el mes pasado.',
        );
      }

      return const AiDashboardInsight(
        source: 'welcome',
        text:
            'Registra tu primera compra con el botón **+** para activar tu comparador de precios, análisis por categoría y consejos personalizados.',
      );
    }

    // 2. Caso: Mes pasado cerrado (solo si tiene presupuesto)
    final hasSavingsGoal = metaAhorro > 0;
    final limiteParaGastar = hasSavingsGoal
        ? (presupuestoGeneral - metaAhorro).clamp(0.0, double.infinity)
        : presupuestoGeneral;

    if (presupuestoGeneral > 0 && isPastMonth) {
      if (totalGastadoMes > limiteParaGastar) {
        final exceso = totalGastadoMes - limiteParaGastar;
        final formattedExceso = CurrencyFormatter.formatAmount(exceso, monedaPresupuesto);
        return AiDashboardInsight(
          source: 'alert',
          text:
              'En $mesActualNombre superaste tu ${hasSavingsGoal ? "límite" : "presupuesto"} por **$formattedExceso**. Toca **Consultar** si quieres revisar qué compras impulsaron ese desfase.',
        );
      } else {
        final rem = limiteParaGastar - totalGastadoMes;
        final formattedRem = CurrencyFormatter.formatAmount(rem, monedaPresupuesto);
        return AiDashboardInsight(
          source: 'alert',
          text:
              '¡Mes cerrado con éxito! En $mesActualNombre te sobraron **$formattedRem** de tu ${hasSavingsGoal ? "límite" : "presupuesto"}.',
        );
      }
    }

    // 3. Caso: Excedido en el mes actual (alerta crítica prioritaria)
    if (presupuestoGeneral > 0 && totalGastadoMes > limiteParaGastar) {
      final exceso = totalGastadoMes - limiteParaGastar;
      final formattedExceso = CurrencyFormatter.formatAmount(exceso, monedaPresupuesto);
      if (hasSavingsGoal) {
        final formattedMeta = CurrencyFormatter.formatAmount(metaAhorro, monedaPresupuesto);
        return AiDashboardInsight(
          source: 'alert',
          text:
              'Superaste tu límite por **$formattedExceso**. Tu meta de ahorro de **$formattedMeta** está comprometida; pausa compras no esenciales o consulta en el chat dónde recortar.',
        );
      } else {
        return AiDashboardInsight(
          source: 'alert',
          text:
              'Superaste tu presupuesto por **$formattedExceso**. Te sugiero pausar gastos no esenciales esta semana y revisar en el chat tus categorías con mayor desvío.',
        );
      }
    }

    // 4. Caso: Meta de ahorro en riesgo por ritmo proyectado
    if (presupuestoGeneral > 0 && hasSavingsGoal) {
      final savingsSnapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: presupuestoGeneral,
        metaAhorro: metaAhorro,
        gastoAcumulado: totalGastadoMes,
        diaActual: now.day,
        diasTotalesMes: diasEnMes,
        moneda: monedaPresupuesto,
      );

      if (savingsSnapshot.status == SavingsGoalStatus.enRiesgo) {
        final formattedProy = CurrencyFormatter.formatAmount(
          savingsSnapshot.gastoProyectadoFinDeMes,
          monedaPresupuesto,
        );
        final formattedMeta = CurrencyFormatter.formatAmount(metaAhorro, monedaPresupuesto);
        return AiDashboardInsight(
          source: 'alert',
          text:
              'A tu ritmo actual proyectas cerrar en **$formattedProy**, lo que comprometería tu meta de **$formattedMeta**. Modera tus compras no esenciales los próximos días.',
        );
      }
    }

    // 5. Prioridad principal en operación normal: Consejo de Gemini en caché (basado en las 4 señales ocultas)
    if (hasValidGeminiTip) {
      return AiDashboardInsight(
        source: 'gemini',
        text: cachedGeminiText.trim(),
      );
    }

    // 6. Respaldo inteligente local: hallazgo real calculado desde las 4 señales ocultas o presupuesto de categoría
    final localSmart = _buildLocalSmartInsight(
      signals: hiddenSignals,
      totalesPorCategoria: totalesPorCategoria,
      presupuestosPorCategoria: presupuestosPorCategoria,
      monedaPresupuesto: monedaPresupuesto,
    );
    if (localSmart != null) {
      return localSmart;
    }

    // 7. Sin presupuesto mensual definido (y sin hallazgo oculto aún)
    if (presupuestoGeneral <= 0) {
      return const AiDashboardInsight(
        source: 'budget_prompt',
        text:
            'Define un **presupuesto mensual** y podré calcular tu ritmo diario ideal y alertarte antes de que alguna categoría se desvíe.',
      );
    }

    // 8. Usuario con presupuesto saludable y poco historial aún: alterna ritmo diario limpio y consejos de valor
    final dayOfYear = _dayOfYearUtc(now);
    if (dayOfYear.isOdd) {
      final disponible = limiteParaGastar - totalGastadoMes;
      final ritmoDiario = disponible / diasRestantes;
      final formattedRitmo = CurrencyFormatter.formatAmount(ritmoDiario, monedaPresupuesto);
      final diasTexto = diasRestantes == 1
          ? 'el **día restante**'
          : 'los **$diasRestantes días** restantes';
      return AiDashboardInsight(
        source: 'daily_pace',
        text:
            'Puedes gastar hasta **$formattedRitmo/día** durante $diasTexto sin salirte de tu plan mensual.',
      );
    }

    return curatedTip;
  }

  /// Construye el contexto compacto y rico en señales ocultas (sin IVA) que se envía a Gemini.
  static Map<String, dynamic> buildCompactContextForGemini({
    required List<GastoModel> gastos,
    required double totalMesUsd,
    required double presupuestoUsd,
    required double metaAhorroUsd,
    required String monedaLente,
    required DateTime now,
    AiHiddenSignals? hiddenSignals,
  }) {
    final Map<String, double> totalesCat = {};
    final Map<String, Map<String, dynamic>> comerciosMap = {};
    final Map<String, Map<String, dynamic>> productosMap = {};

    for (final g in gastos) {
      final usd = g.totalUsd / 100.0;
      totalesCat[g.categoria] = (totalesCat[g.categoria] ?? 0.0) + usd;

      final comName = DatabaseHelper.formatCommerceDisplay(g.comercio);
      if (comName.isNotEmpty && comName.toLowerCase() != 'varios') {
        final key = comName.toLowerCase();
        final entry = comerciosMap[key] ?? {'comercio': comName, 'visitas': 0, 'total_usd': 0.0};
        entry['visitas'] = (entry['visitas'] as int) + 1;
        entry['total_usd'] = (entry['total_usd'] as double) + usd;
        comerciosMap[key] = entry;
      }

      for (final item in g.items) {
        final desc = item.descripcion.trim();
        if (desc.isEmpty || DatabaseHelper.isTaxItem(desc)) continue;
        final pKey = desc.toLowerCase();
        final pEntry = productosMap[pKey] ?? {'producto': desc, 'veces': 0, 'total_usd': 0.0};
        pEntry['veces'] = (pEntry['veces'] as int) + 1;
        final double itemUsd = (g.totalOriginal > 0)
            ? (item.total / g.totalOriginal) * usd
            : (item.total / 100.0);
        pEntry['total_usd'] = (pEntry['total_usd'] as double) + itemUsd;
        productosMap[pKey] = pEntry;
      }
    }

    final topComercios = comerciosMap.values.toList()
      ..sort((a, b) => (b['total_usd'] as double).compareTo(a['total_usd'] as double));
    final topProductos = productosMap.values.toList()
      ..sort((a, b) => (b['total_usd'] as double).compareTo(a['total_usd'] as double));

    final contextMap = <String, dynamic>{
      'fecha_hoy': now.toIso8601String().substring(0, 10),
      'moneda_principal': monedaLente,
      'cantidad_compras_mes': gastos.length,
      'totales_categoria_usd': totalesCat.map(
        (k, v) => MapEntry(k, double.parse(v.toStringAsFixed(2))),
      ),
      'top_comercios': topComercios.take(3).map((c) => {
        'comercio': c['comercio'],
        'visitas': c['visitas'],
        'total_usd': double.parse((c['total_usd'] as double).toStringAsFixed(2)),
      }).toList(),
      'top_productos_sin_iva': topProductos.take(5).map((p) => {
        'producto': p['producto'],
        'veces': p['veces'],
        'total_usd': double.parse((p['total_usd'] as double).toStringAsFixed(2)),
      }).toList(),
    };

    if (hiddenSignals != null && hiddenSignals.hasAnySignal) {
      contextMap.addAll(hiddenSignals.toJson());
    }

    return contextMap;
  }

  static bool _hasMalformedPrefix(String text) {
    final lower = text.trim().toLowerCase();
    return lower.startsWith('consejo corto:') ||
        lower.startsWith('**consejo corto') ||
        lower.startsWith('consejo:') ||
        lower.startsWith('**consejo:');
  }

  /// Parsea de forma ESTRICTA la respuesta JSON `{"consejo": "..."}` de `insight_inicio`.
  /// Si el Worker devolvió texto plano sin JSON válido o con etiquetas basura (`Consejo corto:`),
  /// retorna `null` para evitar guardar respuestas degradadas en la caché local.
  static String? parseStrictDashboardInsight(String rawText) {
    final trimmedRaw = rawText.trim();
    if (trimmedRaw.isEmpty) return null;

    final cleaned = trimmedRaw
        .replaceFirst(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
        .replaceFirst(RegExp(r'\s*```$', multiLine: true), '')
        .trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace == -1 || lastBrace == -1 || lastBrace <= firstBrace) {
      debugPrint('AiInsightService: Respuesta descartada por no ser JSON estructurado.');
      return null;
    }

    final candidateJson = cleaned.substring(firstBrace, lastBrace + 1);
    try {
      final decoded = jsonDecode(candidateJson);
      if (decoded is Map) {
        final rawConsejo = (decoded['consejo'] ?? decoded['resumen'] ?? '').toString();
        final normalized = rawConsejo.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (normalized.length < 20 || _hasMalformedPrefix(normalized)) {
          debugPrint('AiInsightService: Consejo JSON descartado por prefijo inválido o demasiado corto.');
          return null;
        }
        return normalized;
      }
    } catch (e) {
      debugPrint('AiInsightService: JSON inválido en insight_inicio, respuesta descartada: $e');
    }
    return null;
  }

  static Future<void> _purgeLegacyV1Cache(SharedPreferences prefs) async {
    for (final key in _legacyV1Keys) {
      if (prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }
  }

  /// Lee el consejo de Gemini cacheado en `SharedPreferences` (v2) si corresponde al mes indicado.
  static Future<String?> getCachedGeminiInsight({
    required int year,
    required int month,
    SharedPreferences? prefsInstance,
  }) async {
    try {
      final prefs = prefsInstance ?? await SharedPreferences.getInstance();
      await _purgeLegacyV1Cache(prefs);

      final cachedYm = prefs.getString(prefYearMonthKey);
      if (cachedYm != '${year}_$month') return null;

      final text = prefs.getString(prefTextKey);
      if (text != null && text.trim().isNotEmpty && !_hasMalformedPrefix(text)) {
        return text.trim();
      }
    } catch (e) {
      debugPrint('AiInsightService: Error leyendo caché v2 de consejo IA: $e');
    }
    return null;
  }

  /// Verifica si corresponde generar un nuevo consejo personalizado con Gemini en segundo plano
  /// (máximo 1 vez cada 24h, solo en el mes actual, con >= 3 gastos y solo si cambió la firma).
  /// Retorna el texto del consejo vigente (recién generado o de caché v2), o `null` si no aplica.
  static Future<String?> refreshBackgroundInsightIfNeeded({
    required List<GastoModel> gastos,
    required int selectedYear,
    required int selectedMonth,
    required double totalMesUsd,
    required double presupuestoUsd,
    required double metaAhorroUsd,
    String monedaLente = 'USD',
    AiHiddenSignals? hiddenSignals,
    DateTime? currentDate,
    GeminiService? geminiService,
    SharedPreferences? prefsInstance,
  }) async {
    final now = currentDate ?? DateTime.now();
    final isCurrentMonth = selectedYear == now.year && selectedMonth == now.month;
    if (!isCurrentMonth) return null;

    SharedPreferences prefs;
    try {
      prefs = prefsInstance ?? await SharedPreferences.getInstance();
      await _purgeLegacyV1Cache(prefs);
    } catch (e) {
      debugPrint('AiInsightService: SharedPreferences no disponible: $e');
      return null;
    }

    final cached = await getCachedGeminiInsight(
      year: selectedYear,
      month: selectedMonth,
      prefsInstance: prefs,
    );

    if (gastos.length < minExpensesForBackgroundGemini) {
      return cached;
    }

    final todayIso = now.toIso8601String().substring(0, 10);
    final lastFetchDate = prefs.getString(prefLastFetchDateKey);
    final currentSignature = buildExpenseSignature(
      year: selectedYear,
      month: selectedMonth,
      gastos: gastos,
      totalMesUsd: totalMesUsd,
    );
    final lastSignature = prefs.getString(prefSignatureKey);

    // Guarda de cuota D1: máximo 1 llamada por día calendario y solo si cambiaron los gastos
    if (cached != null && (lastFetchDate == todayIso || lastSignature == currentSignature)) {
      return cached;
    }

    // En tests de widgets donde no se inyecta un GeminiService explícito ni hay Firebase inicializado,
    // no realizar llamadas HTTP reales.
    if (geminiService == null && Firebase.apps.isEmpty) {
      return cached;
    }

    if (_isFetchingBackground) return cached;
    _isFetchingBackground = true;

    try {
      final service = geminiService ?? GeminiService();
      final contextData = buildCompactContextForGemini(
        gastos: gastos,
        totalMesUsd: totalMesUsd,
        presupuestoUsd: presupuestoUsd,
        metaAhorroUsd: metaAhorroUsd,
        monedaLente: monedaLente,
        now: now,
        hiddenSignals: hiddenSignals,
      );

      final responseMap = await service.chatWithAnalyst(
        messages: const [
          {
            'role': 'user',
            'text': 'Genera el análisis financiero más útil de hoy en formato JSON según mis señales ocultas.',
          },
        ],
        contextData: contextData,
        modo: 'insight_inicio',
      );
      final rawText = (responseMap['text'] ?? '').toString().trim();
      final consejo = parseStrictDashboardInsight(rawText);

      if (consejo != null && consejo.isNotEmpty) {
        await prefs.setString(prefTextKey, consejo);
        await prefs.setString(prefLastFetchDateKey, todayIso);
        await prefs.setString(prefSignatureKey, currentSignature);
        await prefs.setString(prefYearMonthKey, '${selectedYear}_$selectedMonth');
        return consejo;
      }
    } catch (e) {
      debugPrint('AiInsightService: Generación en 2.º plano omitida: $e');
    } finally {
      _isFetchingBackground = false;
    }

    return cached;
  }
}
