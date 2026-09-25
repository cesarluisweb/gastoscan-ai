import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class SummaryCard extends StatelessWidget {
  final double totalUsd;
  final double totalVes;
  final String periodo;
  final double presupuesto;
  final VoidCallback? onManageBudget;

  const SummaryCard({
    Key? key,
    required this.totalUsd,
    required this.totalVes,
    required this.periodo,
    this.presupuesto = 0.0,
    this.onManageBudget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
              Text(
                'Gasto Total ($periodo)',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatUsd(totalUsd),
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
                'Equivalente en moneda local: ${CurrencyFormatter.formatVes(totalVes)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (presupuesto > 0) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: onManageBudget,
              borderRadius: BorderRadius.circular(8),
              child: Builder(
                builder: (context) {
                  final double percent = (totalUsd / presupuesto).clamp(0.0, 1.0);
                  Color barColor = AppColors.primary;
                  if (percent >= 0.9) {
                    barColor = AppColors.error;
                  } else if (percent >= 0.75) {
                    barColor = AppColors.warning;
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Presupuesto: ${CurrencyFormatter.formatUsd(presupuesto)}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              if (onManageBudget != null) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.edit_outlined, size: 14, color: AppColors.primaryDark),
                              ],
                            ],
                          ),
                          Text(
                            '${(percent * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: barColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: AppColors.surface,
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ] else if (onManageBudget != null) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: onManageBudget,
              child: const Row(
                children: [
                  Icon(Icons.add_circle_outline, size: 14, color: AppColors.primaryDark),
                  SizedBox(width: 4),
                  Text(
                    'Asignar presupuesto mensual',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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
}
