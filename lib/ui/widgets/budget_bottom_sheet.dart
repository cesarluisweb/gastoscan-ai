import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';

class BudgetBottomSheet extends StatefulWidget {
  const BudgetBottomSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const BudgetBottomSheet(),
    );
  }

  @override
  State<BudgetBottomSheet> createState() => _BudgetBottomSheetState();
}

class _BudgetBottomSheetState extends State<BudgetBottomSheet> {
  late TextEditingController _generalBudgetCtrl;
  bool _isEditingGeneral = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final currentGeneral = settings.presupuestoMensual;
    _generalBudgetCtrl = TextEditingController(
      text: currentGeneral > 0 ? currentGeneral.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _generalBudgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarPresupuestoGeneral() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final val = double.tryParse(_generalBudgetCtrl.text.replaceAll(',', '.')) ?? 0.0;
    await settings.setPresupuestoMensual(val >= 0 ? val : 0.0);
    if (mounted) {
      setState(() {
        _isEditingGeneral = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Presupuesto general actualizado', style: TextStyle(color: Colors.black)),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _mostrarDialogoEditarCategoria({String? categoriaInicial, double? montoInicial}) {
    String selectedCat = categoriaInicial ?? AppConstants.categorias.first;
    final ctrl = TextEditingController(
      text: (montoInicial != null && montoInicial > 0) ? montoInicial.toStringAsFixed(0) : '',
    );

    showDialog(
      context: context,
      builder: (dCtx) {
        final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
        final esEdicion = categoriaInicial != null;

        return StatefulBuilder(
          builder: (context, setDState) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                esEdicion ? 'Presupuesto: $categoriaInicial' : 'Asignar Presupuesto',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!esEdicion) ...[
                    const Text('Categoría:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCat,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.cardLighter,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      dropdownColor: AppColors.card,
                      items: AppConstants.categorias.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(color: AppColors.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setDState(() => selectedCat = val);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text('Límite Mensual (USD):', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('input_presupuesto_monto'),
                    controller: ctrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      hintText: 'ej. 100',
                      filled: true,
                      fillColor: AppColors.cardLighter,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                if (esEdicion)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                    label: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                    onPressed: () async {
                      await gastoProvider.eliminarPresupuestoCategoria(categoriaInicial);
                      if (dCtx.mounted) Navigator.pop(dCtx);
                    },
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(dCtx),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  key: const Key('btn_guardar_presupuesto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final cat = selectedCat;
                    final amount = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
                    if (amount > 0) {
                      await gastoProvider.setPresupuestoCategoria(cat, amount);
                    } else {
                      await gastoProvider.eliminarPresupuestoCategoria(cat);
                    }
                    if (dCtx.mounted) Navigator.pop(dCtx);
                  },
                  child: const Text('Guardar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final gastoProvider = Provider.of<GastoProvider>(context);

    final generalBudget = settings.presupuestoMensual;
    final catBudgets = gastoProvider.presupuestosPorCategoria;
    final activeBudgets = catBudgets.entries.where((e) => e.value > 0).toList();

    double totalAsignado = 0.0;
    for (var entry in activeBudgets) {
      totalAsignado += entry.value;
    }

    final disponible = generalBudget - totalAsignado;
    final isExceeded = generalBudget > 0 && totalAsignado > generalBudget;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryDark),
                      SizedBox(width: 8),
                      Text(
                        'Gestión de Presupuestos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppColors.border),
              const SizedBox(height: 12),

              // Sección 1: Presupuesto General
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Presupuesto General Mensual',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (!_isEditingGeneral)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryDark),
                            onPressed: () {
                              setState(() {
                                _isEditingGeneral = true;
                              });
                            },
                          ),
                      ],
                    ),
                    if (_isEditingGeneral) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _generalBudgetCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '\$ ',
                                hintText: '0.00',
                                filled: true,
                                fillColor: AppColors.cardLighter,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onPressed: _guardarPresupuestoGeneral,
                            child: const Text('Guardar', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        generalBudget > 0
                            ? CurrencyFormatter.formatUsd(generalBudget)
                            : 'Sin definir (Toca editar para asignar)',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: generalBudget > 0 ? AppColors.textPrimary : AppColors.textMuted,
                        ),
                      ),
                    ],

                    // Resumen de asignación
                    if (generalBudget > 0) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (totalAsignado / generalBudget).clamp(0.0, 1.0),
                          backgroundColor: AppColors.border,
                          color: isExceeded ? AppColors.error : AppColors.primaryDark,
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Asignado a categorías: ${CurrencyFormatter.formatUsd(totalAsignado)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          Text(
                            isExceeded
                                ? 'Exceso: ${CurrencyFormatter.formatUsd(totalAsignado - generalBudget)}'
                                : 'Disponible: ${CurrencyFormatter.formatUsd(disponible)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isExceeded ? AppColors.error : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Sección 2: Presupuestos por Categoría
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Presupuestos por Categoría',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const Key('btn_asignar_categoria_bottom_sheet'),
                    icon: const Icon(Icons.add, size: 16, color: AppColors.primaryDark),
                    label: const Text('Asignar Categoría', style: TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                    onPressed: () => _mostrarDialogoEditarCategoria(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (activeBudgets.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.category_outlined, color: AppColors.textMuted, size: 36),
                      SizedBox(height: 8),
                      Text(
                        'No tienes presupuestos por categoría activos.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeBudgets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = activeBudgets[index];
                    final catName = item.key;
                    final catBudget = item.value;
                    final spent = gastoProvider.getSpentForCategory(catName);

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: AppColors.primary.withOpacity(0.2),
                            child: const Icon(Icons.label_outline, size: 16, color: AppColors.primaryDark),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  catName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Gastado: ${CurrencyFormatter.formatUsd(spent)} de ${CurrencyFormatter.formatUsd(catBudget)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: Key('edit_budget_$catName'),
                            icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                            onPressed: () => _mostrarDialogoEditarCategoria(
                              categoriaInicial: catName,
                              montoInicial: catBudget,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                            onPressed: () async {
                              await gastoProvider.eliminarPresupuestoCategoria(catName);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Presupuesto de "$catName" eliminado', style: const TextStyle(color: Colors.black)),
                                    backgroundColor: AppColors.primary,
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
