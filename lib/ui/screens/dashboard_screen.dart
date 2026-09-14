import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../services/export_service.dart';
import '../widgets/summary_card.dart';
import '../widgets/category_chart.dart';
import '../widgets/expense_card.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  void _exportarCsv(BuildContext context) async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final todosLosGastos = await gastoProvider.obtenerTodosParaExportar();

    if (todosLosGastos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay gastos registrados para exportar.')),
      );
      return;
    }

    final csvContent = ExportService.generateCsvData(todosLosGastos);
    final fileName = 'gastos_${DateTime.now().toIso8601String().substring(0, 10)}.csv';

    await ExportService.exportAndShare(
      content: csvContent,
      filename: fileName,
      mimeType: 'text/csv',
    );
  }

  void _exportarMarkdown(BuildContext context) async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final todosLosGastos = await gastoProvider.obtenerTodosParaExportar();

    if (todosLosGastos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay gastos registrados para exportar.')),
      );
      return;
    }

    final periodo = '${DateFormatter.getMonthName(gastoProvider.selectedMonth)} ${gastoProvider.selectedYear}';
    final mdContent = ExportService.generateMarkdownReport(todosLosGastos, periodo: periodo);
    final fileName = 'reporte_gastos_${DateTime.now().toIso8601String().substring(0, 10)}.md';

    await ExportService.exportAndShare(
      content: mdContent,
      filename: fileName,
      mimeType: 'text/markdown',
    );
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final mesNombre = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GastoScan AI'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Exportar Reportes',
            color: AppColors.surface,
            onSelected: (val) {
              if (val == 'csv') _exportarCsv(context);
              if (val == 'md') _exportarMarkdown(context);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'csv',
                child: Row(
                  children: [
                    Icon(Icons.table_chart_outlined, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Exportar a CSV (.csv)', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'md',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: AppColors.secondary, size: 18),
                    SizedBox(width: 8),
                    Text('Exportar a Markdown (.md)', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Ajustes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => gastoProvider.cargarDatos(),
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
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
            const SizedBox(height: 8),
            SummaryCard(
              totalUsd: gastoProvider.totalMesUsd,
              totalVes: gastoProvider.totalMesVes,
              periodo: '$mesNombre $anio',
            ),
            const SizedBox(height: 16),
            if (gastoProvider.totalesPorCategoria.isNotEmpty) ...[
              CategoryChart(categoryTotals: gastoProvider.totalesPorCategoria),
              const SizedBox(height: 16),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Comprobantes Registrados',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (gastoProvider.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (gastoProvider.gastos.isEmpty)
              _buildEmptyState()
            else
              ...gastoProvider.gastos.map((gasto) {
                return ExpenseCard(
                  gasto: gasto,
                  onDelete: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.card,
                        title: const Text('Eliminar Comprobante', style: TextStyle(color: AppColors.textPrimary)),
                        content: Text(
                          '¿Deseas eliminar el gasto de "${gasto.comercio}"?',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && gasto.id != null) {
                      gastoProvider.eliminarGasto(gasto.id!);
                    }
                  },
                );
              }).toList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScanScreen()),
          );
        },
        icon: const Icon(Icons.document_scanner_outlined),
        label: const Text(
          'Escanear Factura',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Sin comprobantes en este mes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Presiona "Escanear Factura" para digitalizar tu primer comprobante.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
