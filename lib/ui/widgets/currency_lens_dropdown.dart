import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';

/// Selector desplegable compacto [ USD BCV ▾ ] utilizado en las cabeceras
/// de las tarjetas de Inicio (SummaryCard) y Análisis (AnalysisScreen)
/// para unificar visual y funcionalmente el cambio de lente monetario en toda la app.
class CurrencyLensDropdown extends StatelessWidget {
  final String? monedaSeleccionada;
  final ValueChanged<String>? onMonedaChanged;
  final Key? dropdownKey;

  const CurrencyLensDropdown({
    Key? key,
    this.monedaSeleccionada,
    this.onMonedaChanged,
    this.dropdownKey,
  }) : super(key: key);

  static const List<Map<String, String>> lenses = [
    {'id': 'USD', 'label': 'USD BCV'},
    {'id': 'VES', 'label': 'Bs.'},
    {'id': 'USDT', 'label': 'USDT P2P'},
    {'id': 'EUR', 'label': 'EUR BCV'},
  ];

  @override
  Widget build(BuildContext context) {
    SettingsProvider? settings;
    try {
      settings = Provider.of<SettingsProvider>(context, listen: true);
    } catch (_) {
      settings = null;
    }

    final current = monedaSeleccionada ?? settings?.monedaPrincipal ?? 'USD';
    final activeLens = lenses.firstWhere(
      (l) => l['id'] == current,
      orElse: () => {'id': 'USD', 'label': 'USD BCV'},
    );

    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        key: dropdownKey ?? const Key('summary_card_lens_dropdown'),
        tooltip: 'Cambiar moneda',
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        offset: const Offset(0, 32),
        onSelected: (id) {
          HapticFeedback.selectionClick();
          if (onMonedaChanged != null) {
            onMonedaChanged!(id);
          } else {
            settings?.setMonedaPrincipal(id);
          }
        },
        itemBuilder: (BuildContext ctx) {
          return lenses.map((l) {
            final id = l['id']!;
            final label = l['label']!;
            final isSelected = current == id;
            return PopupMenuItem<String>(
              key: Key('lens_switch_${id.toLowerCase()}'),
              value: id,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                ],
              ),
            );
          }).toList();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.cardLighter.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                activeLens['label'] ?? 'USD BCV',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
