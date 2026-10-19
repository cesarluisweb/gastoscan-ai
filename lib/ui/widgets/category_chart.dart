import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/currency_formatter.dart';

import '../../data/models/gasto_model.dart';
import 'budget_bottom_sheet.dart';

class CategoryChart extends StatefulWidget {
  final Map<String, double> categoryTotals;
  final Map<String, double> categoryBudgets;
  final double presupuestoGeneral;
  final double totalGastadoMes;
  final List<GastoModel> gastosMes;
  final void Function(String categoria, double budget)? onSetBudget;
  final String monedaPrincipal;
  final bool showBudgetBars;
  final VoidCallback? onNavigateToAnalysis;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;
  final bool separateCards;

  const CategoryChart({
    Key? key,
    required this.categoryTotals,
    this.categoryBudgets = const {},
    this.presupuestoGeneral = 0.0,
    this.totalGastadoMes = 0.0,
    this.gastosMes = const [],
    this.onSetBudget,
    this.monedaPrincipal = 'USD',
    this.showBudgetBars = true,
    this.onNavigateToAnalysis,
    this.tasaCambio = 1.0,
    this.tasaEur = 0.0,
    this.tasaUsdt = 0.0,
    this.separateCards = false,
  }) : super(key: key);

  static IconData getCategoryIcon(String cat) => AppConstants.getCategoryIcon(cat);

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

    // Si estamos en la vista de Dashboard (!showBudgetBars), mostrar top 4 y consolidar '+X categorías'
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

      final extraCount = entriesWithSpend.length - top4NonOther.length;
      if (totalOtros > 0) {
        final label = extraCount == 1 ? '+1 categoría' : '+$extraCount categorías';
        displayedEntries.add(MapEntry(label, totalOtros));
      }
    } else {
      displayedEntries.addAll(entriesWithSpend);
    }

    // Preparar secciones del gráfico circular (alineadas con la leyenda)
    final List<PieChartSectionData> sections = [];
    if (totalSuma > 0) {
      final entriesForChart = (!widget.showBudgetBars && entriesWithSpend.length > 5)
          ? displayedEntries
          : entriesWithSpend;

      for (final entry in entriesForChart) {
        if (entry.value <= 0) continue;
        final color = AppColors.categoryColors[entry.key] ?? AppColors.textSecondary;
        final porcentaje = (entry.value / totalSuma) * 100;

        sections.add(
          PieChartSectionData(
            color: color,
            value: entry.value,
            title: porcentaje >= 8 ? '${porcentaje.toStringAsFixed(0)}%' : '',
            radius: 40,
            titleStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color.computeLuminance() > 0.45 ? Colors.black : Colors.white,
            ),
          ),
        );
      }
    }

    final totalDisplayMonto = widget.totalGastadoMes > 0 ? widget.totalGastadoMes : totalSuma;

    Widget buildDonutHeader() {
      return Row(
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
      );
    }

    Widget buildDonutBody() {
      return Row(
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
                          color: color.withValues(alpha: 0.12),
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
      );
    }

    if (widget.separateCards) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('card_category_distribution'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildDonutHeader(),
                if (sections.isNotEmpty && totalSuma > 0) ...[
                  const SizedBox(height: 16),
                  buildDonutBody(),
                ],
              ],
            ),
          ),
          if (widget.showBudgetBars && sortedCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              key: const Key('card_category_budget_control'),
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.label_outline,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Control de Presupuestos por Categoría',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...sortedCategories.map((cat) => _buildCategoryBudgetItem(context, cat)),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildDonutHeader(),
          if (sections.isNotEmpty && totalSuma > 0) ...[
            const SizedBox(height: 16),
            buildDonutBody(),
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
            ? AppColors.error.withValues(alpha: 0.06)
            : AppColors.cardLighter,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isExceeded
              ? AppColors.error.withValues(alpha: 0.4)
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
                        color: categoryColor.withValues(alpha: 0.12),
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
                          ? AppColors.error.withValues(alpha: 0.2)
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
                      color: AppColors.error.withValues(alpha: 0.12),
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
      final tasa = gasto.tasaCambio > 0 ? gasto.tasaCambio : (widget.tasaCambio > 0 ? widget.tasaCambio : 1.0);
      if (gasto.items.isEmpty) {
        if (gasto.categoria.toLowerCase().trim() == cat.toLowerCase().trim()) {
          final double amount;
          if (widget.monedaPrincipal == 'VES') {
            amount = gasto.moneda == 'VES' ? gasto.totalOriginalDisplay : gasto.totalUsdDisplay * tasa;
          } else {
            amount = CurrencyFormatter.convertFromUsd(
              gasto.totalUsdDisplay,
              widget.monedaPrincipal,
              tasa,
              tasaEur: widget.tasaEur,
              tasaUsdt: widget.tasaUsdt,
            );
          }
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
            double itemUsd;
            if (gasto.moneda == 'USD') {
              itemUsd = item.totalDisplay;
            } else {
              final ratio = gasto.totalOriginalDisplay > 0 ? (gasto.totalUsdDisplay / gasto.totalOriginalDisplay) : 0.0;
              itemUsd = ratio > 0 ? item.totalDisplay * ratio : item.totalDisplay / tasa;
            }

            final double itemAmount;
            if (widget.monedaPrincipal == 'VES') {
              itemAmount = gasto.moneda == 'VES' ? item.totalDisplay : item.totalDisplay * tasa;
            } else {
              itemAmount = CurrencyFormatter.convertFromUsd(
                itemUsd,
                widget.monedaPrincipal,
                tasa,
                tasaEur: widget.tasaEur,
                tasaUsdt: widget.tasaUsdt,
              );
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
