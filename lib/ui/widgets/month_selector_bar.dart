import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';

/// Barra de seleccion de mes y anio con boton tipo pildora central y flechas laterales.
/// Al tocar la pildora central se abre un dialogo modal con cuadricula de 12 meses
/// y navegacion de anio.
class MonthSelectorBar extends StatelessWidget {
  final String? keyPrefix;
  final int? selectedMonth;
  final int? selectedYear;
  final void Function(int year, int month)? onMonthChanged;
  final EdgeInsetsGeometry padding;

  const MonthSelectorBar({
    Key? key,
    this.keyPrefix,
    this.selectedMonth,
    this.selectedYear,
    this.onMonthChanged,
    this.padding = EdgeInsets.zero,
  }) : super(key: key);

  void _handleCambiarMes(BuildContext context, int nuevoAnio, int nuevoMes) {
    if (onMonthChanged != null) {
      onMonthChanged!(nuevoAnio, nuevoMes);
    } else {
      Provider.of<GastoProvider>(context, listen: false).cambiarMes(nuevoAnio, nuevoMes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final month = selectedMonth ?? gastoProvider.selectedMonth;
    final year = selectedYear ?? gastoProvider.selectedYear;
    final mesNombre = DateFormatter.getMonthName(month);

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 22),
            visualDensity: VisualDensity.compact,
            tooltip: 'Mes anterior',
            onPressed: () {
              int nuevoMes = month - 1;
              int nuevoAnio = year;
              if (nuevoMes < 1) {
                nuevoMes = 12;
                nuevoAnio--;
              }
              _handleCambiarMes(context, nuevoAnio, nuevoMes);
            },
          ),
          InkWell(
            key: Key('${keyPrefix ?? ''}month_selector_title'),
            onTap: () => showMonthPicker(
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.cardLighter,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$mesNombre $year',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 22),
            visualDensity: VisualDensity.compact,
            tooltip: 'Mes siguiente',
            onPressed: () {
              int nuevoMes = month + 1;
              int nuevoAnio = year;
              if (nuevoMes > 12) {
                nuevoMes = 1;
                nuevoAnio++;
              }
              _handleCambiarMes(context, nuevoAnio, nuevoMes);
            },
          ),
        ],
      ),
    );
  }

  /// Muestra el dialogo modal con cuadricula de meses y navegacion de anio.
  static void showMonthPicker({
    required BuildContext context,
    required int initialYear,
    required int initialMonth,
    required void Function(int year, int month) onSelected,
    String? keyPrefix,
  }) {
    int tempAnio = initialYear;

    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    showDialog(
      context: context,
      builder: (dContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
                    onPressed: () {
                      setStateDialog(() {
                        tempAnio--;
                      });
                    },
                  ),
                  Text(
                    '$tempAnio',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
                    onPressed: () {
                      setStateDialog(() {
                        tempAnio++;
                      });
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 280,
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final mesNum = index + 1;
                    final isSelected = (mesNum == initialMonth && tempAnio == initialYear);
                    return InkWell(
                      key: Key('${keyPrefix ?? ''}month_pick_$mesNum'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        onSelected(tempAnio, mesNum);
                        Navigator.pop(dContext);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.cardLighter,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryDark : AppColors.border,
                          ),
                        ),
                        child: Text(
                          meses[index].substring(0, 3),
                          style: TextStyle(
                            color: isSelected ? AppColors.secondary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dContext),
                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
