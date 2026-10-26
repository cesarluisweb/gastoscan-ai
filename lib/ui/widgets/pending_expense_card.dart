import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gasto_model.dart';

class PendingExpenseCard extends StatelessWidget {
  final GastoModel gasto;
  final VoidCallback onTap;
  final String monedaPrincipal;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;

  const PendingExpenseCard({
    Key? key,
    required this.gasto,
    required this.onTap,
    this.monedaPrincipal = 'USD',
    this.tasaCambio = 1.0,
    this.tasaEur = 0.0,
    this.tasaUsdt = 0.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.5),
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
                  color: AppColors.primary.withValues(alpha: 0.2),
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
                        const Flexible(
                          child: Text(
                            'Pendiente de revisar',
                            style: TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            DateFormatter.formatDate(gasto.fecha),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                      final tasa = gasto.tasaCambio > 0 ? gasto.tasaCambio : (tasaCambio > 0 ? tasaCambio : 1.0);
                      final double ves = gasto.moneda == 'VES'
                          ? gasto.totalOriginalDisplay
                          : (gasto.totalUsdDisplay > 0
                              ? gasto.totalUsdDisplay * tasa
                              : gasto.totalOriginalDisplay * tasa);
                      final double usd = gasto.moneda == 'USD'
                          ? gasto.totalOriginalDisplay
                          : (gasto.totalUsdDisplay > 0
                              ? gasto.totalUsdDisplay
                              : (tasa > 0 ? gasto.totalOriginalDisplay / tasa : 0.0));

                      final double amount;
                      switch (monedaPrincipal.toUpperCase()) {
                        case 'VES':
                          amount = ves;
                          break;
                        case 'EUR':
                          amount = CurrencyFormatter.convertFromUsd(
                            usd,
                            'EUR',
                            tasa,
                            tasaEur: tasaEur,
                            tasaUsdt: tasaUsdt,
                          );
                          break;
                        case 'USDT':
                          amount = CurrencyFormatter.convertFromUsd(
                            usd,
                            'USDT',
                            tasa,
                            tasaEur: tasaEur,
                            tasaUsdt: tasaUsdt,
                          );
                          break;
                        case 'USD':
                        default:
                          amount = usd;
                          break;
                      }

                      if (amount <= 0) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
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

                      return FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          CurrencyFormatter.formatAmount(amount, monedaPrincipal),
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
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
