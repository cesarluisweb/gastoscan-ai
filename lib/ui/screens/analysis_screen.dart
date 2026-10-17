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
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildLensSwitch(context, settings),
            ),
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
              final String activeMoneda = settings.monedaPrincipal;
              final double tUsd = settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0;
              final double tEur = settings.tasaCambioVesEur > 0 ? settings.tasaCambioVesEur : tUsd;

              double convertAmountToLens(double amount) {
                if (amount <= 0 || gastoProvider.monedaPresupuesto == activeMoneda) return amount;
                double inUsd;
                if (isBudgetVes) {
                  inUsd = tUsd > 0 ? (amount / tUsd) : amount;
                } else if (gastoProvider.monedaPresupuesto == 'EUR') {
                  inUsd = (tUsd > 0 && tEur > 0) ? (amount * tEur / tUsd) : amount;
                } else {
                  inUsd = amount; // USD o USDT (1:1)
                }

                if (activeMoneda == 'VES') {
                  return inUsd * tUsd;
                } else if (activeMoneda == 'EUR') {
                  return tEur > 0 ? (inUsd * tUsd / tEur) : inUsd;
                } else {
                  return inUsd; // USD o USDT (1:1)
                }
              }

              final Map<String, double> categoryTotals;
              final Map<String, double> categoryBudgets = gastoProvider.presupuestosPorCategoria.map((k, v) => MapEntry(
                    k,
                    convertAmountToLens(v),
                  ));
              final double totalMes;
              final double budgetGeneral = convertAmountToLens(gastoProvider.presupuestoGeneral);

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
                categoryTotals = gastoProvider.totalesPorCategoriaVes.map((k, v) => MapEntry(
                      k,
                      tEur > 0 ? v / tEur : 0.0,
                    ));
                totalMes = tEur > 0 ? (gastoProvider.totalMesVes / tEur) : gastoProvider.totalMesUsd;
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

    final double tUsd = settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0;
    final double tEur = settings.tasaCambioVesEur > 0 ? settings.tasaCambioVesEur : tUsd;

    double convertAmountToLens(double amount) {
      if (amount <= 0 || gastoProvider.monedaPresupuesto == activeMoneda) return amount;
      double inUsd;
      if (isBudgetVes) {
        inUsd = tUsd > 0 ? (amount / tUsd) : amount;
      } else if (gastoProvider.monedaPresupuesto == 'EUR') {
        inUsd = (tUsd > 0 && tEur > 0) ? (amount * tEur / tUsd) : amount;
      } else {
        inUsd = amount; // USD o USDT (1:1)
      }

      if (activeMoneda == 'VES') {
        return inUsd * tUsd;
      } else if (activeMoneda == 'EUR') {
        return tEur > 0 ? (inUsd * tUsd / tEur) : inUsd;
      } else {
        return inUsd; // USD o USDT (1:1)
      }
    }

    final double budget = convertAmountToLens(rawBudget);
    final double metaAhorro = convertAmountToLens(rawMetaAhorro);
    final double spent;

    if (activeMoneda == 'VES') {
      spent = gastoProvider.totalMesVes;
    } else if (activeMoneda == 'USD') {
      spent = gastoProvider.totalMesUsd;
    } else if (activeMoneda == 'USDT') {
      spent = gastoProvider.totalMesUsdt;
    } else {
      // EUR
      spent = tEur > 0 ? (gastoProvider.totalMesVes / tEur) : gastoProvider.totalMesUsd;
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
                          AppColors.getBudgetProgressColor(percent, isExceeded: isExceeded),
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

  Widget _buildLensSwitch(BuildContext context, SettingsProvider settings) {
    final current = settings.monedaPrincipal;
    final lenses = [
      {'id': 'USD', 'label': 'USD BCV'},
      {'id': 'USDT', 'label': 'USDT P2P'},
      {'id': 'EUR', 'label': 'EUR BCV'},
      {'id': 'VES', 'label': 'Bs.'},
    ];

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.cardLighter,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: lenses.map((l) {
          final isSelected = current == l['id'];
          return InkWell(
            key: Key('analysis_lens_${l['id']?.toLowerCase()}'),
            onTap: () => settings.setMonedaPrincipal(l['id']!),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                boxShadow: isSelected
                    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                    : null,
              ),
              child: Text(
                l['label']!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
