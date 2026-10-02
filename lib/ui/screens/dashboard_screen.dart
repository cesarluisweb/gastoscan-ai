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
import '../widgets/pending_expense_card.dart';
import '../widgets/budget_bottom_sheet.dart';
import '../widgets/ai_insight_card.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'review_expense_screen.dart';
import 'chat_screen.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../services/update_service.dart';
import '../widgets/update_dialog.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onNavigateToGastos;
  final VoidCallback? onNavigateToAnalysis;
  final VoidCallback? onNavigateToChat;
  final VoidCallback? onAddExpense;

  const DashboardScreen({
    Key? key,
    this.onNavigateToGastos,
    this.onNavigateToAnalysis,
    this.onNavigateToChat,
    this.onAddExpense,
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

    // Verificación silenciosa de actualización con throttling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verificarActualizacionSilenciosa();
    });
  }

  Future<void> _verificarActualizacionSilenciosa() async {
    try {
      final updateService = UpdateService();
      final updateInfo = await updateService.checkForUpdate(force: false);
      if (mounted && updateInfo != null && updateInfo.hasUpdate) {
        UpdateDialog.show(context, updateInfo);
      }
    } catch (_) {}
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Rinde Más',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const Key('dashboard_ai_chat_button'),
            icon: SizedBox(
              width: 24,
              height: 24,
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  Icon(Icons.chat_bubble_outline, size: 22, color: AppColors.textPrimary),
                  Padding(
                    padding: EdgeInsets.only(bottom: 2),
                    child: Text(
                      '?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
            // Selector de mes con botón píldora central y flechas laterales sueltas
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 22),
                    visualDensity: VisualDensity.compact,
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
                  InkWell(
                    key: const Key('month_selector_title'),
                    onTap: () => _mostrarPickerMes(context, gastoProvider),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.cardLighter,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$mesNombre $anio',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.keyboard_arrow_down,
                            color: AppColors.textSecondary,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 22),
                    visualDensity: VisualDensity.compact,
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
            ),
            const SizedBox(height: 8),
            SummaryCard(
              totalUsd: gastoProvider.totalMesUsd,
              totalVes: gastoProvider.totalMesVes,
              periodo: '$mesNombre $anio',
              monedaPrincipal: settings.monedaPrincipal,
              tasaCambio: settings.tasaCambioVesUsd,
              presupuestoGeneral: gastoProvider.presupuestoGeneral,
              metaAhorro: gastoProvider.metaAhorro,
              monedaPresupuesto: gastoProvider.monedaPresupuesto,
              mes: gastoProvider.selectedMonth,
              anio: gastoProvider.selectedYear,
            ),
            const SizedBox(height: 16),
            AiInsightCard(
              gastos: gastoProvider.gastos,
              presupuestoGeneral: gastoProvider.presupuestoGeneral,
              metaAhorro: gastoProvider.metaAhorro,
              totalesPorCategoria: gastoProvider.totalesPorCategoria,
              totalGastadoMes: gastoProvider.totalMesUsd,
              monedaPrincipal: settings.monedaPrincipal,
              monedaPresupuesto: gastoProvider.monedaPresupuesto,
              tasaCambio: settings.tasaCambioVesUsd,
              onChatTap: widget.onNavigateToChat,
            ),
            const SizedBox(height: 16),
            if (gastoProvider.totalesPorCategoria.isNotEmpty ||
                gastoProvider.presupuestosPorCategoria.isNotEmpty) ...[
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
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Gastos recientes',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (gastoProvider.gastos.length > 5 && widget.onNavigateToGastos != null)
                    InkWell(
                      onTap: widget.onNavigateToGastos,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cardLighter,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Ver todos',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, size: 11, color: AppColors.textPrimary),
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
            else if (gastoProvider.gastos.isEmpty && scanQueue.readyItems.isEmpty)
              _buildEmptyState()
            else ...() {
              final List<Widget> cards = [];

              for (final item in scanQueue.readyItems) {
                Map<String, dynamic> data = {};
                if (item['extracted_data'] != null) {
                  data = Map<String, dynamic>.from(jsonDecode(item['extracted_data']));
                }
                final result = GeminiExtractionResult.fromJson(data);
                final file = File(item['image_path']);
                
                final double totalOrig = result.totalOriginal;
                final double tasa = (result.tasaCambioDetectada != null && result.tasaCambioDetectada! > 0)
                    ? result.tasaCambioDetectada!
                    : 1.0;
                final double totalUsd = (result.moneda == 'USD')
                    ? totalOrig
                    : (tasa > 0 ? totalOrig / tasa : 0.0);

                final dummyGasto = GastoModel(
                  uuid: 'pending_${item['id']}',
                  fecha: result.fecha ?? DateTime.now().toIso8601String().substring(0, 10),
                  comercio: result.comercio ?? 'Comercio Desconocido',
                  moneda: result.moneda ?? 'VES',
                  totalOriginal: (totalOrig * 100).round(),
                  totalUsd: (totalUsd * 100).round(),
                  tasaCambio: tasa,
                  categoria: 'Pendiente',
                  creadoEn: DateTime.now().toIso8601String(),
                  items: result.items,
                );

                cards.add(
                  PendingExpenseCard(
                    key: ValueKey('pending_${item['id']}'),
                    gasto: dummyGasto,
                    monedaPrincipal: settings.monedaPrincipal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewExpenseScreen(
                            imageFile: file.existsSync() ? file : null,
                            extractedData: result,
                            queueItemId: item['id'],
                          ),
                        ),
                      ).then((_) {
                        scanQueue.loadReadyItems();
                      });
                    },
                  ),
                );
              }

              final displayedGastos = gastoProvider.gastos.take(5).toList();

              cards.addAll(displayedGastos.map<Widget>((gasto) {
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
              }));

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
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 8),
          const Text(
            'Sin gastos este mes',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Registra tu primera compra para crear tu historial.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          if (widget.onAddExpense != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('empty_state_add_expense_btn'),
                onPressed: widget.onAddExpense,
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'Agregar gasto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
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
