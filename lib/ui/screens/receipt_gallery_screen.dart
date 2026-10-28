import '../widgets/month_selector_bar.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gasto_model.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../widgets/receipt_viewer_dialog.dart';

class ReceiptGalleryScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const ReceiptGalleryScreen({
    Key? key,
    this.showBackButton = true,
    this.onBack,
  }) : super(key: key);

  @override
  State<ReceiptGalleryScreen> createState() => _ReceiptGalleryScreenState();
}

class _ReceiptGalleryScreenState extends State<ReceiptGalleryScreen> {
  List<GastoModel> _validReceipts = [];
  List<GastoModel>? _lastGastos;
  int? _lastMonth;
  int? _lastYear;

  bool _isSelectionMode = false;
  final Set<String> _selectedGastoUuids = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gastoProvider = Provider.of<GastoProvider>(context);
    final gastos = gastoProvider.gastos;

    if (_lastMonth != gastoProvider.selectedMonth || _lastYear != gastoProvider.selectedYear) {
      _lastMonth = gastoProvider.selectedMonth;
      _lastYear = gastoProvider.selectedYear;
      if (_isSelectionMode) {
        _isSelectionMode = false;
        _selectedGastoUuids.clear();
      }
    }

    if (_lastGastos != gastos) {
      _lastGastos = gastos;
      _filterReceiptsAsync(gastos);
    }
  }

  Future<void> _filterReceiptsAsync(List<GastoModel> gastos) async {
    final withPath = gastos.where((g) => g.rutaFotoLocal != null && g.rutaFotoLocal!.isNotEmpty).toList();
    final List<GastoModel> valid = [];
    for (final g in withPath) {
      final exists = await File(g.rutaFotoLocal!).exists();
      if (exists) {
        valid.add(g);
      }
    }
    if (mounted) {
      setState(() {
        _validReceipts = valid;
        // Limpiar selecciones de fotos que ya no existan
        _selectedGastoUuids.removeWhere((uuid) => !valid.any((g) => g.uuid == uuid));
        if (_validReceipts.isEmpty && _isSelectionMode) {
          _isSelectionMode = false;
        }
      });
    }
  }

  void _enterSelectionMode(GastoModel? initialGasto) {
    setState(() {
      _isSelectionMode = true;
      _selectedGastoUuids.clear();
      if (initialGasto != null) {
        _selectedGastoUuids.add(initialGasto.uuid);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedGastoUuids.clear();
    });
  }

  void _toggleSelection(GastoModel gasto) {
    setState(() {
      if (_selectedGastoUuids.contains(gasto.uuid)) {
        _selectedGastoUuids.remove(gasto.uuid);
        if (_selectedGastoUuids.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedGastoUuids.add(gasto.uuid);
      }
    });
  }

  void _toggleSelectAll(List<GastoModel> receipts) {
    setState(() {
      if (_selectedGastoUuids.length == receipts.length) {
        _selectedGastoUuids.clear();
        _isSelectionMode = false;
      } else {
        _selectedGastoUuids.clear();
        _selectedGastoUuids.addAll(receipts.map((g) => g.uuid));
      }
    });
  }

  Future<void> _confirmarYEliminarSeleccionados(List<GastoModel> receipts) async {
    final selectedGastos = receipts.where((g) => _selectedGastoUuids.contains(g.uuid)).toList();
    if (selectedGastos.isEmpty) return;

    final count = selectedGastos.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Eliminar $count ${count == 1 ? 'foto' : 'fotos'}?',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Las fotos seleccionadas se borrarán del teléfono para liberar espacio.\n\nLos registros de compras, montos y categorías se conservarán intactos en tu historial.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar $count ${count == 1 ? 'foto' : 'fotos'}'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
      final deleted = await gastoProvider.eliminarFotosComprobantes(selectedGastos);
      if (mounted) {
        _exitSelectionMode();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$deleted ${deleted == 1 ? 'foto eliminada' : 'fotos eliminadas'} del teléfono. Los gastos se conservan.',
            ),
            backgroundColor: Colors.black87,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final mesNombre = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    final List<GastoModel> receipts = _validReceipts;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isSelectionMode
                ? (_selectedGastoUuids.isEmpty
                    ? 'Selecciona comprobantes'
                    : '${_selectedGastoUuids.length} ${_selectedGastoUuids.length == 1 ? 'seleccionado' : 'seleccionados'}')
                : 'Comprobantes Guardados',
          ),
          leading: _isSelectionMode
              ? IconButton(
                  key: const Key('btn_cancelar_seleccion'),
                  icon: const Icon(Icons.close),
                  tooltip: 'Cancelar selección',
                  onPressed: _exitSelectionMode,
                )
              : (widget.showBackButton
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack ?? () => Navigator.pop(context),
                    )
                  : null),
          automaticallyImplyLeading: _isSelectionMode || widget.showBackButton,
          actions: [
            if (!_isSelectionMode && receipts.isNotEmpty)
              TextButton.icon(
                key: const Key('btn_seleccionar_comprobantes'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                ),
                icon: const Icon(Icons.checklist_rtl_rounded, size: 20),
                label: const Text('Seleccionar'),
                onPressed: () => _enterSelectionMode(null),
              ),
            if (_isSelectionMode) ...[
              IconButton(
                key: const Key('btn_toggle_seleccionar_todos'),
                icon: Icon(
                  _selectedGastoUuids.length == receipts.length
                      ? Icons.deselect_outlined
                      : Icons.select_all_outlined,
                ),
                tooltip: _selectedGastoUuids.length == receipts.length
                    ? 'Deseleccionar todos'
                    : 'Seleccionar todos',
                onPressed: () => _toggleSelectAll(receipts),
              ),
              if (_selectedGastoUuids.isNotEmpty)
                IconButton(
                  key: const Key('btn_eliminar_seleccionados_appbar'),
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  tooltip: 'Eliminar fotos seleccionadas',
                  onPressed: () => _confirmarYEliminarSeleccionados(receipts),
                ),
            ],
          ],
        ),
        bottomNavigationBar: _isSelectionMode && _selectedGastoUuids.isNotEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppColors.card,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  child: ElevatedButton.icon(
                    key: const Key('btn_eliminar_seleccionados_bottom'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: Text(
                      'Eliminar ${_selectedGastoUuids.length} ${_selectedGastoUuids.length == 1 ? 'foto' : 'fotos'}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () => _confirmarYEliminarSeleccionados(receipts),
                  ),
                ),
              )
            : null,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Selector de Mes y Año
                const MonthSelectorBar(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                ),

                // Resumen de cantidad
                if (receipts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '${receipts.length} ${receipts.length == 1 ? 'comprobante guardado' : 'comprobantes guardados'}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        if (!_isSelectionMode)
                          const Text(
                            'Mantén para seleccionar',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),

                // Contenido principal
                Expanded(
                  child: receipts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay comprobantes en $mesNombre $anio',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Las facturas escaneadas o fotos que adjuntes a tus gastos aparecerán organizadas aquí.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 0.72,
                          ),
                          itemCount: receipts.length,
                          itemBuilder: (context, index) {
                            final gasto = receipts[index];
                            final file = File(gasto.rutaFotoLocal!);
                            final isSelected = _selectedGastoUuids.contains(gasto.uuid);

                            final formattedAmount = () {
                              final tasa = gasto.tasaCambio > 0 ? gasto.tasaCambio : 1.0;
                              return CurrencyFormatter.formatPreferido(
                                gasto.totalUsdDisplay,
                                gasto.moneda == 'VES' ? gasto.totalOriginalDisplay : null,
                                tasa,
                                settings.monedaPrincipal,
                                tasaEur: settings.tasaCambioVesEur,
                                tasaUsdt: settings.tasaCambioVesUsdt,
                              );
                            }();

                            return Material(
                              color: AppColors.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: isSelected ? AppColors.primaryDark : AppColors.border,
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    _enterSelectionMode(gasto);
                                  } else {
                                    _toggleSelection(gasto);
                                  }
                                },
                                onTap: () {
                                  if (_isSelectionMode) {
                                    _toggleSelection(gasto);
                                  } else {
                                    ReceiptViewerDialog.show(
                                      context,
                                      imagePath: gasto.rutaFotoLocal!,
                                      title: gasto.comercio,
                                      subtitle: DateFormatter.formatDate(gasto.fecha),
                                      amount: formattedAmount,
                                      gasto: gasto,
                                    ).then((_) {
                                      if (mounted) {
                                        final currentGastos = Provider.of<GastoProvider>(context, listen: false).gastos;
                                        _filterReceiptsAsync(currentGastos);
                                      }
                                    });
                                  }
                                },
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Imagen de fondo
                                    Image.file(
                                      file,
                                      fit: BoxFit.cover,
                                    ),
                                    // Overlay cuando está seleccionado
                                    if (isSelected)
                                      Container(
                                        color: Colors.black.withOpacity(0.35),
                                      ),
                                    // Degradado inferior para legibilidad
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black87,
                                              Colors.black54,
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              gasto.comercio,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              formattedAmount,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                            Text(
                                              DateFormatter.formatDate(gasto.fecha),
                                              style: const TextStyle(
                                                color: Colors.white70,
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Indicador superior derecho: Checkbox en modo selección o Lupa en modo normal
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: _isSelectionMode
                                          ? AnimatedContainer(
                                              duration: const Duration(milliseconds: 150),
                                              width: 26,
                                              height: 26,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: isSelected ? AppColors.primaryDark : Colors.black45,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 16,
                                                      color: Colors.black,
                                                    )
                                                  : null,
                                            )
                                          : Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.black45,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: const Icon(
                                                Icons.fullscreen,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
