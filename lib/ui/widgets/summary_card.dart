import 'budget_bottom_sheet.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class SummaryCard extends StatelessWidget {
  final double totalUsd;
  final double totalVes;
  final String periodo;
  final String monedaPrincipal;
  final double tasaCambio;
  final double presupuestoGeneral;
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
    this.presupuestoGeneral = 0.0,
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
    );

    final textoSecundario = CurrencyFormatter.formatSecundario(
      totalUsd,
      totalVes > 0 ? totalVes : null,
      tasaCambio,
      monedaPrincipal,
    );

    final hasBudget = presupuestoGeneral > 0;
    final isBudgetVes = monedaPresupuesto == 'VES';
    final effectiveSpent = isBudgetVes
        ? (totalVes > 0 ? totalVes : totalUsd * tasaCambio)
        : totalUsd;
    final percentUsed = hasBudget ? (effectiveSpent / presupuestoGeneral) : 0.0;
    final isOverBudget = hasBudget && (effectiveSpent > presupuestoGeneral);

    final now = DateTime.now();
    final isCurrentMonth = (mes == null || anio == null) ||
        (now.month == mes && now.year == anio);
    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = (totalDaysInMonth - now.day).clamp(0, 31);
    final daysForCalculation = daysRemaining > 0 ? daysRemaining : 1;

    // Métricas para la fila inferior compacta
    final rem = (presupuestoGeneral - effectiveSpent).clamp(0.0, double.infinity);
    final ritmoDiario = rem / daysForCalculation;
    final diasTexto = daysRemaining == 1 ? 'Falta 1 día' : 'Faltan $daysRemaining días';
    final remFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(rem)
        : CurrencyFormatter.formatPreferido(
            rem,
            null,
            tasaCambio,
            monedaPrincipal,
          );
    final ritmoFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(ritmoDiario)
        : CurrencyFormatter.formatPreferido(
            ritmoDiario,
            null,
            tasaCambio,
            monedaPrincipal,
          );
    final budgetFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(presupuestoGeneral)
        : CurrencyFormatter.formatPreferido(presupuestoGeneral, null, tasaCambio, monedaPrincipal);
    final excessFormatted = isBudgetVes
        ? CurrencyFormatter.formatVes(effectiveSpent - presupuestoGeneral)
        : CurrencyFormatter.formatPreferido(totalUsd - presupuestoGeneral, null, tasaCambio, monedaPrincipal);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
                              'Presupuesto: $budgetFormatted',
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
                'Has superado tu presupuesto por $excessFormatted',
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
                    'Te quedan $remFormatted',
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
