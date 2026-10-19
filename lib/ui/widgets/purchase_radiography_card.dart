import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gasto_model.dart';

/// Tarjeta 6 — Radiografía de Compras (Gastos Hormiga vs. Fuertes)
/// Clasifica las compras del mes en 3 rangos según su magnitud en USD
/// (< $5, $5-$25, > $25) y destaca el gasto individual más alto.
class PurchaseRadiographyCard extends StatelessWidget {
  final List<GastoModel> gastosMes;
  final String monedaPrincipal;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;

  const PurchaseRadiographyCard({
    Key? key,
    required this.gastosMes,
    this.monedaPrincipal = 'USD',
    this.tasaCambio = 1.0,
    this.tasaEur = 0.0,
    this.tasaUsdt = 0.0,
  }) : super(key: key);

  double _convertGastoToActiveCurrency(GastoModel gasto) {
    final double usdRate = tasaCambio > 0 ? tasaCambio : 1.0;
    final double eurRate = tasaEur > 0 ? tasaEur : usdRate;

    if (monedaPrincipal == 'VES') {
      if (gasto.moneda == 'VES') {
        return gasto.totalOriginalDisplay;
      }
      final rate = gasto.tasaCambio > 0 ? gasto.tasaCambio : usdRate;
      return gasto.totalUsdDisplay * rate;
    } else if (monedaPrincipal == 'USDT') {
      return (gasto.totalUsdt != null && gasto.totalUsdt! > 0)
          ? gasto.totalUsdtDisplay
          : gasto.totalUsdDisplay;
    } else if (monedaPrincipal == 'EUR') {
      if (gasto.moneda == 'VES') {
        return eurRate > 0 ? gasto.totalOriginalDisplay / eurRate : gasto.totalUsdDisplay;
      }
      return CurrencyFormatter.convertFromUsd(
        gasto.totalUsdDisplay,
        'EUR',
        usdRate,
        tasaEur: tasaEur,
        tasaUsdt: tasaUsdt,
      );
    } else {
      // USD
      return gasto.totalUsdDisplay;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (gastosMes.isEmpty) {
      return const SizedBox.shrink();
    }

    int countHormiga = 0;
    double sumHormiga = 0.0;

    int countMedias = 0;
    double sumMedias = 0.0;

    int countFuertes = 0;
    double sumFuertes = 0.0;

    GastoModel? mayorGasto;
    double mayorGastoUsd = -1.0;

    for (final g in gastosMes) {
      final double usd = g.totalUsdDisplay;
      final double activeMonto = _convertGastoToActiveCurrency(g);

      if (usd < 5.0) {
        countHormiga++;
        sumHormiga += activeMonto;
      } else if (usd <= 25.0) {
        countMedias++;
        sumMedias += activeMonto;
      } else {
        countFuertes++;
        sumFuertes += activeMonto;
      }

      if (usd > mayorGastoUsd) {
        mayorGastoUsd = usd;
        mayorGasto = g;
      }
    }

    final double totalSuma = sumHormiga + sumMedias + sumFuertes;
    final int totalCount = gastosMes.length;

    Widget buildRow({
      required String label,
      required int count,
      required double amount,
      required Color barColor,
    }) {
      final double ratio = totalSuma > 0 ? (amount / totalSuma).clamp(0.0, 1.0) : 0.0;
      final String formattedAmount = CurrencyFormatter.formatAmount(amount, monedaPrincipal);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$count ${count == 1 ? 'compra' : 'compras'} · $formattedAmount',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: AppColors.cardLighter,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
          ],
        ),
      );
    }

    // Pie con mayor gasto
    Widget? mayorGastoWidget;
    if (mayorGasto != null) {
      final String nombre = mayorGasto.comercio.trim().isNotEmpty
          ? mayorGasto.comercio
          : mayorGasto.categoria;
      final double montoActivo = _convertGastoToActiveCurrency(mayorGasto);
      final String montoFmt = CurrencyFormatter.formatAmount(montoActivo, monedaPrincipal);

      String fechaFmt = mayorGasto.fecha;
      final d = DateTime.tryParse(mayorGasto.fecha);
      if (d != null) {
        fechaFmt = '${d.day} de ${DateFormatter.getMonthName(d.month)}';
      }

      mayorGastoWidget = Row(
        children: [
          const Text('🏆 ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: Text.rich(
              key: const Key('purchase_radiography_highest_expense'),
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'Mayor gasto: '),
                  TextSpan(
                    text: nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextSpan(
                    text: ' ($montoFmt el $fechaFmt)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Container(
      key: const Key('card_purchase_radiography'),
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
          // Cabecera: Título y badge de registros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Radiografía de Compras',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.cardLighter,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
                ),
                child: Text(
                  '$totalCount ${totalCount == 1 ? 'registro' : 'registros'}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3 filas de clasificación
          buildRow(
            label: '🐜 Gastos hormiga (menores a \$ 5)',
            count: countHormiga,
            amount: sumHormiga,
            barColor: const Color(0xFF64748B), // Slate suave
          ),
          buildRow(
            label: '🛒 Compras medias (\$ 5 a \$ 25)',
            count: countMedias,
            amount: sumMedias,
            barColor: const Color(0xFF3B82F6), // Azul medio
          ),
          buildRow(
            label: '🐘 Gastos fuertes (mayores a \$ 25)',
            count: countFuertes,
            amount: sumFuertes,
            barColor: const Color(0xFFE11D48), // Rosa intenso / carmesí
          ),

          if (mayorGastoWidget != null) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            mayorGastoWidget,
          ],
        ],
      ),
    );
  }
}
