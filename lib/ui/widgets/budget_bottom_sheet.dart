import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/amount_parser.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import 'category_chart.dart';

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
  late TextEditingController _savingsGoalCtrl;
  final Map<String, TextEditingController> _categoryControllers = {};
  String _selectedMoneda = 'USD';

  @override
  void initState() {
    super.initState();
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    _selectedMoneda = gastoProvider.monedaPresupuesto;
    final currentGeneral = gastoProvider.presupuestoGeneral;
    _generalBudgetCtrl = TextEditingController(
      text: currentGeneral > 0
          ? (currentGeneral % 1 == 0
              ? currentGeneral.toInt().toString()
              : currentGeneral.toStringAsFixed(2))
          : '',
    );
    _generalBudgetCtrl.addListener(_onFieldChanged);

    final currentMeta = gastoProvider.metaAhorro;
    _savingsGoalCtrl = TextEditingController(
      text: currentMeta > 0
          ? (currentMeta % 1 == 0
              ? currentMeta.toInt().toString()
              : currentMeta.toStringAsFixed(2))
          : '',
    );
    _savingsGoalCtrl.addListener(_onFieldChanged);

    for (final cat in AppConstants.categorias) {
      final currentBudget = gastoProvider.getPresupuestoCategoria(cat);
      final ctrl = TextEditingController(
        text: currentBudget > 0
            ? (currentBudget % 1 == 0
                ? currentBudget.toInt().toString()
                : currentBudget.toStringAsFixed(2))
            : '',
      );
      ctrl.addListener(_onFieldChanged);
      _categoryControllers[cat] = ctrl;
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  void _cambiarMoneda(
    String nuevaMoneda, {
    required double tasaUsd,
    required double tasaEur,
    required double tasaUsdt,
  }) {
    if (nuevaMoneda == _selectedMoneda) return;

    double toVes(double val, String moneda) {
      switch (moneda) {
        case 'VES':
          return val;
        case 'EUR':
          // Sin tasa EUR no se inventa ratio (antes: USD * 1.08 / 43.0):
          // aproximación con tasa USD, o passthrough si no hay dato.
          return val * (tasaEur > 0 ? tasaEur : (tasaUsd > 0 ? tasaUsd : 1.0));
        case 'USDT':
          return val * (tasaUsdt > 0 ? tasaUsdt : (tasaUsd > 0 ? tasaUsd : 1.0));
        case 'USD':
        default:
          return val * (tasaUsd > 0 ? tasaUsd : 1.0);
      }
    }

    double fromVes(double ves, String moneda) {
      switch (moneda) {
        case 'VES':
          return ves;
        case 'EUR':
          final r = tasaEur > 0 ? tasaEur : (tasaUsd > 0 ? tasaUsd : 0.0);
          return r > 0 ? ves / r : ves;
        case 'USDT':
          final r = tasaUsdt > 0 ? tasaUsdt : (tasaUsd > 0 ? tasaUsd : 0.0);
          return r > 0 ? ves / r : ves;
        case 'USD':
        default:
          final r = tasaUsd > 0 ? tasaUsd : 0.0;
          return r > 0 ? ves / r : ves;
      }
    }

    // Convertir presupuesto general
    final genVal = tryParseAmount(_generalBudgetCtrl.text, isPrice: false) ?? 0.0;
    if (genVal > 0) {
      final double ves = toVes(genVal, _selectedMoneda);
      final double nuevoGen = fromVes(ves, nuevaMoneda);
      _generalBudgetCtrl.text = nuevoGen >= 100
          ? nuevoGen.round().toString()
          : nuevoGen.toStringAsFixed(2);
    }

    // Convertir meta de ahorro
    final metaVal = tryParseAmount(_savingsGoalCtrl.text, isPrice: false) ?? 0.0;
    if (metaVal > 0) {
      final double ves = toVes(metaVal, _selectedMoneda);
      final double nuevoMeta = fromVes(ves, nuevaMoneda);
      _savingsGoalCtrl.text = nuevoMeta >= 100
          ? nuevoMeta.round().toString()
          : nuevoMeta.toStringAsFixed(2);
    }

    // Convertir categorías
    for (final ctrl in _categoryControllers.values) {
      final val = tryParseAmount(ctrl.text, isPrice: false) ?? 0.0;
      if (val > 0) {
        final double ves = toVes(val, _selectedMoneda);
        final double nuevoVal = fromVes(ves, nuevaMoneda);
        ctrl.text = nuevoVal >= 100
            ? nuevoVal.round().toString()
            : nuevoVal.toStringAsFixed(2);
      }
    }

    setState(() {
      _selectedMoneda = nuevaMoneda;
    });
  }

  @override
  void dispose() {
    _generalBudgetCtrl.removeListener(_onFieldChanged);
    _generalBudgetCtrl.dispose();
    _savingsGoalCtrl.removeListener(_onFieldChanged);
    _savingsGoalCtrl.dispose();
    for (final ctrl in _categoryControllers.values) {
      ctrl.removeListener(_onFieldChanged);
      ctrl.dispose();
    }
    super.dispose();
  }

  double get _montoGeneral {
    return tryParseAmount(_generalBudgetCtrl.text, isPrice: false) ?? 0.0;
  }

  double get _montoMetaAhorro {
    return tryParseAmount(_savingsGoalCtrl.text, isPrice: false) ?? 0.0;
  }

  double get _limiteParaGastar {
    final gen = _montoGeneral;
    final meta = _montoMetaAhorro;
    if (meta <= 0) return gen;
    return (gen - meta).clamp(0.0, double.infinity);
  }

  double get _sumaCategorias {
    double total = 0.0;
    for (final ctrl in _categoryControllers.values) {
      final val = tryParseAmount(ctrl.text, isPrice: false) ?? 0.0;
      if (val > 0) total += val;
    }
    return total;
  }

  bool get _isMetaExceeded {
    final gen = _montoGeneral;
    final meta = _montoMetaAhorro;
    return gen > 0 && meta > gen;
  }

  bool get _isCategoriesExceeded {
    final gen = _montoGeneral;
    if (gen <= 0) return false;
    final limite = _limiteParaGastar;
    return _sumaCategorias > limite;
  }

  bool get _isExceeded => _isMetaExceeded || _isCategoriesExceeded;

  /// true si algún campo tiene texto no vacío que no es un monto válido
  /// (ej. "1.234,56" mal formado o letras). Evita guardar 0 en silencio.
  bool get _hasInvalidAmount {
    if (_generalBudgetCtrl.text.trim().isNotEmpty &&
        tryParseAmount(_generalBudgetCtrl.text, isPrice: false) == null) {
      return true;
    }
    if (_savingsGoalCtrl.text.trim().isNotEmpty &&
        tryParseAmount(_savingsGoalCtrl.text, isPrice: false) == null) {
      return true;
    }
    for (final ctrl in _categoryControllers.values) {
      if (ctrl.text.trim().isNotEmpty &&
          tryParseAmount(ctrl.text, isPrice: false) == null) {
        return true;
      }
    }
    return false;
  }

  Future<void> _guardar() async {
    if (_hasInvalidAmount) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hay montos no válidos. Revisa los campos antes de guardar.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_isMetaExceeded) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La meta de ahorro no puede superar el presupuesto general.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_isCategoriesExceeded) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La suma de las categorías supera el límite para gastar.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    final Map<String, double> categoriasMap = {};
    for (final entry in _categoryControllers.entries) {
      final val = tryParseAmount(entry.value.text, isPrice: false) ?? 0.0;
      if (val > 0) {
        categoriasMap[entry.key] = val;
      }
    }

    final success = await gastoProvider.guardarTodoElPresupuesto(
      _montoGeneral,
      categoriasMap,
      moneda: _selectedMoneda,
      metaAhorro: _montoMetaAhorro,
    );

    if (mounted) {
      if (success) {
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              gastoProvider.errorMessage ?? 'Error al guardar los presupuestos',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final mesNombre = DateFormatter.obtenerNombreMes(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    final gen = _montoGeneral;
    final meta = _montoMetaAhorro;
    final limite = _limiteParaGastar;
    final suma = _sumaCategorias;
    final disponible = limite - suma;
    final bool metaExceeded = _isMetaExceeded;
    final bool categoriesExceeded = _isCategoriesExceeded;
    final bool exceeded = _isExceeded;
    final prefix = () {
      switch (_selectedMoneda) {
        case 'VES':
          return 'Bs. ';
        case 'EUR':
          return '€ ';
        case 'USDT':
          return 'USDT ';
        case 'USD':
        default:
          return '\$ ';
      }
    }();

    String fmt(double monto) => CurrencyFormatter.formatAmount(monto, _selectedMoneda);

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
                        fontSize: 16,
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
            const SizedBox(height: 6),

            // Selector de Moneda (USD / VES)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Moneda del presupuesto:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardLighter,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final m in ['USD', 'VES', 'EUR', 'USDT'])
                        InkWell(
                          key: Key('budget_currency_${m.toLowerCase()}_btn'),
                          onTap: () => _cambiarMoneda(
                            m,
                            tasaUsd: settings.tasaCambioVesUsd,
                            tasaEur: settings.tasaCambioVesEur,
                            tasaUsdt: settings.tasaCambioVesUsdt,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _selectedMoneda == m ? AppColors.surface : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: _selectedMoneda == m
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            child: Text(
                              m,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: _selectedMoneda == m ? FontWeight.bold : FontWeight.normal,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                children: [
                  // Sección 1: Presupuesto General y Meta de Ahorro
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
                        Text(
                          'Presupuesto General Mensual ($_selectedMoneda)',
                          style: const TextStyle(
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
                            prefixText: prefix,
                            hintText: '0.00',
                            filled: true,
                            fillColor: AppColors.cardLighter,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.savings_outlined, size: 16, color: AppColors.primaryDark),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Meta de Ahorro / Inversión ($_selectedMoneda) (Opcional)',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          key: const Key('input_meta_ahorro'),
                          controller: _savingsGoalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            prefixText: prefix,
                            hintText: '0.00',
                            filled: true,
                            fillColor: AppColors.cardLighter,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (meta > 0 && gen > 0 && !metaExceeded) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.cardLighter,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Límite para gastar:',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  fmt(limite),
                                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (gen > 0) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (limite > 0 ? (suma / limite) : 1.0).clamp(0.0, 1.0),
                              backgroundColor: AppColors.border,
                              color: categoriesExceeded ? AppColors.error : AppColors.primaryDark,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                meta > 0 ? 'Asignado a categorías: ${fmt(suma)}' : 'Asignado: ${fmt(suma)}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                              Text(
                                categoriesExceeded
                                    ? 'Exceso: ${fmt(suma - limite)}'
                                    : 'Disponible: ${fmt(disponible)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: categoriesExceeded ? AppColors.error : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (metaExceeded) ...[
                          const SizedBox(height: 10),
                          Container(
                            key: const Key('alert_meta_ahorro_excedida'),
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
                                    'La meta de ahorro (${fmt(meta)}) no puede superar el presupuesto general (${fmt(gen)}).',
                                    style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (categoriesExceeded) ...[
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
                                    meta > 0
                                        ? 'La suma de categorías (${fmt(suma)}) supera el límite para gastar (${fmt(limite)}). Ajusta los montos.'
                                        : 'La suma de categorías (${fmt(suma)}) supera el presupuesto general (${fmt(gen)}). Ajusta los montos.',
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
                  Text(
                    'Define un límite para cada categoría. Las que dejes vacías o en 0 no se mostrarán.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              CategoryChart.getCategoryIcon(cat),
                              size: 14,
                              color: color,
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
                            width: 110,
                            child: TextField(
                              key: Key('input_presupuesto_categoria_$cat'),
                              controller: ctrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixText: prefix,
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
