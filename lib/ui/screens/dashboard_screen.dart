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
import '../widgets/budget_bottom_sheet.dart';
import '../widgets/ai_insight_card.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'review_expense_screen.dart';
import 'chat_screen.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/gemini_extraction_result.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToGastos;
  final VoidCallback? onNavigateToAnalysis;
  final VoidCallback? onNavigateToChat;

  const DashboardScreen({
    Key? key,
    this.onNavigateToGastos,
    this.onNavigateToAnalysis,
    this.onNavigateToChat,
  }) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Registrar actividad del usuario y reprogramar recordatorio de inactividad a 3 días
    NotificationService.instance.recordActivityAndReschedule();
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final scanQueue = Provider.of<ScanQueueProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final mesNombre = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rinde Más'),
        actions: [
          IconButton(
            key: const Key('dashboard_ai_chat_button'),
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Asistente IA',
            onPressed: () {
              if (widget.onNavigateToChat != null) {
                widget.onNavigateToChat!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ChatScreen(showBackButton: true),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await gastoProvider.sincronizarConFirestore();
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
                InkWell(
                  key: const Key('month_selector_title'),
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
            const SizedBox(height: 8),
            SummaryCard(
              totalUsd: gastoProvider.totalMesUsd,
              totalVes: gastoProvider.totalMesVes,
              periodo: '$mesNombre $anio',
              monedaPrincipal: settings.monedaPrincipal,
              tasaCambio: settings.tasaCambioVesUsd,
              presupuestoGeneral: gastoProvider.presupuestoGeneral,
              mes: gastoProvider.selectedMonth,
              anio: gastoProvider.selectedYear,
            ),
            const SizedBox(height: 16),
            AiInsightCard(
              gastos: gastoProvider.gastos,
              presupuestoGeneral: gastoProvider.presupuestoGeneral,
              totalesPorCategoria: gastoProvider.totalesPorCategoria,
              totalGastadoMes: gastoProvider.totalMesUsd,
              monedaPrincipal: settings.monedaPrincipal,
              tasaCambio: settings.tasaCambioVesUsd,
              onChatTap: widget.onNavigateToChat,
            ),
            const SizedBox(height: 16),
            if (gastoProvider.totalesPorCategoria.isNotEmpty ||
                gastoProvider.presupuestosPorCategoria.isNotEmpty ||
                gastoProvider.presupuestoGeneral > 0) ...[
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
                showBudgetBars: false,
                onNavigateToAnalysis: widget.onNavigateToAnalysis,
              ),
              const SizedBox(height: 16),
            ] else ...[
              _buildCategoryChartSilhouette(),
              const SizedBox(height: 16),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gastos realizados',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (gastoProvider.gastos.length > 5 && widget.onNavigateToGastos != null)
                    InkWell(
                      onTap: widget.onNavigateToGastos,
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ver todos',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.secondary),
                          ],
                        ),
                      ),
                    ),
                ],
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
              final displayedGastos = gastoProvider.gastos.take(5).toList();

              final cards = displayedGastos.map<Widget>((gasto) {
                return ExpenseCard(
                  key: ValueKey(gasto.id ?? gasto.comercio),
                  gasto: gasto,
                  monedaPrincipal: settings.monedaPrincipal,
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

              if (gastoProvider.gastos.length > 5 && widget.onNavigateToGastos != null) {
                cards.add(
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      key: const Key('btn_ver_todos_los_gastos'),
                      onPressed: widget.onNavigateToGastos,
                      icon: const Icon(Icons.receipt_long, size: 18),
                      label: Text(
                        'Ver todos los gastos (${gastoProvider.gastos.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                );
              }

              return cards;
            }(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            'Sin facturas este mes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Presiona "+" para registrar tu primera compra.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }



  Widget _buildProcessingBanner(BuildContext context, ScanQueueProvider scanQueue) {
    final count = scanQueue.pendingCount > 0 ? scanQueue.pendingCount : 1;
    final itemText = count == 1 ? 'factura' : 'facturas';
    final isProcessing = scanQueue.isProcessing;

    return Container(
      key: const Key('processing_queue_banner'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isProcessing ? AppColors.primaryLight : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isProcessing ? AppColors.primary : AppColors.warning),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: isProcessing 
              ? const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.secondary),
                )
              : const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isProcessing ? 'Procesando $count $itemText en cola...' : 'Pausado: $count $itemText',
                  style: TextStyle(
                    color: isProcessing ? AppColors.secondary : AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isProcessing
                      ? 'Extrayendo datos en segundo plano'
                      : (scanQueue.lastError ?? 'Fallo al procesar. Toca reintentar.'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isProcessing)
            TextButton(
              onPressed: () async {
                await scanQueue.cancelProcessing();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Descartar',
                  onPressed: () async {
                    await scanQueue.cancelProcessing();
                  },
                ),
                TextButton(
                  onPressed: () async {
                    await scanQueue.processPendingItems();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.cardLighter,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.pie_chart_outline_rounded,
              size: 24,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Distribución por Categorías',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Al registrar compras, verás aquí la distribución de tus gastos por rubro.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ],
            ),
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
                      key: Key('month_pick_${mesNum}'),
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

  void _mostrarDialogoPresupuesto(
    BuildContext context,
    GastoProvider gastoProvider, {
    String? categoriaInicial,
    double? montoInicial,
  }) {
    String selectedCategory = categoriaInicial ?? AppConstants.categorias.first;
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
                      DropdownButtonFormField<String>(
                        value: selectedCategory,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.cardLighter,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                        dropdownColor: AppColors.card,
                        items: AppConstants.categorias.map((String cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: Text(cat, style: const TextStyle(color: AppColors.textPrimary)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setStateDialog(() {
                              selectedCategory = newValue;
                            });
                          }
                        },
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
                    final catName = selectedCategory;
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
