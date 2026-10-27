import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/gasto_model.dart';

/// Tarjeta 5 — ¿En qué moneda se va tu dinero? (Radiografía por moneda de origen)
/// Agrupa los gastos del mes según la moneda original en la que fueron registrados
/// (VES/Bs., USD, USDT, EUR), convirtiendo sus subtotales a la moneda activa del selector.
class CurrencyRadiographyCard extends StatelessWidget {
  final List<GastoModel> gastosMes;
  final String monedaPrincipal;
  final double tasaCambio;
  final double tasaEur;
  final double tasaUsdt;

  const CurrencyRadiographyCard({
    Key? key,
    required this.gastosMes,
    this.monedaPrincipal = 'USD',
    this.tasaCambio = 1.0,
    this.tasaEur = 0.0,
    this.tasaUsdt = 0.0,
  }) : super(key: key);

  static const Map<String, Color> currencyColors = {
    'VES': Color(0xFF2563EB), // Azul financiero
    'USD': Color(0xFF16A34A), // Verde dólar
    'USDT': Color(0xFF0D9488), // Verde azulado crypto
    'EUR': Color(0xFF9333EA), // Púrpura euro
  };

  static const Map<String, String> currencyLabels = {
    'VES': 'Pagado en Bolívares (Bs.)',
    'USD': 'Pagado en USD',
    'USDT': 'Pagado en USDT',
    'EUR': 'Pagado en EUR',
  };

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
      final rate = gasto.tasaCambio > 0 ? gasto.tasaCambio : usdRate;
      final ves = gasto.moneda == 'VES'
          ? gasto.totalOriginalDisplay
          : gasto.totalUsdDisplay * rate;
      return eurRate > 0 ? ves / eurRate : gasto.totalUsdDisplay;
    } else {
      // USD
      return gasto.totalUsdDisplay;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Agrupar gastos por moneda de origen
    final Map<String, double> totalsByCurrency = {};
    for (final g in gastosMes) {
      final code = g.moneda.trim().toUpperCase();
      final normCode = (code == 'BS' || code == 'VES')
          ? 'VES'
          : (code == 'USD' || code == 'USDT' || code == 'EUR' ? code : 'USD');
      final double monto = _convertGastoToActiveCurrency(g);
      totalsByCurrency[normCode] = (totalsByCurrency[normCode] ?? 0.0) + monto;
    }

    final double totalSuma = totalsByCurrency.values.fold(0.0, (a, b) => a + b);

    // Filtrar y ordenar de mayor a menor uso
    final entries = totalsByCurrency.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (entries.isEmpty || totalSuma <= 0) {
      return const SizedBox.shrink();
    }

    return Container(
      key: const Key('card_currency_radiography'),
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
          const Text(
            '¿En qué moneda se va tu dinero?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Distribución según la moneda original registrada',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),

          // Barra horizontal apilada multi-segmento
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: SizedBox(
              height: 10,
              child: Row(
                children: entries.map((e) {
                  final double pct = (e.value / totalSuma) * 100;
                  final int flex = (pct * 10).round().clamp(1, 1000);
                  final color = currencyColors[e.key] ?? AppColors.primaryDark;
                  return Expanded(
                    flex: flex,
                    child: Container(
                      color: color,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Lista clasificada de desglose
          Column(
            children: entries.map((e) {
              final double pct = (e.value / totalSuma) * 100;
              final color = currencyColors[e.key] ?? AppColors.primaryDark;
              final label = currencyLabels[e.key] ?? 'Pagado en ${e.key}';
              final formattedAmount = CurrencyFormatter.formatAmount(e.value, monedaPrincipal);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          formattedAmount,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
