import '../widgets/month_selector_bar.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/scan_queue_provider.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../widgets/expense_card.dart';
import '../widgets/pending_expense_card.dart';
import '../widgets/global_scan_queue_banner.dart';
import 'review_expense_screen.dart';

class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  bool _isSearching = false;
  bool _onlyWithReceipt = false;
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

    final scanQueue = Provider.of<ScanQueueProvider>(context);

    // Filtrar gastos por búsqueda y comprobante
    final query = _normalizeText(_searchQuery.trim());
    final filteredGastos = gastoProvider.gastos.where((gasto) {
      if (_onlyWithReceipt && (gasto.rutaFotoLocal == null || gasto.rutaFotoLocal!.isEmpty)) {
        return false;
      }
      if (query.isEmpty) return true;
      final matchComercio = _normalizeText(gasto.comercio).contains(query);
      final matchItems = gasto.items.any((item) => _normalizeText(item.descripcion).contains(query));
      return matchComercio || matchItems;
    }).toList();
    
    // Crear borradores pendientes si no hay búsqueda activa (o si deciden buscar en pendientes)
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
      
      final double totalOrig = result.totalOriginal;
      final double tasa = (result.tasaCambioDetectada != null && result.tasaCambioDetectada! > 0)
          ? result.tasaCambioDetectada!
          : (settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : 1.0);
      final double totalUsd = (result.moneda == 'USD')
          ? totalOrig
          : (tasa > 0 ? totalOrig / tasa : 0.0);

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
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : const Text('Gastos'),
        actions: [
          IconButton(
            key: const Key('expense_history_receipt_filter_toggle'),
            icon: Icon(_onlyWithReceipt ? Icons.photo_library : Icons.photo_library_outlined),
            tooltip: _onlyWithReceipt ? 'Ver todos los gastos' : 'Ver solo comprobantes',
            color: _onlyWithReceipt ? AppColors.primaryDark : null,
            onPressed: () {
              setState(() {
                _onlyWithReceipt = !_onlyWithReceipt;
              });
            },
          ),
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
          const GlobalScanQueueBanner(),
          // Selector de Mes
          const MonthSelectorBar(
            keyPrefix: 'expense_history_',
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
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
                                  initiallyExpanded: query.isNotEmpty && gasto.items.any((item) => _normalizeText(item.descripcion).contains(query)),
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
