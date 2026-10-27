import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/budget_bottom_sheet.dart';
import '../widgets/category_chart.dart';
import '../widgets/currency_lens_dropdown.dart';
import '../widgets/currency_radiography_card.dart';
import '../widgets/daily_evolution_card.dart';
import '../widgets/global_scan_queue_banner.dart';
import '../widgets/month_selector_bar.dart';
import '../widgets/purchase_radiography_card.dart';

class AnalysisScreen extends StatelessWidget {
  final VoidCallback? onNavigateToSearch;
  final VoidCallback? onNavigateToChat;

  const AnalysisScreen({
    Key? key,
    this.onNavigateToSearch,
    this.onNavigateToChat,
  }) : super(key: key);

  double _convertBudgetToLens(
    double amount,
    String fromMoneda,
    String toMoneda,
    SettingsProvider settings,
  ) {
    if (amount <= 0) return 0.0;
    if (fromMoneda == toMoneda) return amount;

    final double usdRate = settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0;
    final double eurRate = settings.tasaCambioVesEur > 0 ? settings.tasaCambioVesEur : usdRate;

    double inUsd = amount;
    if (fromMoneda == 'VES') {
      inUsd = amount / usdRate;
    } else if (fromMoneda == 'EUR') {
      inUsd = (amount * eurRate) / usdRate;
    } else if (fromMoneda == 'USDT') {
      inUsd = amount;
    }

    if (toMoneda == 'USD' || toMoneda == 'USDT') {
      return inUsd;
    } else if (toMoneda == 'VES') {
      return inUsd * usdRate;
    } else if (toMoneda == 'EUR') {
      return eurRate > 0 ? (inUsd * usdRate) / eurRate : inUsd;
    }
    return amount;
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    final hasData = gastoProvider.totalesPorCategoria.isNotEmpty ||
        gastoProvider.totalesPorCategoriaVes.isNotEmpty ||
        gastoProvider.presupuestosPorCategoria.isNotEmpty ||
        gastoProvider.presupuestoGeneral > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis'),
        actions: [
          IconButton(
            key: const Key('analysis_search_button'),
            icon: const Icon(
              Icons.search,
              size: 22,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Buscar',
            onPressed: onNavigateToSearch,
          ),
          IconButton(
            key: const Key('analysis_ai_chat_button'),
            icon: const Icon(
              Icons.auto_awesome,
              size: 22,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Asistente IA',
            onPressed: onNavigateToChat,
          ),
        ],
      ),
      body: Column(
        children: [
          const GlobalScanQueueBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                const MonthSelectorBar(
                  keyPrefix: 'analysis_',
                  padding: EdgeInsets.only(bottom: 12),
                ),

                if (gastoProvider.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  )
                else if (hasData) ...[
                  () {
                    final String budgetMoneda = gastoProvider.monedaPresupuesto;
                    final String activeMoneda = settings.monedaPrincipal;

                    final Map<String, double> categoryTotals;
                    final Map<String, double> categoryBudgets =
                        gastoProvider.presupuestosPorCategoria.map(
                      (k, v) => MapEntry(
                          k, _convertBudgetToLens(v, budgetMoneda, activeMoneda, settings)),
                    );
                    final double totalMes;
                    final double budgetGeneral = _convertBudgetToLens(
                      gastoProvider.presupuestoGeneral,
                      budgetMoneda,
                      activeMoneda,
                      settings,
                    );
                    final double metaAhorro = _convertBudgetToLens(
                      gastoProvider.metaAhorro,
                      budgetMoneda,
                      activeMoneda,
                      settings,
                    );
                    final double limiteTarget = metaAhorro > 0
                        ? (budgetGeneral - metaAhorro).clamp(0.0, double.infinity)
                        : budgetGeneral;

                    if (activeMoneda == 'VES') {
                      categoryTotals = gastoProvider.totalesPorCategoriaVes;
                      totalMes = gastoProvider.totalMesVes;
                    } else if (activeMoneda == 'USD') {
                      categoryTotals = gastoProvider.totalesPorCategoria;
                      totalMes = gastoProvider.totalMesUsd;
                    } else if (activeMoneda == 'USDT') {
                      categoryTotals = gastoProvider.totalesPorCategoriaUsdt;
                      totalMes = gastoProvider.totalMesUsdt;
                    } else {
                      // EUR
                      final double eurRate = settings.tasaCambioVesEur > 0
                          ? settings.tasaCambioVesEur
                          : (settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0);
                      categoryTotals = gastoProvider.totalesPorCategoriaVes.isNotEmpty
                          ? gastoProvider.totalesPorCategoriaVes.map(
                              (k, v) => MapEntry(k, eurRate > 0 ? (v / eurRate) : 0.0))
                          : gastoProvider.totalesPorCategoria.map((k, v) => MapEntry(
                                k,
                                CurrencyFormatter.convertFromUsd(
                                  v,
                                  activeMoneda,
                                  settings.tasaCambioVesUsd,
                                  tasaEur: settings.tasaCambioVesEur,
                                  tasaUsdt: settings.tasaCambioVesUsdt,
                                ),
                              ));
                      totalMes = gastoProvider.totalMesVes > 0 && eurRate > 0
                          ? (gastoProvider.totalMesVes / eurRate)
                          : CurrencyFormatter.convertFromUsd(
                              gastoProvider.totalMesUsd,
                              activeMoneda,
                              settings.tasaCambioVesUsd,
                              tasaEur: settings.tasaCambioVesEur,
                              tasaUsdt: settings.tasaCambioVesUsdt,
                            );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tarjeta 1 — Total Gastado y Proyección de Fin de Mes
                        _buildGeneralBudgetCard(
                            context, gastoProvider, settings, activeMoneda),
                        const SizedBox(height: 16),

                        // Tarjeta 2 — Evolución Diaria (Tarjeta independiente)
                        DailyEvolutionCard(
                          gastosMes: gastoProvider.gastos,
                          totalGastadoMes: totalMes,
                          limitePresupuesto: limiteTarget,
                          monedaPrincipal: activeMoneda,
                          anio: gastoProvider.selectedYear,
                          mes: gastoProvider.selectedMonth,
                          tasaCambio: settings.tasaCambioVesUsd,
                          tasaEur: settings.tasaCambioVesEur,
                          tasaUsdt: settings.tasaCambioVesUsdt,
                        ),
                        const SizedBox(height: 16),

                        // Tarjeta 3 (Dona) y Tarjeta 4 (Control por Categoría)
                        CategoryChart(
                          categoryTotals: categoryTotals,
                          categoryBudgets: categoryBudgets,
                          presupuestoGeneral: budgetGeneral,
                          totalGastadoMes: totalMes,
                          gastosMes: gastoProvider.gastos,
                          onSetBudget: (categoria, budget) async {
                            await gastoProvider.setPresupuestoCategoria(categoria, budget);
                          },
                          monedaPrincipal: activeMoneda,
                          showBudgetBars: true,
                          separateCards: true,
                          tasaCambio: settings.tasaCambioVesUsd,
                          tasaEur: settings.tasaCambioVesEur,
                          tasaUsdt: settings.tasaCambioVesUsdt,
                        ),
                        const SizedBox(height: 16),

                        // Tarjeta 5 — ¿En qué moneda se va tu dinero? (Radiografía por moneda de origen)
                        CurrencyRadiographyCard(
                          gastosMes: gastoProvider.gastos,
                          monedaPrincipal: activeMoneda,
                          tasaCambio: settings.tasaCambioVesUsd,
                          tasaEur: settings.tasaCambioVesEur,
                          tasaUsdt: settings.tasaCambioVesUsdt,
                        ),
                        const SizedBox(height: 16),

                        // Tarjeta 6 — Radiografía de Compras (Gastos Hormiga vs. Fuertes)
                        PurchaseRadiographyCard(
                          gastosMes: gastoProvider.gastos,
                          monedaPrincipal: activeMoneda,
                          tasaCambio: settings.tasaCambioVesUsd,
                          tasaEur: settings.tasaCambioVesEur,
                          tasaUsdt: settings.tasaCambioVesUsdt,
                        ),
                      ],
                    );
                  }(),
                ] else
                  _buildEmptyAnalysisState(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralBudgetCard(
    BuildContext context,
    GastoProvider gastoProvider,
    SettingsProvider settings,
    String activeMoneda,
  ) {
    final String budgetMoneda = gastoProvider.monedaPresupuesto;
    final double rawBudget = gastoProvider.presupuestoGeneral;
    final double rawMetaAhorro = gastoProvider.metaAhorro;

    final double budget = _convertBudgetToLens(rawBudget, budgetMoneda, activeMoneda, settings);
    final double metaAhorro =
        _convertBudgetToLens(rawMetaAhorro, budgetMoneda, activeMoneda, settings);
    final double spent;

    if (activeMoneda == 'VES') {
      spent = gastoProvider.totalMesVes;
    } else if (activeMoneda == 'USD') {
      spent = gastoProvider.totalMesUsd;
    } else if (activeMoneda == 'USDT') {
      spent = gastoProvider.totalMesUsdt;
    } else {
      // EUR
      final double eurRate = settings.tasaCambioVesEur > 0
          ? settings.tasaCambioVesEur
          : (settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0);
      spent = gastoProvider.totalMesVes > 0 && eurRate > 0
          ? (gastoProvider.totalMesVes / eurRate)
          : CurrencyFormatter.convertFromUsd(
              gastoProvider.totalMesUsd,
              activeMoneda,
              settings.tasaCambioVesUsd,
              tasaEur: settings.tasaCambioVesEur,
              tasaUsdt: settings.tasaCambioVesUsdt,
            );
    }

    final bool hasSavingsGoal = metaAhorro > 0;
    final double limiteParaGastar = hasSavingsGoal
        ? (budget - metaAhorro).clamp(0.0, double.infinity)
        : budget;

    final bool hasBudget = budget > 0;
    final double targetBudget = hasSavingsGoal ? limiteParaGastar : budget;
    final bool isExceeded = hasBudget && (targetBudget > 0 ? spent > targetBudget : spent > 0);
    final double percentUsed = (hasBudget && targetBudget > 0) ? (spent / targetBudget) : 0.0;

    final now = DateTime.now();
    final isCurrentMonth = (now.month == gastoProvider.selectedMonth &&
        now.year == gastoProvider.selectedYear);
    final isPastMonth = gastoProvider.selectedYear < now.year ||
        (gastoProvider.selectedYear == now.year &&
            gastoProvider.selectedMonth < now.month);
    final totalDays = DateTime(
      gastoProvider.selectedYear,
      gastoProvider.selectedMonth + 1,
      0,
    ).day;
    final int diasTranscurridos = isCurrentMonth
        ? now.day.clamp(1, totalDays)
        : (isPastMonth ? totalDays : 1);
    final double promedioDia = diasTranscurridos > 0 ? (spent / diasTranscurridos) : 0.0;
    final double proyeccion = promedioDia * totalDays;
    final bool proyectaSuperar = targetBudget > 0 && (proyeccion > targetBudget);

    String formatSecundarioAmount(double amountInLens) {
      final double usdRate =
          settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0;
      if (activeMoneda == 'VES') {
        final inUsd = amountInLens / usdRate;
        return CurrencyFormatter.formatUsd(inUsd);
      } else {
        final inVes = amountInLens * usdRate;
        return CurrencyFormatter.formatVes(inVes);
      }
    }

    String fmt(double val) => CurrencyFormatter.formatAmount(val, activeMoneda);

    return Container(
      key: const Key('general_budget_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExceeded ? AppColors.error.withValues(alpha: 0.04) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExceeded ? AppColors.error.withValues(alpha: 0.4) : AppColors.border,
          width: isExceeded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fila superior: Título con mes y selector desplegable compacto [ USD BCV ▾ ]
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  'Total gastado en ${DateFormatter.obtenerNombreMes(gastoProvider.selectedMonth)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const CurrencyLensDropdown(
                dropdownKey: Key('summary_card_lens_dropdown'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Monto principal y límite: En una misma fila alineada por su línea base en FittedBox
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  fmt(spent),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isExceeded ? AppColors.error : AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (hasBudget) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    key: const Key('analysis_edit_budget_button'),
                    onTap: () => BudgetBottomSheet.show(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'de ${fmt(targetBudget)}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.edit_outlined,
                            size: 15,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (!hasBudget) ...[
            const SizedBox(height: 8),
            InkWell(
              key: const Key('analysis_edit_budget_button'),
              onTap: () => BudgetBottomSheet.show(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 15, color: Colors.black),
                    SizedBox(width: 4),
                    Text(
                      'Definir presupuesto',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 3),
          Text(
            '≈ ${formatSecundarioAmount(spent)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          if (isExceeded) ...[
            const SizedBox(height: 10),
            Row(
              key: const Key('excess_alert_general'),
              children: [
                const Icon(Icons.warning_amber_rounded, size: 15, color: AppColors.error),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    hasSavingsGoal
                        ? 'Límite de gasto superado por ${fmt(spent - targetBudget)}'
                        : 'Presupuesto superado por ${fmt(spent - targetBudget)}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (hasBudget) ...[
            const SizedBox(height: 12),
            // Barra lineal limpia de 10dp con marcador vertical de ahorro
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final double rawLimiteRatio = budget > 0 ? (limiteParaGastar / budget) : 1.0;
                final double savingsMarkerPos =
                    (totalWidth * rawLimiteRatio).clamp(0.0, totalWidth);
                final double barFillRatio = budget > 0 ? (spent / budget) : 0.0;

                final bool isCaution = !isExceeded && percentUsed >= 0.85;

                final Color barColor;
                if (isExceeded) {
                  barColor = AppColors.error;
                } else if (isCaution) {
                  barColor = const Color(0xFFF59E0B);
                } else {
                  barColor = const Color(0xFF1E293B);
                }

                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: barFillRatio.clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: AppColors.cardLighter,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    if (hasSavingsGoal)
                      Positioned(
                        left: (savingsMarkerPos - 1.0).clamp(0.0, totalWidth - 2.0),
                        top: -3,
                        bottom: -3,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4B5563),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            // Recuadro analítico inferior (Caja gris suave rounded-xl con padding 14dp)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                children: [
                  // Fila 1: Presupuesto Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          hasSavingsGoal
                              ? 'Presupuesto Total (incluye ${fmt(metaAhorro)} de ahorro)'
                              : 'Presupuesto Total',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            fmt(budget),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Fila 2: Promedio gastado por día
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Promedio gastado por día',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${fmt(promedioDia)} / día',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Fila 3: Ritmo / Proyección o Gasto final
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isPastMonth
                              ? 'Gasto final del mes'
                              : 'Si sigues a este ritmo gastarás en el mes',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 150),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            isPastMonth
                                ? fmt(spent)
                                : '${proyectaSuperar ? '↗' : '↘'} ≈ ${fmt(proyeccion)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isPastMonth
                                  ? (isExceeded ? AppColors.error : const Color(0xFF16A34A))
                                  : (proyectaSuperar ? AppColors.error : const Color(0xFF16A34A)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyAnalysisState(BuildContext context) {
    return Container(
      key: const Key('analysis_empty_state'),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.pie_chart_outline, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Sin estadísticas aún',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Registra gastos este mes o asigna presupuestos para ver la distribución detallada de tus finanzas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            key: const Key('analysis_empty_budget_button'),
            icon: const Icon(Icons.add, color: AppColors.textPrimary),
            label: const Text(
              'Asignar presupuesto mensual',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => BudgetBottomSheet.show(context),
          ),
        ],
      ),
    );
  }
}
