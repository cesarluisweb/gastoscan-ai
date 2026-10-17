import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scan_queue_provider.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../widgets/month_selector_bar.dart';
import '../widgets/expense_card.dart';
import '../widgets/pending_expense_card.dart';
import '../widgets/global_scan_queue_banner.dart';
import 'review_expense_screen.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  final VoidCallback? onNavigateToChat;

  const ExpenseHistoryScreen({
    Key? key,
    this.onNavigateToChat,
  }) : super(key: key);

  @override
  State<ExpenseHistoryScreen> createState() => ExpenseHistoryScreenState();
}

class ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  bool _isSearching = false;
  bool get isSearching => _isSearching;

  void activateSearch() {
    if (!_isSearching) {
      setState(() {
        _isSearching = true;
        _cargarTodosLosGastos();
      });
    }
  }

  void closeSearch() {
    if (_isSearching) {
      setState(() {
        _isSearching = false;
        _searchCtrl.clear();
        _searchQuery = '';
        _allGastos = null;
      });
    }
  }
  bool _onlyWithReceipt = false;
  String? _selectedCategory;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<GastoModel>? _allGastos;
  bool _isLoadingAll = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTodosLosGastos() async {
    if (_allGastos != null || _isLoadingAll) return;
    setState(() => _isLoadingAll = true);
    final provider = Provider.of<GastoProvider>(context, listen: false);
    final results = await provider.obtenerTodosLosGastos();
    if (mounted) {
      setState(() {
        _allGastos = results;
        _isLoadingAll = false;
      });
    }
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
    final scanQueue = Provider.of<ScanQueueProvider>(context);

    // Filtrar gastos por búsqueda, comprobante y categoría seleccionada
    final query = _normalizeText(_searchQuery.trim());
    final isSearchingGlobal = _isSearching && query.isNotEmpty;
    final baseGastos = (isSearchingGlobal && _allGastos != null)
        ? _allGastos!
        : gastoProvider.gastos;

    final filteredGastos = baseGastos.where((gasto) {
      if (_onlyWithReceipt && (gasto.rutaFotoLocal == null || gasto.rutaFotoLocal!.isEmpty)) {
        return false;
      }
      if (_selectedCategory != null && gasto.categoria != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      final matchComercio = _normalizeText(gasto.comercio).contains(query);
      final matchItems = gasto.items.any((item) => _normalizeText(item.descripcion).contains(query));
      return matchComercio || matchItems;
    }).toList();

    // Crear borradores pendientes si no hay búsqueda activa (o si coinciden con los filtros)
    final List<GastoModel> pendingGastos = [];
    for (final item in scanQueue.readyItems) {
      final imagePath = item['image_path'] as String?;
      if (_onlyWithReceipt && (imagePath == null || imagePath.isEmpty)) {
        continue;
      }

      Map<String, dynamic> data = {};
      if (item['extracted_data'] != null) {
        data = Map<String, dynamic>.from(jsonDecode(item['extracted_data']));
      }
      final result = GeminiExtractionResult.fromJson(data);

      if (_selectedCategory != null && !result.items.any((it) => it.categoria == _selectedCategory)) {
        continue;
      }

      final double totalOrig = result.totalOriginal;
      final double tasa = (result.moneda == 'VES' && result.tasaCambioDetectada != null && result.tasaCambioDetectada! > 0)
          ? result.tasaCambioDetectada!
          : (settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0);
      final double totalUsd = CurrencyFormatter.convertAmount(
        totalOrig,
        result.moneda,
        'USD',
        settings.tasaCambioVesUsd,
        tasaEur: settings.tasaCambioVesEur,
        tasaUsdt: settings.tasaCambioVesUsdt,
      );

      final dummyGasto = GastoModel(
        uuid: 'pending_${item['id']}',
        fecha: result.fecha,
        comercio: result.comercio,
        moneda: result.moneda,
        totalOriginal: (totalOrig * 100).round(),
        totalUsd: (totalUsd * 100).round(),
        tasaCambio: tasa,
        categoria: 'Pendiente',
        creadoEn: DateTime.now().toIso8601String(),
        items: result.items,
        rutaFotoLocal: imagePath,
      );

      if (query.isEmpty) {
        pendingGastos.add(dummyGasto);
      } else {
        final matchComercio = _normalizeText(dummyGasto.comercio).contains(query);
        final matchItems = dummyGasto.items.any((it) => _normalizeText(it.descripcion).contains(query));
        if (matchComercio || matchItems) pendingGastos.add(dummyGasto);
      }
    }

    // Ordenar descendente y agrupar por fecha
    final allGastos = [...pendingGastos, ...filteredGastos];
    final sortedGastos = List<GastoModel>.from(allGastos)
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
                  if (_allGastos == null) {
                    _cargarTodosLosGastos();
                  }
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
            tooltip: _isSearching ? 'Cerrar búsqueda' : 'Buscar',
            onPressed: () {
              if (_isSearching) {
                closeSearch();
              } else {
                activateSearch();
              }
            },
          ),
          IconButton(
            key: const Key('expense_history_ai_chat_button'),
            icon: const Icon(
              Icons.auto_awesome,
              size: 22,
              color: AppColors.textPrimary,
            ),
            tooltip: 'Asistente IA',
            onPressed: widget.onNavigateToChat,
          ),
        ],
      ),
      body: Column(
        children: [
          const GlobalScanQueueBanner(),
          // Selector de Mes o indicador de búsqueda global
          if (!isSearchingGlobal) ...[
            const MonthSelectorBar(
              keyPrefix: 'expense_history_',
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            ),
            _buildMonthlySummaryStrip(gastoProvider, settings, filteredGastos),
            _buildFilterChipsRow(),
            const SizedBox(height: 6),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.travel_explore, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Búsqueda en todo el historial (${filteredGastos.length} ${filteredGastos.length == 1 ? 'resultado' : 'resultados'})',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            _buildFilterChipsRow(),
            const SizedBox(height: 6),
          ],

          // Lista de Gastos agrupada por fecha
          Expanded(
            child: gastoProvider.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : sortedGastos.isEmpty
                    ? _buildEmptyState(query.isNotEmpty || _onlyWithReceipt || _selectedCategory != null)
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
                              if (gasto.categoria == 'Pendiente' && gasto.uuid.startsWith('pending_'))
                                (() {
                                  final queueItemId = int.parse(gasto.uuid.split('_')[1]);
                                  final item = scanQueue.readyItems.firstWhere(
                                    (e) => e['id'] == queueItemId,
                                    orElse: () => <String, dynamic>{},
                                  );

                                  if (item.isEmpty) return const SizedBox.shrink();

                                  Map<String, dynamic> data = {};
                                  if (item['extracted_data'] != null) {
                                    data = Map<String, dynamic>.from(jsonDecode(item['extracted_data']));
                                  }
                                  final result = GeminiExtractionResult.fromJson(data);
                                  final file = File(item['image_path']);

                                  return PendingExpenseCard(
                                    key: ValueKey('history_${gasto.uuid}'),
                                    gasto: gasto,
                                    monedaPrincipal: settings.monedaPrincipal,
                                    tasaCambio: settings.tasaCambioVesUsd,
                                    tasaEur: settings.tasaCambioVesEur,
                                    tasaUsdt: settings.tasaCambioVesUsdt,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ReviewExpenseScreen(
                                            imageFile: file.existsSync() ? file : null,
                                            extractedData: result,
                                            queueItemId: queueItemId,
                                          ),
                                        ),
                                      ).then((_) {
                                        scanQueue.loadReadyItems();
                                      });
                                    },
                                  );
                                })()
                              else
                                ExpenseCard(
                                  key: ValueKey('history_${gasto.id ?? gasto.comercio}_${gasto.uuid}'),
                                  gasto: gasto,
                                  monedaPrincipal: settings.monedaPrincipal,
                                  tasaCambio: settings.tasaCambioVesUsd,
                                  tasaEur: settings.tasaCambioVesEur,
                                  tasaUsdt: settings.tasaCambioVesUsdt,
                                  showDirectItemBreakdown: true,
                                  initiallyExpanded: query.isNotEmpty && gasto.items.any((item) => _normalizeText(item.descripcion).contains(query)),
                                  onEdit: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ReviewExpenseScreen(
                                          existingGasto: gasto,
                                        ),
                                      ),
                                    ).then((_) {
                                      if (_isSearching) {
                                        _allGastos = null;
                                        _cargarTodosLosGastos();
                                      }
                                    });
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
                                      await gastoProvider.eliminarGasto(gasto.id!);
                                      if (_isSearching) {
                                        _allGastos = null;
                                        _cargarTodosLosGastos();
                                      }
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

  Widget _buildMonthlySummaryStrip(GastoProvider gastoProvider, SettingsProvider settings, List<GastoModel> currentGastos) {
    final double tasa = settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0;

    final double sumUsd;
    final double sumVes;
    final double sumUsdt;
    if (_selectedCategory == null && !_onlyWithReceipt) {
      sumUsd = gastoProvider.totalMesUsd;
      sumVes = gastoProvider.totalMesVes;
      sumUsdt = gastoProvider.totalMesUsdt;
    } else {
      sumUsd = currentGastos.fold(0.0, (acc, g) => acc + g.totalUsdDisplay);
      sumUsdt = currentGastos.fold(0.0, (acc, g) => acc + g.totalUsdtDisplay);
      sumVes = currentGastos.fold(0.0, (acc, g) {
        final double t = g.tasaCambio > 0 ? g.tasaCambio : tasa;
        return acc + (g.moneda == 'VES' ? g.totalOriginalDisplay : g.totalUsdDisplay * t);
      });
    }

    final String primaryFormatted = CurrencyFormatter.formatPreferido(
      sumUsd,
      sumVes,
      tasa,
      settings.monedaPrincipal,
      tasaEur: settings.tasaCambioVesEur,
      tasaUsdt: settings.tasaCambioVesUsdt,
      totalUsdt: sumUsdt,
    );

    final int count = currentGastos.length;
    final String countStr = count == 1 ? '1 compra' : '$count compras';

    return Center(
      child: Container(
        key: const Key('expense_history_monthly_summary_strip'),
        margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.cardLighter,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              'Total gastado ($countStr): ',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              primaryFormatted,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipsRow() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildChipItem(
            key: const Key('expense_filter_chip_all'),
            label: 'Todos',
            isSelected: _selectedCategory == null && !_onlyWithReceipt,
            onTap: () {
              setState(() {
                _selectedCategory = null;
                _onlyWithReceipt = false;
              });
            },
          ),
          const SizedBox(width: 8),
          _buildChipItem(
            key: const Key('expense_history_receipt_filter_toggle'),
            label: '🧾 Con comprobante',
            isSelected: _onlyWithReceipt,
            onTap: () {
              setState(() {
                _onlyWithReceipt = !_onlyWithReceipt;
              });
            },
          ),
          const SizedBox(width: 8),
          for (final cat in AppConstants.categorias) ...[
            _buildChipItem(
              key: Key('expense_filter_chip_${cat.toLowerCase()}'),
              label: cat,
              icon: AppConstants.getCategoryIcon(cat),
              isSelected: _selectedCategory == cat,
              onTap: () {
                setState(() {
                  _selectedCategory = (_selectedCategory == cat) ? null : cat;
                });
              },
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildChipItem({
    required Key key,
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.black : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.black : AppColors.textPrimary,
              ),
            ),
          ],
        ),
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
                  ? 'Intenta con otro término o filtro de categoría.'
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
