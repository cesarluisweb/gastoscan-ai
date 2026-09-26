import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/category_chart.dart';
import '../widgets/budget_bottom_sheet.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final mesNombre = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    final hasData = gastoProvider.totalesPorCategoria.isNotEmpty ||
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Selector de Mes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$mesNombre $anio',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
              categoryTotals: gastoProvider.totalesPorCategoria,
              categoryBudgets: gastoProvider.presupuestosPorCategoria,
              presupuestoGeneral: gastoProvider.presupuestoGeneral,
              totalGastadoMes: gastoProvider.totalMesUsd,
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
    );
  }

  Widget _buildGeneralBudgetCard(
    BuildContext context,
    GastoProvider gastoProvider,
    SettingsProvider settings,
  ) {
    final double budget = gastoProvider.presupuestoGeneral;
    final double spent = gastoProvider.totalMesUsd;
    final bool hasBudget = budget > 0;
    final bool isExceeded = hasBudget && spent > budget;
    final double percent = hasBudget ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final int pctUsed = hasBudget ? ((spent / budget) * 100).round() : 0;

    final now = DateTime.now();
    final isCurrentMonth = (now.month == gastoProvider.selectedMonth &&
        now.year == gastoProvider.selectedYear);
    final totalDays = DateTime(
      gastoProvider.selectedYear,
      gastoProvider.selectedMonth + 1,
      0,
    ).day;
    final daysRemaining = (totalDays - now.day).clamp(0, 31);

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
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, size: 20, color: AppColors.primaryDark),
                  SizedBox(width: 8),
                  Text(
                    'Control de Presupuesto Mensual General',
                    style: TextStyle(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${CurrencyFormatter.formatPreferido(spent, null, settings.tasaCambioVesUsd, settings.monedaPrincipal)} / ${CurrencyFormatter.formatPreferido(budget, null, settings.tasaCambioVesUsd, settings.monedaPrincipal)}',
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
                    'Presupuesto superado por ${CurrencyFormatter.formatPreferido(spent - budget, null, settings.tasaCambioVesUsd, settings.monedaPrincipal)}',
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
                    ? 'Te quedan ${CurrencyFormatter.formatPreferido(budget - spent, null, settings.tasaCambioVesUsd, settings.monedaPrincipal)} y faltan $daysRemaining días'
                    : 'Te sobraron ${CurrencyFormatter.formatPreferido(budget - spent, null, settings.tasaCambioVesUsd, settings.monedaPrincipal)} en este período',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
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
