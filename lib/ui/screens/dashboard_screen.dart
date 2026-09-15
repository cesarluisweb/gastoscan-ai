import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scan_queue_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../../services/export_service.dart';
import '../widgets/summary_card.dart';
import '../widgets/category_chart.dart';
import '../widgets/expense_card.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'review_expense_screen.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/gemini_extraction_result.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  void _exportarCsv(BuildContext context) async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final gastosMes = gastoProvider.gastos;

    if (gastosMes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay gastos en este mes para exportar.')),
      );
      return;
    }

    final csvContent = ExportService.generateCsvData(gastosMes);
    final mes = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;
    final fileName = 'gastos_${mes}_$anio.csv';

    await ExportService.exportAndShare(
      content: csvContent,
      filename: fileName,
      mimeType: 'text/csv',
    );
  }

  void _exportarMarkdown(BuildContext context) async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final gastosMes = gastoProvider.gastos;

    if (gastosMes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay gastos en este mes para exportar.')),
      );
      return;
    }

    final mes = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;
    final mdContent = ExportService.generateMarkdownReport(gastosMes, periodo: '$mes $anio');
    final fileName = 'reporte_${mes}_$anio.md';

    await ExportService.exportAndShare(
      content: mdContent,
      filename: fileName,
      mimeType: 'text/markdown',
    );
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final scanQueue = Provider.of<ScanQueueProvider>(context);
    final mesNombre = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rinde Más'),
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
                    Text('Exportar a Excel (.csv)', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'md',
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Exportar a Markdown (.md)', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await gastoProvider.cargarDatos();
          await scanQueue.processPendingItems();
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            if (scanQueue.readyItems.isNotEmpty)
              _buildQueueBanner(context, scanQueue),
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
              presupuesto: Provider.of<SettingsProvider>(context).presupuestoMensual,
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
                  onEdit: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewExpenseScreen(
                          existingGasto: gasto,
                        ),
                      ),
                    );
                  },
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

  Widget _buildQueueBanner(BuildContext context, ScanQueueProvider scanQueue) {
    return GestureDetector(
      onTap: () {
        // Al tocar, abrir el primero listo
        final item = scanQueue.readyItems.first;
        final data = jsonDecode(item['extracted_data']);
        final result = GeminiExtractionResult.fromMap(data);
        final file = File(item['image_path']);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReviewExpenseScreen(
              imageFile: file.existsSync() ? file : null,
              extractedData: result,
              queueItemId: item['id'], // Pasamos el ID para borrarlo luego
            ),
          ),
        ).then((_) {
          // Actualizar lista si canceló o guardó
          scanQueue.loadReadyItems();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppColors.primaryDark),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tienes ${scanQueue.readyItems.length} factura(s) en cola listas para revisar.',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primaryDark),
          ],
        ),
      ),
    );
  }
}
