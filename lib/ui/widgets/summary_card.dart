import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'budget_bottom_sheet.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/finance/savings_health_models.dart';
import '../../domain/finance/savings_health_calculator.dart';
import '../../providers/settings_provider.dart';

class SummaryCard extends StatelessWidget {
  final double totalUsd;
  final double totalVes;
  final double totalUsdt;
  final String periodo;
  final String monedaPrincipal;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;
  final double presupuestoGeneral;
  final double metaAhorro;
  final String monedaPresupuesto;
  final int? mes;
  final int? anio;
  final ValueChanged<String>? onMonedaChanged;

  const SummaryCard({
    Key? key,
    required this.totalUsd,
    required this.totalVes,
    this.totalUsdt = 0.0,
    required this.periodo,
    this.monedaPrincipal = 'USD',
    this.tasaCambio = 1.0,
    this.tasaEur = 0.0,
    this.tasaUsdt = 0.0,
    this.presupuestoGeneral = 0.0,
    this.metaAhorro = 0.0,
    this.monedaPresupuesto = 'USD',
    this.mes,
    this.anio,
    this.onMonedaChanged,
  }) : super(key: key);

  double _convertBudgetToLens(double amount) {
    if (amount <= 0) return 0.0;
    if (monedaPresupuesto == monedaPrincipal) return amount;

    final double usdRate = tasaCambio > 0 ? tasaCambio : 1.0;
    final double eurRate = tasaEur > 0 ? tasaEur : usdRate;

    double inUsd = amount;
    if (monedaPresupuesto == 'VES') {
      inUsd = amount / usdRate;
    } else if (monedaPresupuesto == 'EUR') {
      inUsd = (amount * eurRate) / usdRate;
    } else if (monedaPresupuesto == 'USDT') {
      inUsd = amount;
    }

    if (monedaPrincipal == 'USD' || monedaPrincipal == 'USDT') {
      return inUsd;
    } else if (monedaPrincipal == 'VES') {
      return inUsd * usdRate;
    } else if (monedaPrincipal == 'EUR') {
      return eurRate > 0 ? (inUsd * usdRate) / eurRate : inUsd;
    }
    return amount;
  }

  @override
  Widget build(BuildContext context) {
    final double usdtEff = totalUsdt > 0 ? totalUsdt : totalUsd;
    final double usdRate = tasaCambio > 0 ? tasaCambio : 1.0;
    final double eurRate = tasaEur > 0 ? tasaEur : usdRate;
    final double vesEquiv = totalVes > 0 ? totalVes : (totalUsd * usdRate);

    final double effectiveSpent;
    if (monedaPrincipal == 'VES') {
      effectiveSpent = vesEquiv;
    } else if (monedaPrincipal == 'USDT') {
      effectiveSpent = usdtEff;
    } else if (monedaPrincipal == 'EUR') {
      effectiveSpent = eurRate > 0 ? (vesEquiv / eurRate) : totalUsd;
    } else {
      effectiveSpent = totalUsd;
    }

    final numberFormatter = NumberFormat('#,##0.00', 'es_VE');
    final displayMainAmount = numberFormatter.format(effectiveSpent);

    final textoSecundario = CurrencyFormatter.formatSecundario(
      totalUsd,
      totalVes > 0 ? totalVes : null,
      tasaCambio,
      monedaPrincipal,
    );

    final hasBudget = presupuestoGeneral > 0;
    final hasSavingsGoal = metaAhorro > 0;

    final double budgetInLens = _convertBudgetToLens(presupuestoGeneral);
    final double metaInLens = _convertBudgetToLens(metaAhorro);

    final limiteParaGastar = hasSavingsGoal
        ? (budgetInLens - metaInLens).clamp(0.0, double.infinity)
        : budgetInLens;

    final targetBudget = hasSavingsGoal ? limiteParaGastar : budgetInLens;
    final percentUsed = (hasBudget && targetBudget > 0) ? (effectiveSpent / targetBudget) : 0.0;
    final isOverBudget = hasBudget && (effectiveSpent > targetBudget);

    final now = DateTime.now();
    final targetYear = anio ?? now.year;
    final targetMonth = mes ?? now.month;
    final isCurrentMonth = (mes == null || anio == null) ||
        (now.month == targetMonth && now.year == targetYear);
    final isPastMonth = targetYear < now.year ||
        (targetYear == now.year && targetMonth < now.month);
    final totalDaysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
    final daysRemaining = isCurrentMonth
        ? (totalDaysInMonth - now.day).clamp(0, 31)
        : (isPastMonth ? 0 : totalDaysInMonth);
    final daysForCalculation = daysRemaining > 0 ? daysRemaining : 1;

    final rem = (targetBudget - effectiveSpent).clamp(0.0, double.infinity);
    final ritmoDiario = rem / daysForCalculation;
    final remFormatted = CurrencyFormatter.formatAmount(rem, monedaPrincipal);
    final ritmoFormatted = CurrencyFormatter.formatAmount(ritmoDiario, monedaPrincipal);
    final budgetFormatted = CurrencyFormatter.formatAmount(budgetInLens, monedaPrincipal);
    final limiteFormatted = CurrencyFormatter.formatAmount(limiteParaGastar, monedaPrincipal);
    final excessFormatted = CurrencyFormatter.formatAmount(
      (effectiveSpent - targetBudget).clamp(0.0, double.infinity),
      monedaPrincipal,
    );

    final snapshot = hasSavingsGoal
        ? SavingsHealthCalculator.calculate(
            presupuestoGeneral: budgetInLens,
            metaAhorro: metaInLens,
            gastoAcumulado: effectiveSpent,
            diaActual: isCurrentMonth ? now.day : (isPastMonth ? totalDaysInMonth : 1),
            diasTotalesMes: totalDaysInMonth,
            moneda: monedaPrincipal,
          )
        : null;

    final lenses = [
      {'id': 'USD', 'label': 'USD BCV'},
      {'id': 'VES', 'label': 'Bs.'},
      {'id': 'USDT', 'label': 'USDT P2P'},
      {'id': 'EUR', 'label': 'EUR BCV'},
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ==========================================
          // BLOQUE 1: Total gastado + Selector Binance
          // ==========================================
          const Text(
            'Total gastado',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    displayMainAmount,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _buildCurrencyDropdown(context, lenses),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '≈ $textoSecundario',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          // ==========================================
          // SIN PRESUPUESTO: Botón de definición
          // ==========================================
          if (!hasBudget) ...[
            const SizedBox(height: 16),
            InkWell(
              key: const Key('summary_card_set_budget_btn'),
              onTap: () => BudgetBottomSheet.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardLighter,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.secondary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '+ Definir presupuesto del mes',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // ==========================================
            // BLOQUE 2: Disponible por gastar / Te sobraron
            // ==========================================
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final String label;
                if (isPastMonth) {
                  label = isOverBudget
                      ? (hasSavingsGoal ? 'Excedido del límite' : 'Excedido del presupuesto')
                      : 'Te sobraron';
                } else {
                  label = isOverBudget
                      ? (hasSavingsGoal ? 'Excedido del límite' : 'Excedido del presupuesto')
                      : 'Disponible por gastar';
                }

                final displayRemAmount = isOverBudget ? excessFormatted : remFormatted;
                final amountColor = isOverBudget ? AppColors.error : const Color(0xFF2E7D32);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: isOverBudget ? AppColors.error : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        displayRemAmount,
                        style: TextStyle(
                          color: amountColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // ==========================================
            // BLOQUE 3: Barra de progreso (Allocation)
            // ==========================================
            const SizedBox(height: 14),
            if (!hasSavingsGoal)
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: percentUsed.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: AppColors.cardLighter,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.getBudgetProgressColor(percentUsed, isExceeded: isOverBudget),
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  const gap = 2.0;
                  final availableWidth = (totalWidth - gap).clamp(0.0, double.infinity);

                  final double rawMetaRatio = budgetInLens > 0 ? (metaInLens / budgetInLens) : 0.0;
                  final double metaRatio = rawMetaRatio.clamp(0.12, 0.35);
                  final double limiteRatio = 1.0 - metaRatio;

                  final double limiteWidth = availableWidth * limiteRatio;
                  final double metaWidth = availableWidth * metaRatio;

                  final double limiteSpentRatio = limiteParaGastar > 0
                      ? (effectiveSpent / limiteParaGastar).clamp(0.0, 1.0)
                      : 1.0;
                  final double spentInLimiteWidth = limiteWidth * limiteSpentRatio;

                  final bool isInvading = effectiveSpent > limiteParaGastar;
                  final double excessOverLimite = (effectiveSpent - limiteParaGastar).clamp(0.0, double.infinity);
                  final double metaInvadedRatio = metaInLens > 0
                      ? (excessOverLimite / metaInLens).clamp(0.0, 1.0)
                      : (isInvading ? 1.0 : 0.0);
                  final double spentInMetaWidth = metaWidth * metaInvadedRatio;

                  final Color limiteFillColor = isInvading
                      ? AppColors.error
                      : AppColors.getBudgetProgressColor(limiteSpentRatio, isExceeded: false);

                  const Color metaBaseColor = Color(0xFFF59E0B);

                  return Row(
                    children: [
                      // Tramo Límite
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(5),
                          bottomLeft: Radius.circular(5),
                        ),
                        child: Container(
                          width: limiteWidth,
                          height: 8,
                          color: AppColors.cardLighter,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: spentInLimiteWidth,
                            height: 8,
                            decoration: BoxDecoration(
                              color: limiteFillColor,
                              borderRadius: spentInLimiteWidth >= limiteWidth
                                  ? BorderRadius.zero
                                  : const BorderRadius.only(
                                      topRight: Radius.circular(2),
                                      bottomRight: Radius.circular(2),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: gap),
                      // Tramo Meta de Ahorro
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(5),
                          bottomRight: Radius.circular(5),
                        ),
                        child: Container(
                          width: metaWidth,
                          height: 8,
                          color: metaBaseColor,
                          alignment: Alignment.centerLeft,
                          child: isInvading
                              ? Container(
                                  width: spentInMetaWidth,
                                  height: 8,
                                  color: AppColors.error,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  );
                },
              ),

            // ==========================================
            // BLOQUE 4: Pie en formato tabla limpia
            // ==========================================
            const SizedBox(height: 14),
            // Fila 1: Límite del mes / Presupuesto del mes (Toda la fila tocable)
            InkWell(
              key: const Key('summary_card_edit_budget_btn'),
              onTap: () => BudgetBottomSheet.show(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      hasSavingsGoal ? 'Límite del mes' : 'Presupuesto del mes',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              hasSavingsGoal ? limiteFormatted : budgetFormatted,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Fila 2: Ritmo sugerido / Ritmo del mes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isPastMonth ? 'Ritmo del mes' : 'Ritmo sugerido',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      isPastMonth
                          ? 'Período finalizado'
                          : (isOverBudget
                              ? (hasSavingsGoal ? 'Límite superado' : 'Presupuesto superado')
                              : '$ritmoFormatted/día · $daysRemaining d'),
                      style: TextStyle(
                        color: (isOverBudget && !isPastMonth) ? AppColors.error : AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Fila 3: Meta de ahorro (Condicional si hasSavingsGoal)
            if (hasSavingsGoal) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final bool isInvading = effectiveSpent > limiteParaGastar;
                  final bool isEnRiesgo = snapshot?.status == SavingsGoalStatus.enRiesgo;

                  final Color dotColor;
                  final String statusText;
                  final Color statusTextColor;

                  if (isInvading || snapshot?.status == SavingsGoalStatus.comprometida) {
                    dotColor = AppColors.error;
                    statusText = 'Comprometida';
                    statusTextColor = AppColors.error;
                  } else if (isEnRiesgo) {
                    dotColor = const Color(0xFFD97706);
                    statusText = 'En riesgo';
                    statusTextColor = const Color(0xFFD97706);
                  } else {
                    dotColor = const Color(0xFFF59E0B);
                    statusText = 'Protegida';
                    statusTextColor = AppColors.textPrimary;
                  }

                  final metaFormatted = CurrencyFormatter.formatAmount(metaInLens, monedaPrincipal);

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Meta de ahorro',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$metaFormatted · ',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(
    BuildContext context,
    List<Map<String, String>> lenses,
  ) {
    SettingsProvider? settings;
    try {
      settings = Provider.of<SettingsProvider>(context, listen: false);
    } catch (_) {
      settings = null;
    }
    final current = settings?.monedaPrincipal ?? monedaPrincipal;
    final activeLens = lenses.firstWhere(
      (l) => l['id'] == current,
      orElse: () => {'id': 'USD', 'label': 'USD BCV'},
    );

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        key: const Key('summary_card_lens_dropdown'),
        tooltip: 'Cambiar moneda',
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        offset: const Offset(0, 36),
        onSelected: (id) {
          HapticFeedback.selectionClick();
          if (onMonedaChanged != null) {
            onMonedaChanged!(id);
          } else {
            settings?.setMonedaPrincipal(id);
          }
        },
        itemBuilder: (BuildContext ctx) {
          return lenses.map((l) {
            final id = l['id']!;
            final label = l['label']!;
            final isSelected = current == id;
            return PopupMenuItem<String>(
              key: Key('lens_switch_${id.toLowerCase()}'),
              value: id,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.cardLighter.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activeLens['label'] ?? 'USD BCV',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
