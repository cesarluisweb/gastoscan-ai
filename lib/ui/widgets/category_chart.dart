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
  final List<GastoModel> gastosMes;
  final void Function(String categoria, double budget)? onSetBudget;

  const CategoryChart({
    Key? key,
    required this.categoryTotals,
    this.categoryBudgets = const {},
    this.gastosMes = const [],
    this.onSetBudget,
  }) : super(key: key);

  @override
  State<CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<CategoryChart> {
  String? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    // Si no hay totales ni presupuestos configurados, no renderizar nada
    if (widget.categoryTotals.isEmpty && widget.categoryBudgets.isEmpty) {
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

    // Obtener lista consolidada y ordenada de categorías para presupuestos
    final Set<String> allCategoryKeys = {
      ...widget.categoryTotals.keys,
      ...widget.categoryBudgets.keys.where((k) => (widget.categoryBudgets[k] ?? 0) > 0),
    };
    final List<String> sortedCategories = allCategoryKeys.toList()
      ..sort((a, b) {
        final spentA = _getSpent(a);
        final spentB = _getSpent(b);
        return spentB.compareTo(spentA);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
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
                'Distribución y Presupuestos',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                key: const Key('add_category_budget_button'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Presupuesto', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondary,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showBudgetDialog(context),
              ),
            ],
          ),
          if (sections.isNotEmpty && totalSuma > 0) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 150,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
                        centerSpaceRadius: 35,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: ListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: widget.categoryTotals.entries.map((entry) {
                        final color = AppColors.categoryColors[entry.key] ??
                            AppColors.textSecondary;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.key,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                CurrencyFormatter.formatUsd(entry.value),
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
            ),
          ],
          if (sortedCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
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
    if (widget.categoryBudgets.containsKey(category)) {
      return widget.categoryBudgets[category]!;
    }
    for (final entry in widget.categoryBudgets.entries) {
      if (entry.key.toLowerCase().trim() == category.toLowerCase().trim()) {
        return entry.value;
      }
    }
    return 0.0;
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
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: categoryColor,
                        shape: BoxShape.circle,
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
                          ? '${CurrencyFormatter.formatUsd(spent)} / ${CurrencyFormatter.formatUsd(budget)}'
                          : CurrencyFormatter.formatUsd(spent),
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
                          'Presupuesto superado por ${CurrencyFormatter.formatUsd(spent - budget)}',
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
      for (final item in gasto.items) {
        if (item.categoria.toLowerCase().trim() == cat.toLowerCase().trim()) {
           double itemUsd = item.totalDisplay;
           if (gasto.moneda != 'USD' && gasto.totalOriginalDisplay > 0) {
             itemUsd = item.totalDisplay * (gasto.totalUsdDisplay / gasto.totalOriginalDisplay);
           }
           items.add({
             'descripcion': item.descripcion,
             'comercio': gasto.comercio,
             'usd': itemUsd,
             'cantidad': item.cantidad,
           });
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
      final double usd = (it['usd'] as num).toDouble();

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
              CurrencyFormatter.formatUsd(usd),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }).toList();
  }
}
