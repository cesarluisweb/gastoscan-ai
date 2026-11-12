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
        return '✓ Actualizada hoy';
      case EstadoTasaMoneda.referencia:
        return 'Última registrada';
      case EstadoTasaMoneda.sinTasa:
        return 'Sin tasa disponible';
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
                flex: 6,
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
                flex: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _textoEstadoTasa(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _colorEstadoTasa(),
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: const Key('refresh_rates_btn'),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildRateColumn(
                    label: 'Dólar BCV',
                    monto: settings.tasaCambioVesUsd > 1.0
                        ? 'Bs. ${settings.tasaCambioVesUsd.toStringAsFixed(2)}'
                        : '—',
                    unit: 'por USD',
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(
                  child: _buildRateColumn(
                    label: 'Euro BCV',
                    monto: settings.tasaCambioVesEur > 1.0
                        ? 'Bs. ${settings.tasaCambioVesEur.toStringAsFixed(2)}'
                        : '—',
                    unit: 'por EUR',
                  ),
                ),
                Container(width: 1, height: 36, color: AppColors.border),
                Expanded(
                  child: _buildRateColumn(
                    label: 'USDT P2P',
                    monto: settings.tasaCambioVesUsdt > 1.0
                        ? 'Bs. ${settings.tasaCambioVesUsdt.toStringAsFixed(2)}'
                        : '—',
                    unit: 'por USDT',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateColumn({required String label, required String monto, required String unit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
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
