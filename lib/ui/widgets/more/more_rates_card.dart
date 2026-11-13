import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/monetary/rate_market.dart';
import '../../../providers/settings_provider.dart';

class MoreRatesCard extends StatelessWidget {
  final SettingsProvider settings;
  final VoidCallback onRefresh;

  const MoreRatesCard({
    Key? key,
    required this.settings,
    required this.onRefresh,
  }) : super(key: key);

  String _textoEstadoTasa() {
    if (settings.esTasaManualUsd) return 'Tasa manual';
    switch (settings.estadoTasaUsd) {
      case EstadoTasaMoneda.actualizada:
        return 'Actualizada hoy';
      case EstadoTasaMoneda.referencia:
        return 'Última registrada';
      case EstadoTasaMoneda.sinTasa:
        return 'Sin tasa disponible';
    }
  }

  IconData _iconoEstadoTasa() {
    if (settings.esTasaManualUsd) return Icons.tune;
    switch (settings.estadoTasaUsd) {
      case EstadoTasaMoneda.actualizada:
        return Icons.check_circle;
      case EstadoTasaMoneda.referencia:
        return Icons.schedule;
      case EstadoTasaMoneda.sinTasa:
        return Icons.error_outline;
    }
  }

  Color _colorEstadoTasa() {
    if (settings.esTasaManualUsd) return AppColors.textSecondary;
    switch (settings.estadoTasaUsd) {
      case EstadoTasaMoneda.actualizada:
        return AppColors.balancePositive;
      case EstadoTasaMoneda.referencia:
        return const Color(0xFF92400E);
      case EstadoTasaMoneda.sinTasa:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final estadoColor = _colorEstadoTasa();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.currency_exchange, color: AppColors.primaryDark, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tasas de Cambio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_iconoEstadoTasa(), size: 12, color: estadoColor),
                      const SizedBox(width: 4),
                      Text(
                        _textoEstadoTasa(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: estadoColor,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('refresh_rates_btn'),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: settings.isSyncingRate
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.refresh, size: 18, color: AppColors.textSecondary),
                tooltip: 'Actualizar tasas',
                onPressed: settings.isSyncingRate ? null : onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRateCard(
                  cardKey: const Key('rate_card_usd'),
                  icon: Icons.attach_money,
                  label: 'Dólar BCV',
                  monto: settings.tasaCambioVesUsd > 1.0
                      ? 'Bs. ${settings.tasaCambioVesUsd.toStringAsFixed(2)}'
                      : '—',
                  unit: 'por USD',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRateCard(
                  cardKey: const Key('rate_card_eur'),
                  icon: Icons.euro,
                  label: 'Euro BCV',
                  monto: settings.tasaCambioVesEur > 1.0
                      ? 'Bs. ${settings.tasaCambioVesEur.toStringAsFixed(2)}'
                      : '—',
                  unit: 'por EUR',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRateCard(
                  cardKey: const Key('rate_card_usdt'),
                  icon: Icons.toll_outlined,
                  label: 'USDT P2P',
                  monto: settings.tasaCambioVesUsdt > 1.0
                      ? 'Bs. ${settings.tasaCambioVesUsdt.toStringAsFixed(2)}'
                      : '—',
                  unit: 'por USDT',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard({
    required Key cardKey,
    required IconData icon,
    required String label,
    required String monto,
    required String unit,
  }) {
    return Container(
      key: cardKey,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: AppColors.primaryDark),
                const SizedBox(width: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              monto,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              unit,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
