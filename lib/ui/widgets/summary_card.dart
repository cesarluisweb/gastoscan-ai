import 'budget_bottom_sheet.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../domain/finance/savings_health_models.dart';
import '../../domain/finance/savings_health_calculator.dart';

class SummaryCard extends StatelessWidget {
  final double totalUsd;
  final double totalVes;
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

  const SummaryCard({
    Key? key,
    required this.totalUsd,
    required this.totalVes,
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textoPrincipal = CurrencyFormatter.formatPreferido(
      totalUsd,
      totalVes > 0 ? totalVes : null,
      tasaCambio,
      monedaPrincipal,
      tasaEur: tasaEur,
      tasaUsdt: tasaUsdt,
    );

    final textoSecundario = CurrencyFormatter.formatSecundario(
      totalUsd,
      totalVes > 0 ? totalVes : null,
      tasaCambio,
      monedaPrincipal,
    );

    final hasBudget = presupuestoGeneral > 0;
    final hasSavingsGoal = metaAhorro > 0;
    final isBudgetVes = monedaPresupuesto == 'VES';
    final effectiveSpent = isBudgetVes
        ? (totalVes > 0 ? totalVes : totalUsd * tasaCambio)
        : totalUsd;

    final limiteParaGastar = hasSavingsGoal
        ? (presupuestoGeneral - metaAhorro).clamp(0.0, double.infinity)
        : presupuestoGeneral;

    final targetBudget = hasSavingsGoal ? limiteParaGastar : presupuestoGeneral;
    final percentUsed = (hasBudget && targetBudget > 0) ? (effectiveSpent / targetBudget) : 0.0;
    final isOverBudget = hasBudget && (effectiveSpent > targetBudget);

    final now = DateTime.now();
    final isCurrentMonth = (mes == null || anio == null) ||
        (now.month == mes && now.year == anio);
    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = (totalDaysInMonth - now.day).clamp(0, 31);
    final daysForCalculation = daysRemaining > 0 ? daysRemaining : 1;

    // Métricas para la fila inferior compacta
    final rem = (targetBudget - effectiveSpent).clamp(0.0, double.infinity);
    final ritmoDiario = rem / daysForCalculation;
    final diasTexto = daysRemaining == 1 ? 'Falta 1 día' : 'Faltan $daysRemaining días';
    final remFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(rem)
        : CurrencyFormatter.formatPreferido(
            rem,
            null,
            tasaCambio,
            monedaPrincipal,
            tasaEur: tasaEur,
            tasaUsdt: tasaUsdt,
          );
    final ritmoFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(ritmoDiario)
        : CurrencyFormatter.formatPreferido(
            ritmoDiario,
            null,
            tasaCambio,
            monedaPrincipal,
            tasaEur: tasaEur,
            tasaUsdt: tasaUsdt,
          );
    final budgetFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(presupuestoGeneral)
        : CurrencyFormatter.formatPreferido(presupuestoGeneral, null, tasaCambio, monedaPrincipal, tasaEur: tasaEur, tasaUsdt: tasaUsdt);
    final limiteFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(limiteParaGastar)
        : CurrencyFormatter.formatPreferido(limiteParaGastar, null, tasaCambio, monedaPrincipal, tasaEur: tasaEur, tasaUsdt: tasaUsdt);
    final excessFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(effectiveSpent - targetBudget)
        : CurrencyFormatter.formatPreferido(effectiveSpent - targetBudget, null, tasaCambio, monedaPrincipal, tasaEur: tasaEur, tasaUsdt: tasaUsdt);

    final snapshot = hasSavingsGoal
        ? SavingsHealthCalculator.calculate(
            presupuestoGeneral: presupuestoGeneral,
            metaAhorro: metaAhorro,
            gastoAcumulado: effectiveSpent,
            diaActual: isCurrentMonth ? now.day : totalDaysInMonth,
            diasTotalesMes: totalDaysInMonth,
            moneda: monedaPresupuesto,
          )
        : null;

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
          // Fila superior: "Total gastado" y "Presupuesto: $X"
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total gastado',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasBudget)
                Flexible(
                  child: InkWell(
                    key: const Key('summary_card_edit_budget_btn'),
                    onTap: () => BudgetBottomSheet.show(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cardLighter,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              hasSavingsGoal
                                  ? 'Límite: $limiteFormatted'
                                  : 'Presupuesto: $budgetFormatted',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                InkWell(
                  key: const Key('summary_card_set_budget_btn'),
                  onTap: () => BudgetBottomSheet.show(context),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      '+ Definir presupuesto',
                      style: TextStyle(
                        color: AppColors.secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          // Monto Principal
          Text(
            textoPrincipal,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 34,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 1),
          // Monto Secundario (Bs.) limpio sin chip de tasa
          Text(
            textoSecundario,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasSavingsGoal && snapshot != null) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                Color badgeColor;
                Color badgeTextColor;
                String statusText;
                switch (snapshot.status) {
                  case SavingsGoalStatus.protegida:
                    badgeColor = const Color(0xFFE8F5E9);
                    badgeTextColor = const Color(0xFF2E7D32);
                    statusText = 'Protegida';
                    break;
                  case SavingsGoalStatus.enRiesgo:
                    badgeColor = const Color(0xFFFFF8E1);
                    badgeTextColor = const Color(0xFFB45309);
                    statusText = 'En riesgo';
                    break;
                  case SavingsGoalStatus.comprometida:
                    badgeColor = const Color(0xFFFFEBEE);
                    badgeTextColor = const Color(0xFFC62828);
                    statusText = 'Comprometida';
                    break;
                  case SavingsGoalStatus.sinMeta:
                    return const SizedBox.shrink();
                }

                final metaFormatted = isBudgetVes
                    ? CurrencyFormatter.formatVes(metaAhorro)
                    : CurrencyFormatter.formatPreferido(metaAhorro, null, tasaCambio, monedaPrincipal, tasaEur: tasaEur, tasaUsdt: tasaUsdt);

                return Container(
                  key: const Key('summary_card_savings_badge'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: badgeTextColor.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.savings_outlined, size: 14, color: AppColors.primaryDark),
                      const SizedBox(width: 6),
                      Text(
                        'Meta ahorro: $metaFormatted ($statusText)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: badgeTextColor,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          if (hasBudget) ...[
            const SizedBox(height: 10),
            // Barra de progreso con porcentaje a la derecha
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: percentUsed.clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.cardLighter,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isOverBudget
                            ? AppColors.error
                            : (percentUsed >= 0.80 ? AppColors.warning : const Color(0xFF10B981)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${(percentUsed * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: isOverBudget ? AppColors.error : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Fila de resumen de ritmo diario y saldo disponible
            if (isOverBudget)
              Text(
                hasSavingsGoal
                    ? 'Has superado tu límite para gastar por $excessFormatted'
                    : 'Has superado tu presupuesto por $excessFormatted',
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (isCurrentMonth)
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    hasSavingsGoal
                        ? 'Te quedan $remFormatted para gastar'
                        : 'Te quedan $remFormatted',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(
                    diasTexto,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  Text(
                    'Ritmo diario: $ritmoFormatted',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            else
              Text(
                'Te sobraron $remFormatted en este período',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
