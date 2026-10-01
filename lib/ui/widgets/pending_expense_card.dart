import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gasto_model.dart';

class PendingExpenseCard extends StatelessWidget {
  final GastoModel gasto;
  final VoidCallback onTap;
  final String monedaPrincipal;

  const PendingExpenseCard({
    Key? key,
    required this.gasto,
    required this.onTap,
    this.monedaPrincipal = 'USD',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.document_scanner_outlined,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gasto.comercio,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.pending_actions,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Pendiente de revisar',
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormatter.formatDate(gasto.fecha),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Builder(
                    builder: (context) {
                      final double amount;
                      if (monedaPrincipal == 'VES') {
                        amount = gasto.moneda == 'VES'
                            ? gasto.totalOriginalDisplay
                            : (gasto.totalUsdDisplay > 0
                                ? gasto.totalUsdDisplay *
                                    (gasto.tasaCambio > 0 ? gasto.tasaCambio : 1.0)
                                : gasto.totalOriginalDisplay *
                                    (gasto.tasaCambio > 0 ? gasto.tasaCambio : 1.0));
                      } else {
                        amount = gasto.moneda == 'USD'
                            ? gasto.totalOriginalDisplay
                            : (gasto.totalUsdDisplay > 0
                                ? gasto.totalUsdDisplay
                                : (gasto.tasaCambio > 0
                                    ? gasto.totalOriginalDisplay / gasto.tasaCambio
                                    : 0.0));
                      }

                      if (amount <= 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                          ),
                          child: const Text(
                            'Por revisar',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      return Text(
                        monedaPrincipal == 'VES'
                            ? CurrencyFormatter.formatVes(amount)
                            : CurrencyFormatter.formatUsd(amount),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.primaryDark),
            ],
          ),
        ),
      ),
    );
  }
}
