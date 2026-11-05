import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import 'month_selector_bar.dart';

/// Selector de mes responsivo integrado en las acciones del AppBar como una cápsula unificada.
/// Integra dentro de un único contenedor las flechas circulares de navegación y la píldora central.
/// Muestra el mes abreviado (ej. 'Nov' en el año actual, o 'Nov 25' en años distintos) sin flecha inferior ni icono de calendario.
class AppBarMonthSelector extends StatelessWidget {
  final String? keyPrefix;
  final double? maxWidth;
  final int? selectedMonth;
  final int? selectedYear;
  final void Function(int year, int month)? onMonthChanged;

  const AppBarMonthSelector({
    super.key,
    this.keyPrefix,
    this.maxWidth,
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

  Widget _buildArrowCircle({
    required IconData icon,
    required String tooltip,
    required bool isDisabled,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isDisabled
                  ? Colors.transparent
                  : const Color(0xFFF1F5F9).withOpacity(0.55), // Gris tenue y muy sutil
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 15,
              color: isDisabled
                  ? AppColors.textSecondary.withOpacity(0.2)
                  : AppColors.textSecondary.withOpacity(0.7), // Discreto sin llamar la atención
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = (selectedMonth == null || selectedYear == null)
        ? _tryGetGastoProvider(context)
        : null;
    final int currentYear = DateTime.now().year;
    final int month = selectedMonth ?? gastoProvider?.selectedMonth ?? DateTime.now().month;
    final int year = selectedYear ?? gastoProvider?.selectedYear ?? currentYear;

    final double screenWidth = MediaQuery.maybeSizeOf(context)?.width ?? 0;
    final double defaultWidth = screenWidth > 0 ? (screenWidth - 200).clamp(80.0, 400.0) : 200.0;
    final double effectiveMaxWidth = maxWidth ?? defaultWidth;

    final double scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    if (effectiveMaxWidth < 40 * scale) {
      return const SizedBox.shrink();
    }

    final bool showArrows = effectiveMaxWidth >= 75 * scale;
    final String mesNombre = DateFormatter.getMonthName(month);
    final String mesCorto = mesNombre.length >= 3 ? mesNombre.substring(0, 3) : mesNombre;
    final String anioCorto = (year % 100).toString().padLeft(2, '0');
    final String textoPildora = (year == currentYear) ? mesCorto : '$mesCorto $anioCorto';

    final bool isPrevDisabled = year <= AppConstants.fechaMinimaHistoricoTasas.year && month <= 1;

    final Widget capsule = Container(
      height: 34,
      padding: EdgeInsets.symmetric(
        horizontal: showArrows ? 3 : 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showArrows) ...[
            _buildArrowCircle(
              icon: Icons.chevron_left,
              tooltip: 'Mes anterior',
              isDisabled: isPrevDisabled,
              onTap: isPrevDisabled ? null : () => _irAMesAnterior(context, year, month),
            ),
            const SizedBox(width: 3),
          ],
          Semantics(
            button: true,
            label: 'Cambiar mes, $mesNombre $year',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: Key('${keyPrefix ?? ''}month_selector_title'),
                borderRadius: BorderRadius.circular(16),
                onTap: () => MonthSelectorBar.showMonthPicker(
                  context: context,
                  initialYear: year,
                  initialMonth: month,
                  keyPrefix: keyPrefix,
                  onSelected: (nuevoAnio, nuevoMes) {
                    _handleCambiarMes(context, nuevoAnio, nuevoMes);
                  },
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    textoPildora,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showArrows) ...[
            const SizedBox(width: 3),
            _buildArrowCircle(
              icon: Icons.chevron_right,
              tooltip: 'Mes siguiente',
              isDisabled: false,
              onTap: () => _irAMesSiguiente(context, year, month),
            ),
          ],
        ],
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: capsule,
      ),
    );
  }
}
