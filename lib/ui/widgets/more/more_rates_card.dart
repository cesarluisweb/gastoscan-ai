import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/monetary/rate_market.dart';
import '../../../providers/settings_provider.dart';
import '../currency_lens_dropdown.dart';

class MoreRatesCard extends StatelessWidget {
  final SettingsProvider settings;
  final VoidCallback onRefresh;
  final VoidCallback onOpenBcv;

  const MoreRatesCard({
    Key? key,
    required this.settings,
    required this.onRefresh,
    required this.onOpenBcv,
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
        return AppColors.warning;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.currency_exchange, color: AppColors.primaryDark, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tasas de Cambio',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      _textoEstadoTasa(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _colorEstadoTasa(),
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Moneda de reportes:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              CurrencyLensDropdown(
                dropdownKey: const Key('more_currency_lens_dropdown'),
                monedaSeleccionada: settings.monedaPrincipal,
                onMonedaChanged: (newMoneda) {
                  settings.setMonedaPrincipal(newMoneda);
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const Key('more_rates_bcv_disclaimer'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cardLighter,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tasas de referencia tomadas de fuentes públicas oficiales (BCV). Rinde Más no representa al BCV ni a ninguna entidad gubernamental.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                InkWell(
                  key: const Key('more_rates_bcv_source_link'),
                  onTap: onOpenBcv,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Fuente oficial: www.bcv.org.ve',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.open_in_new, size: 12, color: AppColors.textPrimary),
                    ],
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
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
            ),
          ),
          Text(
            unit,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
