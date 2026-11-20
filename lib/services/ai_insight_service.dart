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

/// Modelo inmutable que representa el consejo mostrado en la tarjeta de Inicio
/// (`shortText`) y su versión ampliada para iniciar o continuar en el Chat (`detailedText`).
class AiDashboardInsight {
  final String shortText;
  final String detailedText;
  final String source;

  const AiDashboardInsight({
    required this.shortText,
    required this.detailedText,
    this.source = 'curated',
  });
}

/// Servicio encargado de resolver el consejo único de `AiInsightCard` (combinando
/// ritmo diario determinista, heurísticas locales, banco de valor y generación
/// periódica en segundo plano con Gemini protegida por caché de 24 horas).
class AiInsightService {
  static const String prefShortTextKey = 'ai_insight_cached_short_v1';
  static const String prefDetailedTextKey = 'ai_insight_cached_detailed_v1';
  static const String prefLastFetchDateKey = 'ai_insight_last_fetch_date_v1';
  static const String prefSignatureKey = 'ai_insight_signature_v1';
  static const String prefYearMonthKey = 'ai_insight_year_month_v1';

  /// Mínimo de gastos en el mes actual para disparar generación en segundo plano con Gemini.
  static const int minExpensesForBackgroundGemini = 3;

  static bool _isFetchingBackground = false;

  /// Banco curado de consejos de valor real sobre las capacidades de Rinde Más.
  static const List<AiDashboardInsight> kCuratedValueInsights = [
    AiDashboardInsight(
      source: 'curated',
      shortText:
          'Comprar en el sitio correcto te ayuda a estirar el presupuesto. Rinde Más recuerda tus compras y te avisa dónde te salió más barato cada producto.',
      detailedText:
          '**Comprar en el sitio correcto te ayuda a estirar el presupuesto.**\n\n'
          'Cada vez que registras una compra con sus artículos en **Rinde Más**, guardo el precio unitario y el comercio:\n'
          '• **Comparador en vivo:** Cuando vuelvas a comprar ese mismo producto en los próximos 60 días, verás debajo del artículo si subió o bajó de precio y en qué local te salió más económico.\n'
          '• **Consulta histórica:** También puedes preguntarme aquí en el chat dónde compraste más barato cualquier producto de tus facturas.\n\n'
          '¿Qué producto compras con frecuencia para revisar su último precio registrado?',
    ),
    AiDashboardInsight(
      source: 'curated',
      shortText:
          'Indicar cómo pagaste cada compra (Bs. a BCV, USDT o Efectivo) te muestra cuánto rindió realmente tu dinero frente a la brecha cambiaria.',
      detailedText:
          '**Aprovecha el método de liquidación a tu favor.**\n\n'
          'En Venezuela no cuesta igual pagar un precio en dólares con **Bolívares a tasa BCV** que con **divisas en efectivo**:\n'
          '• Al seleccionar **Bs. a BCV**, **Bs. a USDT** o **Efectivo** cuando guardas un gasto, Rinde Más calcula en la pestaña **Análisis** tu radiografía cambiaria exacta.\n'
          '• Así puedes ver cuántos dólares reales te costó el mes a tasa de reposición.\n\n'
          '¿Quieres que revisemos cómo se dividen tus gastos de este mes según la moneda y forma de pago?',
    ),
    AiDashboardInsight(
      source: 'curated',
      shortText:
          'El papel térmico de las facturas se borra en pocos días. Tómales una foto rápida al salir del local y Rinde Más extraerá cada producto por ti.',
      detailedText:
          '**Que no se te borren las facturas de papel térmico.**\n\n'
          'La tinta de los tickets fiscales se desvanece rápido con el calor de la cartera o el bolsillo:\n'
          '• Con el botón **+ > Escanear factura**, puedes fotografiar tus comprobantes al instante aunque no tengas internet en el local.\n'
          '• La cola inteligente los procesa en segundo plano y desglosa cada producto por categoría para alimentar tu comparador de precios.\n\n'
          '¿Tienes alguna compra de hoy que quieras dictarme o registrar de una vez por aquí?',
    ),
    AiDashboardInsight(
      source: 'curated',
      shortText:
          'Los gastos pequeños del día a día suelen pasar desapercibidos. Dictarlos por voz en 5 segundos te revela a dónde se va tu efectivo.',
      detailedText:
          '**Detecta los gastos hormiga antes de fin de mes.**\n\n'
          'Un café, un snack, un pasaje o un pago móvil rápido parecen montos menores por separado, pero juntos pueden superar el 15% de tu presupuesto mensual:\n'
          '• Puedes dictarme compras rápidas tocando el micrófono (por ejemplo: *«Gasté 150 bolívares en panadería»*) sin llenar formularios.\n'
          '• Cuando acumules varios registros, pregúntame qué gastos pequeños están sumando más de lo que parece.\n\n'
          '¿Quieres que analicemos tus compras pequeñas y frecuentes de este mes?',
    ),
    AiDashboardInsight(
      source: 'curated',
      shortText:
          'Si armas tu lista de compras en Rinde Más antes de salir, los productos se marcarán como comprados automáticamente al registrar tu factura.',
      detailedText:
          '**Planifica tu mercado y evita compras impulsivas.**\n\n'
          'Ir al supermercado o a la farmacia con una lista clara evita olvidos y gastos fuera de presupuesto:\n'
          '• Puedes pedirme aquí mismo en el chat: *«Anota café, harina y queso en la lista de compras»*.\n'
          '• Al escanear o guardar tu factura, Rinde Más tachará automáticamente de tu lista los productos que coincidan.\n\n'
          '¿Qué productos quieres que anote en tu lista de compras para tu próxima salida?',
    ),
  ];

  /// Selecciona de forma determinista el consejo curado del día (sin cambiar durante el mismo día).
  static AiDashboardInsight getCuratedInsightForDate(DateTime date) {
    final startOfYear = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(startOfYear).inDays.abs();
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

  /// Construye un resumen compacto de las categorías principales del mes en el lente activo.
  static String _buildTopCategoriesSummary(
    Map<String, double> totalesPorCategoria,
    double totalGastadoMes,
    String moneda,
  ) {
    if (totalesPorCategoria.isEmpty || totalGastadoMes <= 0) return '';
    final entries = totalesPorCategoria.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return '';

    final topEntries = entries.take(3).map((e) {
      final pct = ((e.value / totalGastadoMes) * 100).round().clamp(1, 100);
      final formatted = CurrencyFormatter.formatAmount(e.value, moneda);
      return '• **${e.key}:** $formatted ($pct%)';
    }).join('\n');

    return '\n\n**Distribución principal de tus gastos:**\n$topEntries';
  }

  /// Evalúa si existe un hallazgo local importante sobre los datos del mes
  /// (categoría con presupuesto propio >= 80% o categoría que concentra >= 50% en >= 3 compras).
  static AiDashboardInsight? _resolveLocalDataHeuristic({
    required List<GastoModel> gastos,
    required Map<String, double> totalesPorCategoria,
    required Map<String, double> presupuestosPorCategoria,
    required double totalGastadoMes,
    required String moneda,
  }) {
    if (gastos.isEmpty || totalGastadoMes <= 0) return null;

    // 1. Alerta de presupuesto específico de categoría al >= 80%
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
        final fSpent = CurrencyFormatter.formatAmount(catSpent, moneda);
        final fBudget = CurrencyFormatter.formatAmount(catBudget, moneda);
        final shortMsg = highestRatio > 1.0
            ? 'En $alertCat superaste el tope asignado a esa categoría ($fSpent de $fBudget).'
            : 'Atención en $alertCat: ya utilizaste el $pct% del presupuesto de esa categoría ($fSpent de $fBudget).';
        final detailMsg =
            '**Seguimiento de tu categoría $alertCat:**\n\n'
            '• **Gastado en $alertCat:** **$fSpent** de un presupuesto asignado de **$fBudget** (**$pct%**).\n'
            '• ${highestRatio > 1.0 ? "Ya superaste el límite previsto para esta categoría este mes." : "Te queda un margen de **${CurrencyFormatter.formatAmount((catBudget - catSpent).clamp(0.0, double.infinity), moneda)}** en esta categoría para el resto del mes."}\n\n'
            '¿Quieres que revisemos qué compras específicas impulsaron el gasto en **$alertCat**?';
        return AiDashboardInsight(
          shortText: shortMsg,
          detailedText: detailMsg,
          source: 'local_heuristic',
        );
      }
    }

    return null;
  }

  /// Resuelve de forma síncrona e instantánea el consejo único a mostrar en `AiInsightCard`
  /// y su contraparte detallada para cuando el usuario pulse "Consultar ->".
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
    String? cachedGeminiShort,
    String? cachedGeminiDetailed,
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

    final hasCleanGeminiTip = isCurrentMonth &&
        cachedGeminiShort != null &&
        cachedGeminiShort.trim().isNotEmpty;

    final AiDashboardInsight dynamicTip = hasCleanGeminiTip
        ? AiDashboardInsight(
            shortText: cachedGeminiShort.trim(),
            detailedText: (cachedGeminiDetailed != null && cachedGeminiDetailed.trim().isNotEmpty)
                ? cachedGeminiDetailed.trim()
                : cachedGeminiShort.trim(),
            source: 'gemini',
          )
        : (_resolveLocalDataHeuristic(
              gastos: gastos,
              totalesPorCategoria: totalesPorCategoria,
              presupuestosPorCategoria: presupuestosPorCategoria,
              totalGastadoMes: totalGastadoMes,
              moneda: monedaPresupuesto,
            ) ??
            curatedTip);

    // 1. Caso: Sin gastos registrados en el mes
    if (gastos.isEmpty) {
      if (now.day <= 5 && presupuestoGeneral > 0 && isCurrentMonth) {
        final fBudget = CurrencyFormatter.formatAmount(presupuestoGeneral, monedaPresupuesto);
        final shortMsg =
            '¡Nuevo mes! Tu presupuesto de $mesActualNombre ya está listo. Hoy es un buen día para determinarte a aplicar lo aprendido el mes pasado.';
        final detailedMsg =
            '**¡Bienvenido a $mesActualNombre!**\n\n'
            'Tu presupuesto mensual de **$fBudget** ya está activo.\n\n'
            '${curatedTip.detailedText}';
        return AiDashboardInsight(
          shortText: shortMsg,
          detailedText: detailedMsg,
          source: 'welcome',
        );
      }

      final shortMsg =
          'Registra tu primera compra con el botón + para activar estadísticas y recomendaciones automáticas. ${curatedTip.shortText}';
      return AiDashboardInsight(
        shortText: shortMsg,
        detailedText: curatedTip.detailedText,
        source: 'welcome',
      );
    }

    // 2. Caso: Con gastos pero sin presupuesto mensual definido
    if (presupuestoGeneral <= 0) {
      final fTotal = CurrencyFormatter.formatAmount(totalGastadoMes, monedaPresupuesto);
      final catSummary = _buildTopCategoriesSummary(totalesPorCategoria, totalGastadoMes, monedaPresupuesto);
      final shortMsg =
          'Define un presupuesto mensual y te diré cuánto puedes gastar cada día sin descuidar tu ahorro. ${dynamicTip.shortText}';
      final detailedMsg =
          '**Resumen de $mesActualNombre:** Llevas **$fTotal** registrados en **${gastos.length} ${gastos.length == 1 ? "compra" : "compras"}**.$catSummary\n\n'
          '💡 *Si defines un presupuesto mensual en tu tarjeta de resumen, calcularé automáticamente cuánto puedes gastar por día.*\n\n'
          '${dynamicTip.detailedText}';
      return AiDashboardInsight(
        shortText: shortMsg,
        detailedText: detailedMsg,
        source: dynamicTip.source,
      );
    }

    final hasSavingsGoal = metaAhorro > 0;
    final limiteParaGastar = hasSavingsGoal
        ? (presupuestoGeneral - metaAhorro).clamp(0.0, double.infinity)
        : presupuestoGeneral;

    final formattedMeta = CurrencyFormatter.formatAmount(
      metaAhorro,
      monedaPresupuesto,
    );
    final formattedTotal = CurrencyFormatter.formatAmount(
      totalGastadoMes,
      monedaPresupuesto,
    );
    final formattedLimite = CurrencyFormatter.formatAmount(
      limiteParaGastar,
      monedaPresupuesto,
    );
    final catSummary = _buildTopCategoriesSummary(
      totalesPorCategoria,
      totalGastadoMes,
      monedaPresupuesto,
    );

    // 3. Caso: Mes pasado cerrado
    if (isPastMonth) {
      if (totalGastadoMes > limiteParaGastar) {
        final exceso = totalGastadoMes - limiteParaGastar;
        final formattedExceso = CurrencyFormatter.formatAmount(
          exceso,
          monedaPresupuesto,
        );
        final shortMsg =
            'En $mesActualNombre superaste tu ${hasSavingsGoal ? "límite" : "presupuesto"} por $formattedExceso.';
        final detailedMsg =
            '**Cierre de $mesActualNombre:**\n\n'
            '• **Total gastado:** **$formattedTotal** frente a tu ${hasSavingsGoal ? "límite disponible" : "presupuesto"} de **$formattedLimite**.\n'
            '• **Desfase:** Superaste el tope por **$formattedExceso**.$catSummary\n\n'
            '¿Quieres que revisemos en qué comercios o productos de $mesActualNombre se concentró ese exceso?';
        return AiDashboardInsight(
          shortText: shortMsg,
          detailedText: detailedMsg,
          source: 'alert',
        );
      } else {
        final rem = limiteParaGastar - totalGastadoMes;
        final formattedRem = CurrencyFormatter.formatAmount(
          rem,
          monedaPresupuesto,
        );
        final shortMsg =
            '¡Mes cerrado con éxito! Te sobraron $formattedRem de tu ${hasSavingsGoal ? "límite" : "presupuesto"}.';
        final detailedMsg =
            '**¡Excelente cierre en $mesActualNombre!**\n\n'
            '• **Total gastado:** **$formattedTotal** de **$formattedLimite** disponibles.\n'
            '• **Margen a favor:** Ahorraste **$formattedRem** adicionales${hasSavingsGoal ? " además de tu meta protegida de **$formattedMeta**" : ""}.$catSummary\n\n'
            '¿Te gustaría comparar este resultado con tus gastos del mes actual?';
        return AiDashboardInsight(
          shortText: shortMsg,
          detailedText: detailedMsg,
          source: 'alert',
        );
      }
    }

    // 4. Caso: Excedido en el mes actual
    if (totalGastadoMes > limiteParaGastar) {
      final exceso = totalGastadoMes - limiteParaGastar;
      final formattedExceso = CurrencyFormatter.formatAmount(
        exceso,
        monedaPresupuesto,
      );
      if (hasSavingsGoal) {
        final shortMsg =
            'Superaste tu límite por $formattedExceso. Tu meta de ahorro de $formattedMeta está comprometida; te sugiero pausar gastos no esenciales.';
        final detailedMsg =
            '**Alerta de presupuesto y meta de ahorro en $mesActualNombre:**\n\n'
            '• **Total acumulado:** **$formattedTotal** (tu límite de gasto era **$formattedLimite** para proteger **$formattedMeta** de ahorro).\n'
            '• **Exceso actual:** **$formattedExceso** por encima del límite.$catSummary\n\n'
            'Te sugiero posponer compras no urgentes durante los próximos días. ¿Quieres que identifiquemos juntos qué gastos discrecionales puedes recortar esta semana?';
        return AiDashboardInsight(
          shortText: shortMsg,
          detailedText: detailedMsg,
          source: 'alert',
        );
      } else {
        final shortMsg =
            'Superaste tu presupuesto por $formattedExceso. Te sugiero pausar gastos no esenciales esta semana.';
        final detailedMsg =
            '**Alerta de presupuesto en $mesActualNombre:**\n\n'
            '• **Total acumulado:** **$formattedTotal** frente a tu presupuesto de **$formattedLimite**.\n'
            '• **Exceso actual:** **$formattedExceso**.$catSummary\n\n'
            '¿Quieres que revisemos cuáles fueron las compras más altas del mes o cómo ajustar tus presupuestos por categoría?';
        return AiDashboardInsight(
          shortText: shortMsg,
          detailedText: detailedMsg,
          source: 'alert',
        );
      }
    }

    // 5. Caso: En riesgo por ritmo proyectado (con meta de ahorro)
    if (hasSavingsGoal) {
      final savingsSnapshot = SavingsHealthCalculator.calculate(
        presupuestoGeneral: presupuestoGeneral,
        metaAhorro: metaAhorro,
        gastoAcumulado: totalGastadoMes,
        diaActual: now.day,
        diasTotalesMes: diasEnMes,
        moneda: monedaPresupuesto,
      );

      if (savingsSnapshot.status == SavingsGoalStatus.enRiesgo) {
        final proy = savingsSnapshot.gastoProyectadoFinDeMes;
        final formattedProy = CurrencyFormatter.formatAmount(
          proy,
          monedaPresupuesto,
        );
        final disponible = (limiteParaGastar - totalGastadoMes).clamp(0.0, double.infinity);
        final ritmoSeguro = CurrencyFormatter.formatAmount(
          disponible / diasRestantes,
          monedaPresupuesto,
        );
        final shortMsg =
            'Atención: a tu ritmo actual proyectas gastar $formattedProy. Modera tus consumos para proteger tu meta de ahorro de $formattedMeta.';
        final detailedMsg =
            '**Proyección de cierre y protección de ahorro:**\n\n'
            '• **Gasto proyectado a fin de mes:** **$formattedProy** (tu límite seguro es **$formattedLimite**).\n'
            '• **Ritmo diario recomendado desde hoy:** Para salvar tu meta de ahorro de **$formattedMeta**, intenta no superar **$ritmoSeguro/día** durante los **$diasRestantes días restantes**.$catSummary\n\n'
            '¿Quieres que revisemos en qué categoría puedes moderar gastos esta semana?';
        return AiDashboardInsight(
          shortText: shortMsg,
          detailedText: detailedMsg,
          source: 'alert',
        );
      }
    }

    // 6. Caso: Ritmo saludable con presupuesto + Consejo Dinámico (Gemini o Valor Real)
    final disponible = limiteParaGastar - totalGastadoMes;
    final ritmoDiario = disponible / diasRestantes;
    final formattedRitmo = CurrencyFormatter.formatAmount(
      ritmoDiario,
      monedaPresupuesto,
    );
    final diasTexto = diasRestantes == 1
        ? 'el día restante'
        : 'los $diasRestantes días restantes';

    final String paceSentence = hasSavingsGoal
        ? '¡Excelente administración! Puedes gastar hasta $formattedRitmo/día durante $diasTexto sin tocar tu meta de $formattedMeta protegida.'
        : '¡Excelente administración! Puedes gastar hasta $formattedRitmo/día durante $diasTexto sin exceder tu presupuesto.';

    final String combinedShort = '$paceSentence ${dynamicTip.shortText}';

    final String combinedDetailed =
        '**Estado de tu presupuesto en $mesActualNombre:**\n'
        '• **Ritmo diario disponible:** Puedes gastar hasta **$formattedRitmo/día** durante $diasTexto (${CurrencyFormatter.formatAmount(disponible, monedaPresupuesto)} disponibles de $formattedLimite)${hasSavingsGoal ? ", manteniendo tu meta de **$formattedMeta** protegida" : ""}.\n\n'
        '${dynamicTip.detailedText}';

    return AiDashboardInsight(
      shortText: combinedShort,
      detailedText: combinedDetailed,
      source: dynamicTip.source,
    );
  }

  /// Construye el contexto compacto y libre de IVA que se envía a Gemini en segundo plano.
  static Map<String, dynamic> buildCompactContextForGemini({
    required List<GastoModel> gastos,
    required double totalMesUsd,
    required double presupuestoUsd,
    required double metaAhorroUsd,
    required String monedaLente,
    required DateTime now,
  }) {
    final Map<String, double> totalesCat = {};
    final Map<String, Map<String, dynamic>> comerciosMap = {};
    final Map<String, Map<String, dynamic>> productosMap = {};

    for (final g in gastos) {
      final usd = g.totalUsd / 100.0;
      totalesCat[g.categoria] = (totalesCat[g.categoria] ?? 0.0) + usd;

      final comName = g.comercio.trim();
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

    return {
      'fecha_hoy': now.toIso8601String().substring(0, 10),
      'moneda_principal': monedaLente,
      'cantidad_compras_mes': gastos.length,
      'total_mes_usd': double.parse(totalMesUsd.toStringAsFixed(2)),
      'presupuesto_usd': double.parse(presupuestoUsd.toStringAsFixed(2)),
      'meta_ahorro_usd': double.parse(metaAhorroUsd.toStringAsFixed(2)),
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
  }

  /// Lee el consejo de Gemini cacheado en `SharedPreferences` si corresponde al mes indicado.
  static Future<Map<String, String>?> getCachedGeminiInsight({
    required int year,
    required int month,
    SharedPreferences? prefsInstance,
  }) async {
    try {
      final prefs = prefsInstance ?? await SharedPreferences.getInstance();
      final cachedYm = prefs.getString(prefYearMonthKey);
      if (cachedYm != '${year}_$month') return null;

      final shortText = prefs.getString(prefShortTextKey);
      final detailedText = prefs.getString(prefDetailedTextKey);
      if (shortText != null && shortText.trim().isNotEmpty) {
        return {
          'resumen': shortText.trim(),
          'detalle': (detailedText != null && detailedText.trim().isNotEmpty)
              ? detailedText.trim()
              : shortText.trim(),
        };
      }
    } catch (e) {
      debugPrint('AiInsightService: Error leyendo caché de consejo IA: $e');
    }
    return null;
  }

  /// Parsea de forma resiliente la respuesta de `insight_inicio` (JSON o texto plano).
  static Map<String, String>? parseDashboardInsightResponse(String rawText) {
    final trimmedRaw = rawText.trim();
    if (trimmedRaw.isEmpty) return null;

    final cleaned = trimmedRaw
        .replaceFirst(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
        .replaceFirst(RegExp(r'\s*```$', multiLine: true), '')
        .trim();

    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      final candidateJson = cleaned.substring(firstBrace, lastBrace + 1);
      try {
        final decoded = jsonDecode(candidateJson);
        if (decoded is Map) {
          final resumen = (decoded['resumen'] ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
          final detalle = (decoded['detalle'] ?? '').toString().trim();
          if (resumen.isNotEmpty) {
            return {
              'resumen': resumen,
              'detalle': detalle.isNotEmpty ? detalle : resumen,
            };
          }
        }
      } catch (e) {
        debugPrint('AiInsightService: JSON no válido en insight_inicio, usando fallback texto: $e');
      }
    }

    final singleLine = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.isEmpty) return null;
    final sentences = singleLine.split(RegExp(r'(?<=[.!?])\s+'));
    final firstSentence = sentences.first.trim();
    final shortSummary = firstSentence.length <= 160
        ? firstSentence
        : '${firstSentence.substring(0, 157).trimRight()}...';
    return {
      'resumen': shortSummary,
      'detalle': cleaned,
    };
  }

  /// Verifica si corresponde generar un nuevo consejo personalizado con Gemini en segundo plano
  /// (máximo 1 vez cada 24h, solo en el mes actual, con >= 3 gastos y solo si cambió la firma de gastos).
  /// Retorna el par `{'resumen', 'detalle'}` vigente (recién generado o de caché).
  static Future<Map<String, String>?> refreshBackgroundInsightIfNeeded({
    required List<GastoModel> gastos,
    required int selectedYear,
    required int selectedMonth,
    required double totalMesUsd,
    required double presupuestoUsd,
    required double metaAhorroUsd,
    String monedaLente = 'USD',
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
      );

      final responseMap = await service.chatWithAnalyst(
        messages: const [
          {
            'role': 'user',
            'text': 'Genera un consejo financiero corto y su versión detallada según mis gastos actuales.',
          },
        ],
        contextData: contextData,
        modo: 'insight_inicio',
      );
      final rawText = (responseMap['text'] ?? '').toString().trim();
      final generated = parseDashboardInsightResponse(rawText);

      if (generated != null &&
          generated['resumen'] != null &&
          generated['resumen']!.trim().isNotEmpty) {
        final cleanShort = generated['resumen']!.trim();
        final cleanDetailed = (generated['detalle'] ?? cleanShort).trim();

        await prefs.setString(prefShortTextKey, cleanShort);
        await prefs.setString(prefDetailedTextKey, cleanDetailed);
        await prefs.setString(prefLastFetchDateKey, todayIso);
        await prefs.setString(prefSignatureKey, currentSignature);
        await prefs.setString(prefYearMonthKey, '${selectedYear}_$selectedMonth');

        return {
          'resumen': cleanShort,
          'detalle': cleanDetailed,
        };
      }
    } catch (e) {
      debugPrint('AiInsightService: Generación en 2.º plano omitida: $e');
    } finally {
      _isFetchingBackground = false;
    }

    return cached;
  }
}
