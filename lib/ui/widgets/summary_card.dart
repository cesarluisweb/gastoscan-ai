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
    final percentUsed = hasBudget ? (totalUsd / presupuestoGeneral) : 0.0;
    final isOverBudget = hasBudget && (totalUsd > presupuestoGeneral);

    final now = DateTime.now();
    final isCurrentMonth = (mes == null || anio == null) ||
        (now.month == mes && now.year == anio);
    final totalDaysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysRemaining = (totalDaysInMonth - now.day).clamp(0, 31);

    String remainingMessage = '';
    if (hasBudget) {
      if (isOverBudget) {
        final overAmount = CurrencyFormatter.formatPreferido(
          totalUsd - presupuestoGeneral,
          null,
          tasaCambio,
          monedaPrincipal,
        );
        remainingMessage = 'Has superado tu presupuesto por $overAmount';
      } else {
        final remAmount = CurrencyFormatter.formatPreferido(
          presupuestoGeneral - totalUsd,
          null,
          tasaCambio,
          monedaPrincipal,
        );
        if (isCurrentMonth) {
          remainingMessage = 'Te quedan $remAmount y faltan $daysRemaining días';
        } else {
          remainingMessage = 'Te sobraron $remAmount en este período';
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Este mes has gastado',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasBudget)
                Text(
                  'Meta: ${CurrencyFormatter.formatPreferido(presupuestoGeneral, null, tasaCambio, monedaPrincipal)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                )
              else
                InkWell(
                  key: const Key('summary_card_set_budget_btn'),
                  onTap: () => BudgetBottomSheet.show(context),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '+ Definir meta',
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
          const SizedBox(height: 12),
          Text(
            textoPrincipal,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.currency_exchange, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                textoSecundario,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (hasBudget) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(percentUsed * 100).toStringAsFixed(0)}% del presupuesto usado',
                  style: TextStyle(
                    color: isOverBudget ? AppColors.error : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  isOverBudget ? 'Excedido' : 'Disponible',
                  style: TextStyle(
                    color: isOverBudget ? AppColors.error : Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentUsed.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: AppColors.cardLighter,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOverBudget
                      ? AppColors.error
                      : (percentUsed >= 0.85 ? AppColors.warning : AppColors.primaryDark),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              remainingMessage,
              style: TextStyle(
                color: isOverBudget ? AppColors.error : AppColors.textSecondary,
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
