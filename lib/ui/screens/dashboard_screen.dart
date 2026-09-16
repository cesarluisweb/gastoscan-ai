import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scan_queue_provider.dart';
import 'dart:io';
import 'dart:convert';
import '../../services/export_service.dart';
import '../../services/notification_service.dart';
import '../widgets/summary_card.dart';
import '../widgets/category_chart.dart';
import '../widgets/expense_card.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'review_expense_screen.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/gemini_extraction_result.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Registrar actividad del usuario y reprogramar recordatorio de inactividad a 3 días
    NotificationService.instance.recordActivityAndReschedule();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

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
        title: _isSearching
            ? TextField(
                key: const Key('dashboard_search_field'),
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Buscar por comercio o producto...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                onSubmitted: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text('Rinde Más'),
        actions: [
          IconButton(
            key: const Key('dashboard_search_toggle_button'),
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchCtrl.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: 'Exportar Reportes',
              color: AppColors.surface,
              onSelected: (val) {
                if (val == 'category_budget') _mostrarDialogoPresupuesto(context, gastoProvider);
                if (val == 'csv') _exportarCsv(context);
                if (val == 'md') _exportarMarkdown(context);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'category_budget',
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Presupuesto por Categoría', style: TextStyle(color: AppColors.textPrimary)),
                    ],
                  ),
                ),
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
                      Icon(Icons.text_snippet_outlined, color: AppColors.primary, size: 18),
                      SizedBox(width: 8),
                      Text('Exportar como Texto', style: TextStyle(color: AppColors.textPrimary)),
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
          await scanQueue.loadReadyItems();
          await scanQueue.loadPendingItems();
          await scanQueue.processPendingItems();
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            if (scanQueue.isProcessing || scanQueue.pendingItems.isNotEmpty)
              _buildProcessingBanner(context, scanQueue),
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
            if (gastoProvider.totalesPorCategoria.isNotEmpty ||
                gastoProvider.presupuestosPorCategoria.isNotEmpty) ...[
              CategoryChart(
                categoryTotals: gastoProvider.totalesPorCategoria,
                categoryBudgets: gastoProvider.presupuestosPorCategoria,
                onSetBudget: (categoria, budget) async {
                  await gastoProvider.setPresupuestoCategoria(categoria, budget);
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              _buildCategoryChartSilhouette(),
              const SizedBox(height: 16),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Facturas Registradas',
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
            else ...() {
              final query = _normalizeText(_searchQuery.trim());
              final filteredGastos = gastoProvider.gastos.where((gasto) {
                if (query.isEmpty) return true;
                final matchComercio = _normalizeText(gasto.comercio).contains(query);
                final matchItems = gasto.items.any((item) => _normalizeText(item.descripcion).contains(query));
                return matchComercio || matchItems;
              }).toList();

              if (filteredGastos.isEmpty) {
                return [_buildEmptySearchState()];
              }

              return filteredGastos.map((gasto) {
                return ExpenseCard(
                  key: ValueKey(gasto.id ?? gasto.comercio),
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
                        title: const Text('Eliminar Factura', style: TextStyle(color: AppColors.textPrimary)),
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
              }).toList();
            }(),
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
            'Sin facturas este mes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Presiona "+" para registrar tu primera compra.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Container(
      key: const Key('empty_search_state'),
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          const Text(
            'No se encontraron gastos',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.trim().isNotEmpty
                ? 'No hay resultados para "${_searchQuery.trim()}". Intenta con otro término.'
                : 'No se encontraron gastos que coincidan con la búsqueda.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingBanner(BuildContext context, ScanQueueProvider scanQueue) {
    final count = scanQueue.pendingCount > 0 ? scanQueue.pendingCount : 1;
    final itemText = count == 1 ? 'factura' : 'facturas';

    return Container(
      key: const Key('processing_queue_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Procesando $count $itemText en cola...',
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Extrayendo datos de facturas en segundo plano',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueBanner(BuildContext context, ScanQueueProvider scanQueue) {
    return GestureDetector(
      key: const Key('ready_queue_banner'),
      onTap: () {
        // Al tocar, abrir el primero listo
        final item = scanQueue.readyItems.first;
        final data = jsonDecode(item['extracted_data']);
        final result = GeminiExtractionResult.fromJson(data);
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

  Widget _buildCategoryChartSilhouette() {
    return Container(
      key: const Key('category_chart_silhouette'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribución por Categorías',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: 1.0,
                        strokeWidth: 14,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.border.withOpacity(0.6),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 32,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tus estadísticas',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Al registrar compras, verás aquí la distribución de tus gastos por rubro.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoPresupuesto(
    BuildContext context,
    GastoProvider gastoProvider, {
    String? categoriaInicial,
    double? montoInicial,
  }) {
    final catCtrl = TextEditingController(text: categoriaInicial ?? '');
    final montoCtrl = TextEditingController(
      text: (montoInicial != null && montoInicial > 0) ? montoInicial.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (dContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                categoriaInicial != null ? 'Presupuesto: $categoriaInicial' : 'Definir Presupuesto',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categoriaInicial == null) ...[
                      const Text('Categoría:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        key: const Key('input_categoria_nombre'),
                        controller: catCtrl,
                        decoration: InputDecoration(
                          hintText: 'Ej. Comida, Alimentación, Salud...',
                          filled: true,
                          fillColor: AppColors.cardLighter,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: AppConstants.categorias.take(4).map((c) {
                          return ActionChip(
                            label: Text(c, style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              catCtrl.text = c;
                              setStateDialog(() {});
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const Text('Límite mensual (USD):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      key: const Key('input_presupuesto_monto'),
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixText: '\$ ',
                        hintText: '50.00',
                        filled: true,
                        fillColor: AppColors.cardLighter,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dContext).pop(),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  key: const Key('btn_guardar_presupuesto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.secondary,
                  ),
                  onPressed: () async {
                    final catName = (categoriaInicial ?? catCtrl.text).trim();
                    final amount = double.tryParse(montoCtrl.text.replaceAll(',', '.')) ?? 0.0;
                    if (catName.isNotEmpty && amount >= 0) {
                      await gastoProvider.setPresupuestoCategoria(catName, amount);
                      Navigator.of(dContext).pop();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
