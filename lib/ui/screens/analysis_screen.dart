import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/finance/savings_health_models.dart';
import '../../domain/finance/savings_health_calculator.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/category_chart.dart';
import '../widgets/budget_bottom_sheet.dart';
import '../widgets/global_scan_queue_banner.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final mesNombre = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    final hasData = gastoProvider.totalesPorCategoria.isNotEmpty ||
        gastoProvider.totalesPorCategoriaVes.isNotEmpty ||
        gastoProvider.presupuestosPorCategoria.isNotEmpty ||
        gastoProvider.presupuestoGeneral > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análisis'),
        actions: [
          IconButton(
            key: const Key('analysis_edit_budget_button'),
            icon: const Icon(Icons.tune),
            tooltip: 'Configurar Presupuestos',
            onPressed: () {
              BudgetBottomSheet.show(context);
            },
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
          // Selector de Mes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                key: const Key('analysis_month_selector_title'),
                onTap: () => _mostrarPickerMes(context, gastoProvider),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$mesNombre $anio',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.textPrimary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                    onPressed: () {
                      int nuevoMes = gastoProvider.selectedMonth - 1;
                      int nuevoAnio = gastoProvider.selectedYear;
                      if (nuevoMes < 1) {
                        nuevoMes = 12;
                        nuevoAnio--;
                      }
                      gastoProvider.cambiarMes(nuevoAnio, nuevoMes);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    onPressed: () {
                      int nuevoMes = gastoProvider.selectedMonth + 1;
                      int nuevoAnio = gastoProvider.selectedYear;
                      if (nuevoMes > 12) {
                        nuevoMes = 1;
                        nuevoAnio++;
                      }
                      gastoProvider.cambiarMes(nuevoAnio, nuevoMes);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (gastoProvider.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (hasData) ...[
            _buildGeneralBudgetCard(context, gastoProvider, settings),
            const SizedBox(height: 16),
            CategoryChart(
              categoryTotals: settings.monedaPrincipal == 'VES'
                  ? gastoProvider.totalesPorCategoriaVes
                  : gastoProvider.totalesPorCategoria,
              categoryBudgets: gastoProvider.presupuestosPorCategoria,
              presupuestoGeneral: gastoProvider.presupuestoGeneral,
              totalGastadoMes: settings.monedaPrincipal == 'VES'
                  ? gastoProvider.totalMesVes
                  : gastoProvider.totalMesUsd,
              gastosMes: gastoProvider.gastos,
              onSetBudget: (categoria, budget) async {
                await gastoProvider.setPresupuestoCategoria(categoria, budget);
              },
              monedaPrincipal: settings.monedaPrincipal,
              tasaCambio: settings.tasaCambioVesUsd,
              showBudgetBars: true,
            ),
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
  ) {
    final isBudgetVes = gastoProvider.monedaPresupuesto == 'VES';
    final double budget = gastoProvider.presupuestoGeneral;
    final double metaAhorro = gastoProvider.metaAhorro;
    final bool hasSavingsGoal = metaAhorro > 0;
    final double limiteParaGastar = hasSavingsGoal
        ? (budget - metaAhorro).clamp(0.0, double.infinity)
        : budget;

    final double spent = isBudgetVes
        ? gastoProvider.totalMesVes
        : gastoProvider.totalMesUsd;
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
        color: isExceeded ? AppColors.error.withOpacity(0.06) : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExceeded ? AppColors.error.withOpacity(0.4) : AppColors.border,
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
                String fmtAmount(double val) => isBudgetVes
                    ? CurrencyFormatter.formatVes(val)
                    : CurrencyFormatter.formatPreferido(val, null, settings.tasaCambioVesUsd, settings.monedaPrincipal);

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
                                Text(fmtAmount(snapshot.gastoProyectadoFinDeMes), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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

  void _mostrarPickerMes(BuildContext context, GastoProvider gastoProvider) {
    int tempAnio = gastoProvider.selectedYear;

    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    showDialog(
      context: context,
      builder: (dContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                    onPressed: () {
                      setStateDialog(() {
                        tempAnio--;
                      });
                    },
                  ),
                  Text(
                    '$tempAnio',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                    onPressed: () {
                      setStateDialog(() {
                        tempAnio++;
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 280,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final mesNum = index + 1;
                    final isSelected = (mesNum == gastoProvider.selectedMonth && tempAnio == gastoProvider.selectedYear);
                    return InkWell(
                      key: Key('analysis_month_pick_$mesNum'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        gastoProvider.cambiarMes(tempAnio, mesNum);
                        Navigator.pop(dContext);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.cardLighter,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryDark : AppColors.border,
                          ),
                        ),
                        child: Text(
                          meses[index].substring(0, 3),
                          style: TextStyle(
                            color: isSelected ? AppColors.secondary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dContext),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
