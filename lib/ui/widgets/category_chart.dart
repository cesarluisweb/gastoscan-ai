import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';

import '../../data/models/gasto_model.dart';
import '../../core/utils/date_formatter.dart';
import 'budget_bottom_sheet.dart';

class CategoryChart extends StatefulWidget {
  final Map<String, double> categoryTotals;
  final Map<String, double> categoryBudgets;
  final double presupuestoGeneral;
  final double totalGastadoMes;
  final List<GastoModel> gastosMes;
  final void Function(String categoria, double budget)? onSetBudget;
  final String monedaPrincipal;
  final double tasaCambio;
  final bool showBudgetBars;
  final VoidCallback? onNavigateToAnalysis;

  const CategoryChart({
    Key? key,
    required this.categoryTotals,
    this.categoryBudgets = const {},
    this.presupuestoGeneral = 0.0,
    this.totalGastadoMes = 0.0,
    this.gastosMes = const [],
    this.onSetBudget,
    this.monedaPrincipal = 'USD',
    this.tasaCambio = 1.0,
    this.showBudgetBars = true,
    this.onNavigateToAnalysis,
  }) : super(key: key);

  static IconData getCategoryIcon(String cat) {
    switch (cat) {
      case 'Alimentación':
        return Icons.restaurant;
      case 'Educación':
        return Icons.school_outlined;
      case 'Salud':
        return Icons.favorite_border;
      case 'Hogar':
        return Icons.home_outlined;
      case 'Higiene':
        return Icons.clean_hands_outlined;
      case 'Servicios':
        return Icons.bolt;
      case 'Transporte':
        return Icons.directions_car_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  @override
  State<CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<CategoryChart> {
  String? _expandedCategory;

  String _fmt(double amount) {
    return CurrencyFormatter.formatAmount(amount, widget.monedaPrincipal);
  }

  @override
  Widget build(BuildContext context) {
    // Si no hay totales ni presupuestos configurados, no renderizar nada
    if (widget.categoryTotals.isEmpty && widget.categoryBudgets.isEmpty && widget.presupuestoGeneral <= 0) {
      return const SizedBox.shrink();
    }

    final double totalSuma =
        widget.categoryTotals.values.fold(0.0, (prev, elem) => prev + elem);

    // Preparar secciones del gráfico circular
    final List<PieChartSectionData> sections = [];
    if (totalSuma > 0) {
      widget.categoryTotals.forEach((cat, monto) {
        if (monto <= 0) return;
        final color = AppColors.categoryColors[cat] ?? AppColors.textSecondary;
        final porcentaje = (monto / totalSuma) * 100;

        sections.add(
          PieChartSectionData(
            color: color,
            value: monto,
            title: porcentaje >= 8 ? '${porcentaje.toStringAsFixed(0)}%' : '',
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      });
    }

    // Obtener lista consolidada y ordenada de TODAS las categorías estándar
    final Set<String> allCategoryKeys = {
      ...AppConstants.categorias,
      ...widget.categoryTotals.keys,
      ...widget.categoryBudgets.keys,
    };
    final List<String> sortedCategories = allCategoryKeys.toList()
      ..sort((a, b) {
        final spentA = _getSpent(a);
        final spentB = _getSpent(b);
        if (spentB != spentA) {
          return spentB.compareTo(spentA);
        }
        return a.compareTo(b);
      });

    final IconData Function(String) getCategoryIcon = CategoryChart.getCategoryIcon;

    // Filtrar y ordenar categorías con consumo
    final entriesWithSpend = widget.categoryTotals.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Si estamos en la vista de Dashboard (!showBudgetBars), mostrar top 5 y consolidar 'Otros'
    final List<MapEntry<String, double>> displayedEntries = [];
    if (!widget.showBudgetBars && entriesWithSpend.length > 5) {
      final nonOtherEntries = entriesWithSpend.where((e) => e.key != 'Otros').toList();
      final otherOriginal = entriesWithSpend.firstWhere(
        (e) => e.key == 'Otros',
        orElse: () => const MapEntry('Otros', 0.0),
      );

      final top4NonOther = nonOtherEntries.take(4).toList();
      displayedEntries.addAll(top4NonOther);

      final remainderSum = nonOtherEntries.skip(4).fold(0.0, (sum, e) => sum + e.value);
      final totalOtros = otherOriginal.value + remainderSum;

      if (totalOtros > 0) {
        displayedEntries.add(MapEntry('Otros', totalOtros));
      }
    } else {
      displayedEntries.addAll(entriesWithSpend);
    }

    final totalDisplayMonto = widget.totalGastadoMes > 0 ? widget.totalGastadoMes : totalSuma;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.showBudgetBars ? 'Distribución por Categorías' : 'Distribución de Gastos',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!widget.showBudgetBars && widget.onNavigateToAnalysis != null)
                InkWell(
                  key: const Key('btn_ver_analisis_completo'),
                  onTap: widget.onNavigateToAnalysis,
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
                          'Ver detalle',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
          if (sections.isNotEmpty && totalSuma > 0) ...[
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Dona con Total al Centro
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          sections: sections,
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _fmt(totalDisplayMonto),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Lista de Categorías con icono circular, % y monto alineados
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: displayedEntries.map((entry) {
                      final color = AppColors.categoryColors[entry.key] ?? AppColors.textSecondary;
                      final total = totalDisplayMonto > 0 ? totalDisplayMonto : 1.0;
                      final pct = ((entry.value / total) * 100).round();
                      final icon = getCategoryIcon(entry.key);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, size: 13, color: color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _fmt(entry.value),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],

          if (widget.showBudgetBars && sortedCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.label_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 6),
                Text(
                  'Control de Presupuestos por Categoría',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...sortedCategories.map((cat) => _buildCategoryBudgetItem(context, cat)),
          ],
        ],
      ),
    );
  }

  Widget _buildGeneralBudgetItem(BuildContext context) {
    final double spent = widget.totalGastadoMes;
    final double budget = widget.presupuestoGeneral;
    final bool isExceeded = spent > budget;
    final double percent = (spent / budget).clamp(0.0, 1.0);
    final Color progressColor = isExceeded
        ? AppColors.error
        : (percent >= 0.75 ? AppColors.warning : AppColors.primaryDark);

    return Container(
      key: const Key('general_budget_card'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isExceeded
            ? AppColors.error.withOpacity(0.06)
            : AppColors.cardLighter,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExceeded
              ? AppColors.error.withOpacity(0.4)
              : AppColors.border,
          width: isExceeded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 16, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Presupuesto General',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                '${_fmt(spent)} / ${_fmt(budget)}',
                style: TextStyle(
                  color: isExceeded ? AppColors.error : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                key: const Key('edit_general_budget_button'),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showBudgetDialog(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const Key('general_budget_progress'),
              value: percent,
              color: progressColor,
              backgroundColor: isExceeded
                  ? AppColors.error.withOpacity(0.2)
                  : AppColors.border,
              minHeight: 6,
            ),
          ),
          if (isExceeded) ...[
            const SizedBox(height: 6),
            Container(
              key: const Key('excess_alert_general'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Presupuesto superado por ${_fmt(spent - budget)}',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _getSpent(String category) {
    if (widget.categoryTotals.containsKey(category)) {
      return widget.categoryTotals[category]!;
    }
    for (final entry in widget.categoryTotals.entries) {
      if (entry.key.toLowerCase().trim() == category.toLowerCase().trim()) {
        return entry.value;
      }
    }
    return 0.0;
  }

  double _getBudget(String category) {
    double rawBudget = 0.0;
    if (widget.categoryBudgets.containsKey(category)) {
      rawBudget = widget.categoryBudgets[category]!;
    } else {
      for (final entry in widget.categoryBudgets.entries) {
        if (entry.key.toLowerCase().trim() == category.toLowerCase().trim()) {
          rawBudget = entry.value;
          break;
        }
      }
    }
    if (rawBudget <= 0) return 0.0;

    // Si los presupuestos están fijados en USD pero la vista actual es VES, adaptamos el límite con la tasa actual
    if (widget.monedaPrincipal == 'VES') {
      return rawBudget * (widget.tasaCambio > 0 ? widget.tasaCambio : 1.0);
    }
    return rawBudget;
  }

  Widget _buildCategoryBudgetItem(BuildContext context, String cat) {
    final double spent = _getSpent(cat);
    final double budget = _getBudget(cat);
    final bool hasBudget = budget > 0;
    final bool isExceeded = hasBudget && spent > budget;
    final Color categoryColor = isExceeded
        ? AppColors.error
        : (AppColors.categoryColors[cat] ?? AppColors.primary);

    return Container(
      key: Key('category_budget_item_$cat'),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isExceeded
            ? AppColors.error.withOpacity(0.06)
            : AppColors.cardLighter,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExceeded
              ? AppColors.error.withOpacity(0.4)
              : AppColors.border,
          width: isExceeded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() {
                if (_expandedCategory == cat) {
                  _expandedCategory = null;
                } else {
                  _expandedCategory = cat;
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CategoryChart.getCategoryIcon(cat),
                        size: 13,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
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
                    Text(
                      hasBudget
                          ? '${_fmt(spent)} / ${_fmt(budget)}'
                          : _fmt(spent),
                      style: TextStyle(
                        color: isExceeded ? AppColors.error : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    if (hasBudget) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        key: Key('edit_budget_$cat'),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showBudgetDialog(
                          context,
                          initialCategory: cat,
                          currentBudget: budget,
                        ),
                      ),
                    ],
                  ],
                ),
                if (hasBudget) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: Key('category_progress_$cat'),
                      value: isExceeded
                          ? 1.0
                          : (budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0),
                      color: isExceeded
                          ? AppColors.error
                          : (AppColors.categoryColors[cat] ?? AppColors.primary),
                      backgroundColor: isExceeded
                          ? AppColors.error.withOpacity(0.2)
                          : AppColors.border,
                      minHeight: 6,
                    ),
                  ),
                ],
                if (isExceeded) ...[
                  const SizedBox(height: 6),
                  Container(
                    key: Key('excess_alert_$cat'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.error,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Presupuesto superado por ${_fmt(spent - budget)}',
                          style: const TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!hasBudget) ...[
                  const SizedBox(height: 2),
                  InkWell(
                    key: Key('assign_budget_prompt_$cat'),
                    onTap: () => _showBudgetDialog(
                      context,
                      initialCategory: cat,
                      currentBudget: 0.0,
                    ),
                    child: const Text(
                      '+ Asignar presupuesto mensual',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_expandedCategory == cat) ...[
            const SizedBox(height: 8),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            ..._buildCategoryItems(cat),
          ],
        ],
      ),
    );
  }

  void _showBudgetDialog(
    BuildContext context, {
    String? initialCategory,
    double? currentBudget,
  }) {
    BudgetBottomSheet.show(context);
  }
  List<Widget> _buildCategoryItems(String cat) {
    final List<Map<String, dynamic>> items = [];
    for (final gasto in widget.gastosMes) {
      if (gasto.items.isEmpty) {
        if (gasto.categoria.toLowerCase().trim() == cat.toLowerCase().trim()) {
          final double amount = widget.monedaPrincipal == 'VES'
              ? (gasto.moneda == 'VES' ? gasto.totalOriginalDisplay : gasto.totalUsdDisplay * (gasto.tasaCambio > 0 ? gasto.tasaCambio : 1.0))
              : gasto.totalUsdDisplay;
          items.add({
            'descripcion': gasto.comercio,
            'comercio': gasto.fecha,
            'monto': amount,
            'cantidad': 1.0,
          });
        }
      } else {
        for (final item in gasto.items) {
          if (item.categoria.toLowerCase().trim() == cat.toLowerCase().trim()) {
            double itemAmount;
            if (widget.monedaPrincipal == 'VES') {
              if (gasto.moneda == 'VES') {
                itemAmount = item.totalDisplay;
              } else {
                final tasa = gasto.tasaCambio > 0 ? gasto.tasaCambio : 1.0;
                itemAmount = item.totalDisplay * tasa;
              }
            } else {
              if (gasto.moneda == 'USD') {
                itemAmount = item.totalDisplay;
              } else {
                final ratio = gasto.totalOriginalDisplay > 0 ? (gasto.totalUsdDisplay / gasto.totalOriginalDisplay) : 0.0;
                itemAmount = item.totalDisplay * ratio;
              }
            }
            items.add({
              'descripcion': item.descripcion,
              'comercio': gasto.comercio,
              'monto': itemAmount,
              'cantidad': item.cantidad,
            });
          }
        }
      }
    }

    if (items.isEmpty) {
      return [const Text('No hay compras en esta categoría.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))];
    }

    return items.map((it) {
      final double cantidad = (it['cantidad'] as num).toDouble();
      final String descripcion = it['descripcion'] as String;
      final String comercio = it['comercio'] as String;
      final double monto = (it['monto'] as num).toDouble();

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                '${cantidad.toStringAsFixed(cantidad % 1 == 0 ? 0 : 2)}x $descripcion',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                comercio,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _fmt(monto),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }).toList();
  }
}
