import '../widgets/month_selector_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/category_chart.dart';
import '../widgets/budget_bottom_sheet.dart';
import '../widgets/global_scan_queue_banner.dart';

class AnalysisScreen extends StatelessWidget {
  final VoidCallback? onNavigateToSearch;
  final VoidCallback? onNavigateToChat;

  const AnalysisScreen({
    Key? key,
    this.onNavigateToSearch,
    this.onNavigateToChat,
  }) : super(key: key);

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              final bool isBudgetVes = gastoProvider.monedaPresupuesto == 'VES';
              final String activeMoneda = isBudgetVes ? 'VES' : settings.monedaPrincipal;

              final Map<String, double> categoryTotals;
              final Map<String, double> categoryBudgets;
              final double totalMes;
              final double budgetGeneral;

              if (activeMoneda == 'VES') {
                categoryTotals = gastoProvider.totalesPorCategoriaVes;
                categoryBudgets = isBudgetVes
                    ? gastoProvider.presupuestosPorCategoria
                    : gastoProvider.presupuestosPorCategoria.map((k, v) => MapEntry(
                          k,
                          CurrencyFormatter.convertFromUsd(v, 'VES', settings.tasaCambioVesUsd),
                        ));
                totalMes = gastoProvider.totalMesVes;
                budgetGeneral = isBudgetVes
                    ? gastoProvider.presupuestoGeneral
                    : CurrencyFormatter.convertFromUsd(gastoProvider.presupuestoGeneral, 'VES', settings.tasaCambioVesUsd);
              } else if (activeMoneda == 'USD') {
                categoryTotals = gastoProvider.totalesPorCategoria;
                categoryBudgets = gastoProvider.presupuestosPorCategoria;
                totalMes = gastoProvider.totalMesUsd;
                budgetGeneral = gastoProvider.presupuestoGeneral;
              } else {
                // EUR o USDT
                categoryTotals = gastoProvider.totalesPorCategoria.map((k, v) => MapEntry(
                      k,
                      CurrencyFormatter.convertFromUsd(
                        v,
                        activeMoneda,
                        settings.tasaCambioVesUsd,
                        tasaEur: settings.tasaCambioVesEur,
                        tasaUsdt: settings.tasaCambioVesUsdt,
                      ),
                    ));
                categoryBudgets = gastoProvider.presupuestosPorCategoria.map((k, v) => MapEntry(
                      k,
                      CurrencyFormatter.convertFromUsd(
                        v,
                        activeMoneda,
                        settings.tasaCambioVesUsd,
                        tasaEur: settings.tasaCambioVesEur,
                        tasaUsdt: settings.tasaCambioVesUsdt,
                      ),
                    ));
                totalMes = CurrencyFormatter.convertFromUsd(
                  gastoProvider.totalMesUsd,
                  activeMoneda,
                  settings.tasaCambioVesUsd,
                  tasaEur: settings.tasaCambioVesEur,
                  tasaUsdt: settings.tasaCambioVesUsdt,
                );
                budgetGeneral = CurrencyFormatter.convertFromUsd(
                  gastoProvider.presupuestoGeneral,
                  activeMoneda,
                  settings.tasaCambioVesUsd,
                  tasaEur: settings.tasaCambioVesEur,
                  tasaUsdt: settings.tasaCambioVesUsdt,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGeneralBudgetCard(context, gastoProvider, settings, activeMoneda),
                  const SizedBox(height: 16),
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
                    tasaCambio: settings.tasaCambioVesUsd,
                    tasaEur: settings.tasaCambioVesEur,
                    tasaUsdt: settings.tasaCambioVesUsdt,
                  ),
                ],
              );
            }(),
          ] else
            _buildEmptyAnalysisState(context),

          const SizedBox(height: 80),
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
    final bool isBudgetVes = gastoProvider.monedaPresupuesto == 'VES';
    final double rawBudget = gastoProvider.presupuestoGeneral;
    final double rawMetaAhorro = gastoProvider.metaAhorro;

    final double budget;
    final double metaAhorro;
    final double spent;

    if (activeMoneda == 'VES') {
      budget = isBudgetVes ? rawBudget : CurrencyFormatter.convertFromUsd(rawBudget, 'VES', settings.tasaCambioVesUsd);
      metaAhorro = isBudgetVes ? rawMetaAhorro : CurrencyFormatter.convertFromUsd(rawMetaAhorro, 'VES', settings.tasaCambioVesUsd);
      spent = gastoProvider.totalMesVes;
    } else if (activeMoneda == 'USD') {
      budget = isBudgetVes ? (settings.tasaCambioVesUsd > 0 ? rawBudget / settings.tasaCambioVesUsd : 0.0) : rawBudget;
      metaAhorro = isBudgetVes ? (settings.tasaCambioVesUsd > 0 ? rawMetaAhorro / settings.tasaCambioVesUsd : 0.0) : rawMetaAhorro;
      spent = gastoProvider.totalMesUsd;
    } else {
      // EUR o USDT
      budget = CurrencyFormatter.convertFromUsd(
        rawBudget,
        activeMoneda,
        settings.tasaCambioVesUsd,
        tasaEur: settings.tasaCambioVesEur,
        tasaUsdt: settings.tasaCambioVesUsdt,
      );
      metaAhorro = CurrencyFormatter.convertFromUsd(
        rawMetaAhorro,
        activeMoneda,
        settings.tasaCambioVesUsd,
        tasaEur: settings.tasaCambioVesEur,
        tasaUsdt: settings.tasaCambioVesUsdt,
      );
      spent = CurrencyFormatter.convertFromUsd(
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
    final double percent = (hasBudget && targetBudget > 0) ? (spent / targetBudget).clamp(0.0, 1.0) : 0.0;
    final int pctUsed = (hasBudget && targetBudget > 0) ? ((spent / targetBudget) * 100).round() : 0;

    final now = DateTime.now();
    final isCurrentMonth = (now.month == gastoProvider.selectedMonth &&
        now.year == gastoProvider.selectedYear);
    final totalDays = DateTime(
      gastoProvider.selectedYear,
      gastoProvider.selectedMonth + 1,
      0,
    ).day;
    final daysRemaining = (totalDays - now.day).clamp(0, 31);

    final snapshot = hasSavingsGoal ? gastoProvider.savingsSnapshot : null;

    return Container(
      key: const Key('general_budget_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExceeded ? AppColors.error.withValues(alpha: 0.06) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExceeded ? AppColors.error.withValues(alpha: 0.4) : AppColors.border,
          width: isExceeded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    hasSavingsGoal ? Icons.savings_outlined : Icons.account_balance_wallet,
                    size: 20,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasSavingsGoal
                        ? 'Límite para Gastar y Ahorro'
                        : 'Control de Presupuesto Mensual General',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                key: const Key('analysis_edit_budget_button'),
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.secondary),
                tooltip: 'Editar Presupuesto',
                onPressed: () => BudgetBottomSheet.show(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasBudget) ...[
            Builder(
              builder: (context) {
                String fmtAmount(double val) {
                  return CurrencyFormatter.formatAmount(val, activeMoneda);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${fmtAmount(spent)} / ${fmtAmount(targetBudget)}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isExceeded ? AppColors.error : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '$pctUsed% usado',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isExceeded ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 10,
                        backgroundColor: AppColors.cardLighter,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isExceeded
                              ? AppColors.error
                              : (percent >= 0.85 ? AppColors.warning : AppColors.primaryDark),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (isExceeded)
                      Row(
                        key: const Key('excess_alert_general'),
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
                          const SizedBox(width: 4),
                          Text(
                            hasSavingsGoal
                                ? 'Límite de gasto superado por ${fmtAmount(spent - targetBudget)}'
                                : 'Presupuesto superado por ${fmtAmount(spent - targetBudget)}',
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        isCurrentMonth
                            ? (hasSavingsGoal
                                ? 'Te quedan ${fmtAmount(targetBudget - spent)} para gastar y faltan $daysRemaining días'
                                : 'Te quedan ${fmtAmount(targetBudget - spent)} y faltan $daysRemaining días')
                            : 'Te sobraron ${fmtAmount(targetBudget - spent)} en este período',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    if (hasSavingsGoal && snapshot != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cardLighter,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Presupuesto Total:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                Text(fmtAmount(budget), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Meta de Ahorro / Inversión:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                Text(fmtAmount(metaAhorro), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Gasto Proyectado Fin de Mes:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                Text(
                                  fmtAmount(
                                    (activeMoneda == 'EUR' || activeMoneda == 'USDT')
                                        ? CurrencyFormatter.convertFromUsd(
                                            snapshot.gastoProyectadoFinDeMes,
                                            activeMoneda,
                                            settings.tasaCambioVesUsd,
                                            tasaEur: settings.tasaCambioVesEur,
                                            tasaUsdt: settings.tasaCambioVesUsdt,
                                          )
                                        : snapshot.gastoProyectadoFinDeMes,
                                  ),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ] else ...[
            const Text(
              'Aún no has configurado un presupuesto general para este mes.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              key: const Key('btn_definir_presupuesto_general'),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Definir Presupuesto General'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () => BudgetBottomSheet.show(context),
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
