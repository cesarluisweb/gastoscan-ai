import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
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
          else if (hasData)
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
            )
          else
            _buildEmptyAnalysisState(context),

          const SizedBox(height: 80),
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
