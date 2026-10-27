import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/gasto_model.dart';

String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  final isAllUpper = text == text.toUpperCase() && text.contains(RegExp(r'[A-Za-z]'));
  if (!isAllUpper) return text;

  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    final lower = word.toLowerCase();
    if (lower == 'c.a.' || lower == 's.a.' || lower == 's.r.l.' || lower == 'c.a' || lower == 's.a') {
      return word.toUpperCase();
    }
    return lower[0].toUpperCase() + lower.substring(1);
  }).join(' ');
}

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

    final hasAmount = amount > 0;
    final String storeName = gasto.comercio.trim().isEmpty ? 'Comercio Desconocido' : gasto.comercio;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5), // Fondo marfil suave cálido (armónico con GlobalScanQueueBanner)
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEF08A), width: 1.2), // Borde ámbar sutil
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                // Icono leading de recibo / escaneo con alto contraste (WCAG AAA > 7:1)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFDE047), width: 1),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF92400E),
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Contenido central: Comercio y estado/artículos protegido contra desbordes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _toTitleCase(storeName),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      if (hasAmount) ...[
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.pending_actions,
                                      size: 11,
                                      color: Color(0xFF92400E),
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Por revisar',
                                      style: TextStyle(
                                        color: Color(0xFF92400E),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (gasto.items.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '${gasto.items.length} ${gasto.items.length == 1 ? 'artículo' : 'artículos'}',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          gasto.items.isNotEmpty
                              ? '${gasto.items.length} ${gasto.items.length == 1 ? 'artículo detectado' : 'artículos detectados'}'
                              : 'Toca para completar datos',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Lado derecho: Monto detectado o Botón de Acción 'Por revisar →'
                if (hasAmount) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 115),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        CurrencyFormatter.formatAmount(amount, monedaPrincipal),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Por revisar',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward,
                          size: 11,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
