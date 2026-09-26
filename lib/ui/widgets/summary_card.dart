import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

class SummaryCard extends StatelessWidget {
  final double totalUsd;
  final double totalVes;
  final String periodo;
  final String monedaPrincipal;
  final double tasaCambio;

  const SummaryCard({
    Key? key,
    required this.totalUsd,
    required this.totalVes,
    required this.periodo,
    this.monedaPrincipal = 'USD',
    this.tasaCambio = 1.0,
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
        ],
      ),
    );
  }
}
