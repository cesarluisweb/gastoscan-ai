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
    final targetFormatted = CurrencyFormatter.formatAmount(targetBudget, monedaPrincipal);
    final remFormatted = CurrencyFormatter.formatAmount(rem, monedaPrincipal);
    final ritmoFormatted = CurrencyFormatter.formatAmount(ritmoDiario, monedaPrincipal);
    final metaFormatted = CurrencyFormatter.formatAmount(metaInLens, monedaPrincipal);
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
          // 1. CABECERA: Total gastado <--> Selector Binance
          // ==========================================
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Total gastado',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              _buildCurrencyDropdown(context, lenses),
            ],
          ),

          // ==========================================
          // 2. BLOQUE DE GASTO Y LÍMITE: 205,31 de $ 550,00
          // ==========================================
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  displayMainAmount,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                    height: 1.1,
                  ),
                ),
                if (hasBudget) ...[
                  const SizedBox(width: 4),
                  Text(
                    ' de $targetFormatted',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '≈ $textoSecundario',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),

          // ==========================================
          // ESTADO SIN PRESUPUESTO
          // ==========================================
          if (!hasBudget) ...[
            const SizedBox(height: 16),
            InkWell(
              key: const Key('summary_card_set_budget_btn'),
              onTap: () => BudgetBottomSheet.show(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                    Flexible(
                      child: Text(
                        '+ Definir presupuesto y meta de ahorro / inversión',
                        style: TextStyle(
                          color: AppColors.secondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // ==========================================
            // 3. BLOQUE DE DISPONIBLE Y RITMO
            // ==========================================
            const SizedBox(height: 14),
            Text(
              isPastMonth
                  ? (isOverBudget ? (hasSavingsGoal ? 'Excedido del límite' : 'Excedido del presupuesto') : 'Te sobraron')
                  : (isOverBudget
                      ? (hasSavingsGoal ? 'Excedido del límite' : 'Excedido del presupuesto')
                      : (daysRemaining == 1
                          ? 'Disponible para gastar hoy'
                          : 'Disponible para gastar en $daysRemaining días')),
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
                isOverBudget ? excessFormatted : remFormatted,
                style: TextStyle(
                  color: isOverBudget ? AppColors.error : const Color(0xFF2E7D32),
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              isPastMonth
                  ? 'Período finalizado'
                  : (isOverBudget
                      ? (hasSavingsGoal ? 'Límite superado' : 'Presupuesto superado')
                      : 'Ritmo sugerido: $ritmoFormatted/día'),
              style: TextStyle(
                color: (isOverBudget && !isPastMonth) ? AppColors.error : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),

            // ==========================================
            // 4. BARRA DE PROGRESO CON MARCA SUTIL DE AHORRO
            // ==========================================
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final double rawMetaRatio = budgetInLens > 0 ? (metaInLens / budgetInLens) : 0.0;
                final double metaRatio = rawMetaRatio.clamp(0.12, 0.35);
                final double savingsDividerPos = totalWidth * (1.0 - metaRatio);

                return Stack(
                  children: [
                    // Barra base de progreso
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
                    ),
                    // Divisor sutil neutral de la meta de ahorro
                    if (hasSavingsGoal)
                      Positioned(
                        left: savingsDividerPos - 1.0,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          decoration: BoxDecoration(
                            color: AppColors.textMuted.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // ==========================================
            // 5. PIE DE TARJETA: Meta de ahorro + Lápiz
            // ==========================================
            const SizedBox(height: 12),
            InkWell(
              key: const Key('summary_card_edit_budget_btn'),
              onTap: () => BudgetBottomSheet.show(context),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.savings_outlined,
                              size: 15,
                              color: hasSavingsGoal
                                  ? ((isOverBudget || snapshot?.status == SavingsGoalStatus.comprometida)
                                      ? AppColors.error
                                      : (snapshot?.status == SavingsGoalStatus.enRiesgo
                                          ? const Color(0xFFD97706)
                                          : const Color(0xFF2E7D32)))
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            if (hasSavingsGoal) ...[
                              Text(
                                'Meta de ahorro: $metaFormatted · ',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                (isOverBudget || snapshot?.status == SavingsGoalStatus.comprometida)
                                    ? 'Comprometida'
                                    : (snapshot?.status == SavingsGoalStatus.enRiesgo ? 'En riesgo' : 'Protegida'),
                                style: TextStyle(
                                  color: (isOverBudget || snapshot?.status == SavingsGoalStatus.comprometida)
                                      ? AppColors.error
                                      : (snapshot?.status == SavingsGoalStatus.enRiesgo
                                          ? const Color(0xFFD97706)
                                          : AppColors.textPrimary),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                '+ Definir meta de ahorro / inversión',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.edit_outlined,
                      size: 15,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
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
        offset: const Offset(0, 32),
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
