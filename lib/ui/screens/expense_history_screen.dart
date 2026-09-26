import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../data/models/gasto_model.dart';
import '../widgets/expense_card.dart';
import 'review_expense_screen.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u');
  }

  String _getGroupHeader(String fechaStr) {
    try {
      final parsed = DateTime.parse(fechaStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final expenseDate = DateTime(parsed.year, parsed.month, parsed.day);

      final monthName = DateFormatter.getMonthName(parsed.month);
      final shortMonth = monthName.length > 3 ? monthName.substring(0, 3) : monthName;

      if (expenseDate == today) {
        return 'Hoy, ${parsed.day} $shortMonth';
      } else if (expenseDate == yesterday) {
        return 'Ayer, ${parsed.day} $shortMonth';
      } else if (parsed.year == now.year) {
        return '${parsed.day} $shortMonth';
      } else {
        return '${parsed.day} $shortMonth ${parsed.year}';
      }
    } catch (_) {
      return fechaStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final mesNombre = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    // Filtrar gastos por búsqueda
    final query = _normalizeText(_searchQuery.trim());
    final filteredGastos = gastoProvider.gastos.where((gasto) {
      if (query.isEmpty) return true;
      final matchComercio = _normalizeText(gasto.comercio).contains(query);
      final matchItems = gasto.items.any((item) => _normalizeText(item.descripcion).contains(query));
      return matchComercio || matchItems;
    }).toList();

    // Ordenar descendente y agrupar por fecha
    final sortedGastos = List<GastoModel>.from(filteredGastos)
      ..sort((a, b) => b.fecha.compareTo(a.fecha));

    final Map<String, List<GastoModel>> groupedGastos = {};
    for (final gasto in sortedGastos) {
      final header = _getGroupHeader(gasto.fecha);
      groupedGastos.putIfAbsent(header, () => []).add(gasto);
    }

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                key: const Key('expense_history_search_field'),
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                decoration: const InputDecoration(
                  hintText: 'Buscar por comercio o producto...',
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text('Gastos'),
        actions: [
          IconButton(
            key: const Key('expense_history_search_toggle'),
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchCtrl.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Selector de Mes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$mesNombre $anio',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
                      onPressed: () {
                        int nuevoMes = gastoProvider.selectedMonth - 1;
                        int nuevoAnio = gastoProvider.selectedYear;
                        if (nuevoMes < 1) {
                          nuevoMes = 12;
                          nuevoAnio--;
                        }
                        gastoProvider.cambiarMes(nuevoAnio, nuevoMes);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      onPressed: () {
                        int nuevoMes = gastoProvider.selectedMonth + 1;
                        int nuevoAnio = gastoProvider.selectedYear;
                        if (nuevoMes > 12) {
                          nuevoMes = 1;
                          nuevoAnio++;
                        }
                        gastoProvider.cambiarMes(nuevoAnio, nuevoMes);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de Gastos agrupada por fecha
          Expanded(
            child: gastoProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : sortedGastos.isEmpty
                    ? _buildEmptyState(query.isNotEmpty)
                    : ListView(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
                        children: [
                          for (final entry in groupedGastos.entries) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 14, bottom: 6),
                              child: Text(
                                entry.key,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            for (final gasto in entry.value)
                              ExpenseCard(
                                key: ValueKey('history_${gasto.id ?? gasto.comercio}_${gasto.uuid}'),
                                gasto: gasto,
                                monedaPrincipal: settings.monedaPrincipal,
                                onEdit: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ReviewExpenseScreen(
                                        existingGasto: gasto,
                                      ),
                                    ),
                                  );
                                },
                                onDelete: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: AppColors.card,
                                      title: const Text('Eliminar Factura',
                                          style: TextStyle(color: AppColors.textPrimary)),
                                      content: Text(
                                        '¿Deseas eliminar el gasto de "${gasto.comercio}"?',
                                        style: const TextStyle(color: AppColors.textSecondary),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancelar',
                                              style: TextStyle(color: AppColors.textSecondary)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Eliminar',
                                              style: TextStyle(color: AppColors.error)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && gasto.id != null) {
                                    gastoProvider.eliminarGasto(gasto.id!);
                                  }
                                },
                              ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isFiltered) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered ? Icons.search_off_rounded : Icons.receipt_long_outlined,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              isFiltered ? 'No se encontraron gastos' : 'Sin facturas este mes',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isFiltered
                  ? 'Intenta con otro término de búsqueda.'
                  : 'Presiona "+" para registrar tu primera compra.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
