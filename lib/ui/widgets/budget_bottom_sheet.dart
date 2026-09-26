import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';

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
  final Map<String, TextEditingController> _categoryControllers = {};

  @override
  void initState() {
    super.initState();
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final currentGeneral = gastoProvider.presupuestoGeneral;
    _generalBudgetCtrl = TextEditingController(
      text: currentGeneral > 0 ? currentGeneral.toStringAsFixed(0) : '',
    );
    _generalBudgetCtrl.addListener(_onFieldChanged);

    for (final cat in AppConstants.categorias) {
      final currentBudget = gastoProvider.getPresupuestoCategoria(cat);
      final ctrl = TextEditingController(
        text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '',
      );
      ctrl.addListener(_onFieldChanged);
      _categoryControllers[cat] = ctrl;
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _generalBudgetCtrl.removeListener(_onFieldChanged);
    _generalBudgetCtrl.dispose();
    for (final ctrl in _categoryControllers.values) {
      ctrl.removeListener(_onFieldChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  double get _montoGeneral {
    return double.tryParse(_generalBudgetCtrl.text.replaceAll(',', '.')) ?? 0.0;
  }

  double get _sumaCategorias {
    double total = 0.0;
    for (final ctrl in _categoryControllers.values) {
      final val = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
      if (val > 0) total += val;
    }
    return total;
  }

  bool get _isExceeded {
    final gen = _montoGeneral;
    return gen > 0 && _sumaCategorias > gen;
  }

  Future<void> _guardar() async {
    if (_isExceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La suma de las categorías supera el presupuesto general.',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final Map<String, double> categoriasMap = {};
    for (final entry in _categoryControllers.entries) {
      final val = double.tryParse(entry.value.text.replaceAll(',', '.')) ?? 0.0;
      if (val > 0) {
        categoriasMap[entry.key] = val;
      }
    }

    await gastoProvider.guardarTodoElPresupuesto(_montoGeneral, categoriasMap);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Presupuestos actualizados correctamente',
            style: TextStyle(color: Colors.black),
          ),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final mesNombre = DateFormatter.obtenerNombreMes(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    final gen = _montoGeneral;
    final suma = _sumaCategorias;
    final disponible = gen - suma;
    final bool exceeded = _isExceeded;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Text(
                      'Presupuestos ($mesNombre $anio)',
                      style: const TextStyle(
                        fontSize: 17,
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
            const SizedBox(height: 8),

            Expanded(
              child: ListView(
                children: [
                  // Sección 1: Presupuesto General
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Presupuesto General Mensual (USD)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('input_presupuesto_general'),
                          controller: _generalBudgetCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            hintText: '0.00',
                            filled: true,
                            fillColor: AppColors.cardLighter,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (gen > 0) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (suma / gen).clamp(0.0, 1.0),
                              backgroundColor: AppColors.border,
                              color: exceeded ? AppColors.error : AppColors.primaryDark,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Asignado: ${CurrencyFormatter.formatUsd(suma)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                exceeded
                                    ? 'Exceso: ${CurrencyFormatter.formatUsd(suma - gen)}'
                                    : 'Disponible: ${CurrencyFormatter.formatUsd(disponible)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: exceeded ? AppColors.error : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (exceeded) ...[
                          const SizedBox(height: 10),
                          Container(
                            key: const Key('alert_presupuesto_excedido'),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.error),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'La suma de categorías (${CurrencyFormatter.formatUsd(suma)}) supera el presupuesto general (${CurrencyFormatter.formatUsd(gen)}). Ajusta los montos.',
                                    style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Sección 2: Presupuestos por Categoría
                  const Text(
                    'Presupuestos por Categoría (Opcional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Define un límite para cada categoría. Las que dejes vacías o en \$0 no se mostrarán.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 10),

                  ...AppConstants.categorias.map((cat) {
                    final color = AppColors.categoryColors[cat] ?? AppColors.primary;
                    final ctrl = _categoryControllers[cat]!;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              cat,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              key: Key('input_presupuesto_categoria_$cat'),
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: '\$ ',
                                hintText: '0',
                                filled: true,
                                fillColor: AppColors.cardLighter,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Botón Guardar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const Key('btn_guardar_presupuestos_all'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: exceeded ? AppColors.textMuted : AppColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: exceeded ? null : _guardar,
                child: const Text(
                  'Guardar Presupuestos',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
