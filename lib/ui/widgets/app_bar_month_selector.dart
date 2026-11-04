import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import 'month_selector_bar.dart';

/// Selector de mes responsivo integrado en el AppBar para navegación temporal rápida.
/// Se adapta a 3 modos según el ancho disponible (maxWidth): Completo, Compacto o Mínimo.
class AppBarMonthSelector extends StatelessWidget {
  final String? keyPrefix;
  final double maxWidth;
  final int? selectedMonth;
  final int? selectedYear;
  final void Function(int year, int month)? onMonthChanged;

  const AppBarMonthSelector({
    super.key,
    this.keyPrefix,
    required this.maxWidth,
    this.selectedMonth,
    this.selectedYear,
    this.onMonthChanged,
  });

  void _handleCambiarMes(BuildContext context, int nuevoAnio, int nuevoMes) {
    if (onMonthChanged != null) {
      onMonthChanged!(nuevoAnio, nuevoMes);
      return;
    }
    try {
      Provider.of<GastoProvider>(context, listen: false).cambiarMes(nuevoAnio, nuevoMes);
    } catch (_) {
      // Ignorar si se ejecuta en pruebas unitarias aisladas sin Provider
    }
  }

  void _irAMesAnterior(BuildContext context, int year, int month) {
    int nuevoMes = month - 1;
    int nuevoAnio = year;
    if (nuevoMes < 1) {
      nuevoMes = 12;
      nuevoAnio--;
    }
    _handleCambiarMes(context, nuevoAnio, nuevoMes);
  }

  void _irAMesSiguiente(BuildContext context, int year, int month) {
    int nuevoMes = month + 1;
    int nuevoAnio = year;
    if (nuevoMes > 12) {
      nuevoMes = 1;
      nuevoAnio++;
    }
    _handleCambiarMes(context, nuevoAnio, nuevoMes);
  }

  GastoProvider? _tryGetGastoProvider(BuildContext context) {
    try {
      return Provider.of<GastoProvider>(context);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = (selectedMonth == null || selectedYear == null)
        ? _tryGetGastoProvider(context)
        : null;
    final int month = selectedMonth ?? gastoProvider?.selectedMonth ?? DateTime.now().month;
    final int year = selectedYear ?? gastoProvider?.selectedYear ?? DateTime.now().year;

    final double scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final bool isCompleto = maxWidth >= 236 * scale;
    final bool isCompacto = !isCompleto && maxWidth >= 146 * scale;
    final bool isMinimo = !isCompleto && !isCompacto && maxWidth >= 88 * scale;

    if (!isCompleto && !isCompacto && !isMinimo) {
      return const SizedBox.shrink();
    }

    final String mesNombre = DateFormatter.getMonthName(month);
    final String mesCorto = mesNombre.length >= 3 ? mesNombre.substring(0, 3) : mesNombre;
    final String textoPildora = isCompleto ? '$mesNombre $year' : '$mesCorto $year';

    final bool showArrows = isCompleto || isCompacto;
    final double arrowWidth = isCompleto ? 32.0 : 30.0;
    final bool isPrevDisabled = year <= AppConstants.fechaMinimaHistoricoTasas.year && month <= 1;

    final Widget pill = Semantics(
      button: true,
      label: 'Cambiar mes, $mesNombre $year',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('${keyPrefix ?? ''}month_selector_title'),
          onTap: () => MonthSelectorBar.showMonthPicker(
            context: context,
            initialYear: year,
            initialMonth: month,
            keyPrefix: keyPrefix,
            onSelected: (nuevoAnio, nuevoMes) {
              _handleCambiarMes(context, nuevoAnio, nuevoMes);
            },
          ),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isCompleto) ...[
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  textoPildora,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary,
                  size: isCompleto ? 16 : 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showArrows)
          IconButton(
            constraints: BoxConstraints(
              minWidth: arrowWidth,
              maxWidth: arrowWidth,
              minHeight: 32,
              maxHeight: 32,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tooltip: 'Mes anterior',
            icon: const Icon(Icons.chevron_left, size: 20, color: AppColors.textSecondary),
            onPressed: isPrevDisabled ? null : () => _irAMesAnterior(context, year, month),
          ),
        pill,
        if (showArrows)
          IconButton(
            constraints: BoxConstraints(
              minWidth: arrowWidth,
              maxWidth: arrowWidth,
              minHeight: 32,
              maxHeight: 32,
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tooltip: 'Mes siguiente',
            icon: const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            onPressed: () => _irAMesSiguiente(context, year, month),
          ),
        const SizedBox(width: 4),
      ],
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: content,
      ),
    );
  }
}
