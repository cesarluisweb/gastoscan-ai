import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import 'month_selector_bar.dart';

/// Selector de mes responsivo integrado en las acciones del AppBar como una cápsula unificada.
/// Integra dentro de un único contenedor las flechas de navegación en negro y el nombre del mes.
/// Muestra el nombre completo del mes (ej. 'Noviembre' en pantalla normal, o 'Nov' en pantalla reducida),
/// añade año a 2 dígitos al navegar a otro año (ej. 'Noviembre 25'), y resalta el borde en amarillo activo si no es el mes actual.
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

  Widget _buildArrowButton({
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
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 24,
            height: 28,
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 19,
              color: isDisabled
                  ? AppColors.textSecondary.withOpacity(0.25)
                  : AppColors.textPrimary,
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
    final DateTime now = DateTime.now();
    final int month = selectedMonth ?? gastoProvider?.selectedMonth ?? now.month;
    final int year = selectedYear ?? gastoProvider?.selectedYear ?? now.year;

    final double screenWidth = MediaQuery.maybeSizeOf(context)?.width ?? 0;
    final double defaultWidth = screenWidth > 0 ? (screenWidth - 200).clamp(80.0, 400.0) : 200.0;
    final double effectiveMaxWidth = maxWidth ?? defaultWidth;

    final double scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    if (effectiveMaxWidth < 40 * scale) {
      return const SizedBox.shrink();
    }

    final bool isCurrentMonth = (year == now.year && month == now.month);
    final bool isDifferentYear = (year != now.year);
    final bool showArrows = effectiveMaxWidth >= 75 * scale;
    final bool useFullName = effectiveMaxWidth >= 145 * scale;

    final String mesNombre = DateFormatter.getMonthName(month);
    final String mesCorto = mesNombre.length >= 3 ? mesNombre.substring(0, 3) : mesNombre;
    final String anioCorto = (year % 100).toString().padLeft(2, '0');

    final String baseMonth = useFullName ? mesNombre : mesCorto;
    final String textoPildora = isDifferentYear ? '$baseMonth $anioCorto' : baseMonth;

    final bool isPrevDisabled = year <= AppConstants.fechaMinimaHistoricoTasas.year && month <= 1;

    final Widget capsule = Container(
      height: 34,
      padding: EdgeInsets.symmetric(
        horizontal: showArrows ? 2 : 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCurrentMonth ? AppColors.border : AppColors.primaryDark,
          width: isCurrentMonth ? 1.0 : 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (showArrows) ...[
            _buildArrowButton(
              icon: Icons.chevron_left,
              tooltip: 'Mes anterior',
              isDisabled: isPrevDisabled,
              onTap: isPrevDisabled ? null : () => _irAMesAnterior(context, year, month),
            ),
            const SizedBox(width: 1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
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
            const SizedBox(width: 1),
            _buildArrowButton(
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
