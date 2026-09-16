import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../data/models/item_gasto_model.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/image_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../providers/scan_queue_provider.dart';

class ReviewExpenseScreen extends StatefulWidget {
  final File? imageFile;
  final GeminiExtractionResult? extractedData;
  final GastoModel? existingGasto;
  final int? queueItemId;

  const ReviewExpenseScreen({
    Key? key,
    this.imageFile,
    this.extractedData,
    this.existingGasto,
    this.queueItemId,
  }) : super(key: key);

  @override
  State<ReviewExpenseScreen> createState() => _ReviewExpenseScreenState();
}

class _ReviewExpenseScreenState extends State<ReviewExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _comercioCtrl;
  late TextEditingController _totalOriginalCtrl;
  late TextEditingController _tasaCambioCtrl;
  late TextEditingController _totalUsdCtrl;

  late String _selectedFecha;
  late String _selectedMoneda;

  String _formatDouble(double value) {
    if (value == 0) return '';
    return value.truncateToDouble() == value ? value.toInt().toString() : value.toString();
  }
  late List<ItemGastoModel> _items;
  String _fuenteTasa = 'Tasa oficial BCV automática';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (widget.existingGasto != null) {
      final gasto = widget.existingGasto!;
      _comercioCtrl = TextEditingController(text: gasto.comercio);
      _selectedFecha = gasto.fecha;
      _selectedMoneda = gasto.moneda;
      _items = List.from(gasto.items);
      _totalOriginalCtrl = TextEditingController(text: _formatDouble(gasto.totalOriginal));
      _totalUsdCtrl = TextEditingController(text: gasto.totalUsd.toStringAsFixed(2));
      
      double tasa = 0;
      if (gasto.moneda == 'VES' && gasto.totalUsd > 0) {
        tasa = gasto.totalOriginal / gasto.totalUsd;
      }
      _tasaCambioCtrl = TextEditingController(text: tasa.toStringAsFixed(2));
      _fuenteTasa = 'Tasa histórica del gasto';
    } else {
      final data = widget.extractedData!;
      _comercioCtrl = TextEditingController(text: data.comercio);
      _selectedFecha = data.fecha;
      _selectedMoneda = data.moneda;
      _items = List.from(data.items);

      _totalOriginalCtrl = TextEditingController(text: _formatDouble(data.totalOriginal));

      double tasaInicial = data.tasaCambioDetectada ?? settings.tasaCambioVesUsd;
      _tasaCambioCtrl = TextEditingController(text: tasaInicial.toStringAsFixed(2));

      if (data.tasaCambioDetectada != null && data.tasaCambioDetectada! > 0) {
        _fuenteTasa = 'Tasa detectada en la factura';
      } else {
        _fuenteTasa = 'Buscando tasa de la fecha...';
        if (_selectedMoneda == 'VES') {
          _actualizarTasaPorFecha(_selectedFecha);
        }
      }

      double totalUsdCalculado;
      if (_selectedMoneda == 'USD') {
        totalUsdCalculado = data.totalOriginal;
      } else if (_selectedMoneda == 'VES') {
        totalUsdCalculado = tasaInicial > 0 ? (data.totalOriginal / tasaInicial) : data.totalOriginal;
      } else {
        totalUsdCalculado = data.totalOriginal;
      }
      _totalUsdCtrl = TextEditingController(text: totalUsdCalculado.toStringAsFixed(2));
    }
    
    // Verificar precios anteriores para los items recien cargados
    _verificarPreciosAnteriores();
  }

  Map<int, Map<String, dynamic>> _priceComparisons = {};

  Future<void> _verificarPreciosAnteriores() async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    for (int i = 0; i < _items.length; i++) {
      final desc = _items[i].descripcion;
      if (desc.trim().length > 3) { // Ignorar muy cortos
        final previo = await gastoProvider.buscarPrecioAnterior(desc);
        if (previo != null && mounted) {
          setState(() {
            _priceComparisons[i] = previo;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _comercioCtrl.dispose();
    _totalOriginalCtrl.dispose();
    _tasaCambioCtrl.dispose();
    _totalUsdCtrl.dispose();
    super.dispose();
  }

  void _recalcularTotalUsd() {
    final original = double.tryParse(_totalOriginalCtrl.text) ?? 0.0;
    if (_selectedMoneda == 'USD') {
      _totalUsdCtrl.text = original.toStringAsFixed(2);
    } else if (_selectedMoneda == 'VES') {
      final tasa = double.tryParse(_tasaCambioCtrl.text) ?? 1.0;
      final enUsd = tasa > 0 ? (original / tasa) : original;
      _totalUsdCtrl.text = enUsd.toStringAsFixed(2);
    } else {
      _totalUsdCtrl.text = original.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _recalcularTotal() {
    double sum = 0.0;
    for (var item in _items) {
      sum += item.total;
    }
    if (sum > 0) {
      _totalOriginalCtrl.text = _formatDouble(sum);
      _recalcularTotalUsd();
    }
  }

  Future<void> _actualizarTasaPorFecha(String fecha) async {
    if (_selectedMoneda != 'VES') return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    setState(() {
      _fuenteTasa = 'Buscando tasa del $fecha...';
    });

    final tasa = await ExchangeRateService.getRateForDate(fecha, tipo: settings.tipoTasa);
    if (mounted && _selectedMoneda == 'VES') {
      setState(() {
        _tasaCambioCtrl.text = tasa.toStringAsFixed(2);
        final today = DateTime.now().toIso8601String().substring(0, 10);
        _fuenteTasa = (fecha == today)
            ? 'Tasa oficial BCV (Hoy)'
            : 'Tasa oficial BCV ($fecha)';
        _recalcularTotalUsd();
      });
    }
  }

  Future<void> _selectDate() async {
    final initialDate = DateTime.tryParse(_selectedFecha) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.card,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final nuevaFecha = DateFormatter.toIsoDate(picked);
      setState(() {
        _selectedFecha = nuevaFecha;
      });
      // Si la factura no traía tasa fija impresa, busca la tasa correspondiente a la fecha elegida
      if (widget.existingGasto == null && (widget.extractedData?.tasaCambioDetectada == null || widget.extractedData!.tasaCambioDetectada! <= 0)) {
        _actualizarTasaPorFecha(nuevaFecha);
      }
    }
  }

  void _addItem() {
    setState(() {
      _items.add(ItemGastoModel(
        descripcion: '',
        cantidad: 1.0,
        precioUnitario: 0.0,
        total: 0.0,
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _guardarGasto() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);

    String? rutaFotoFinal;
    if (widget.existingGasto != null) {
      rutaFotoFinal = widget.existingGasto!.rutaFotoLocal;
      if (widget.imageFile != null && settings.guardarFotos) {
        rutaFotoFinal = await ImageService.saveImagePermanently(widget.imageFile!);
      }
    } else {
      if (settings.guardarFotos && widget.imageFile != null) {
        rutaFotoFinal = await ImageService.saveImagePermanently(widget.imageFile!);
      } else if (widget.imageFile != null) {
        await ImageService.deleteTempFile(widget.imageFile!);
      }
    }

    final totalOrig = double.tryParse(_totalOriginalCtrl.text) ?? 0.0;
    final totalUsd = double.tryParse(_totalUsdCtrl.text) ?? 0.0;

    final nuevoGasto = GastoModel(
      id: widget.existingGasto?.id,
      fecha: _selectedFecha,
      comercio: _comercioCtrl.text.trim(),
      moneda: _selectedMoneda,
      totalOriginal: totalOrig,
      totalUsd: totalUsd,
      categoria: _items.isNotEmpty ? _items.first.categoria : 'Otros',
      rutaFotoLocal: rutaFotoFinal,
      creadoEn: widget.existingGasto?.creadoEn ?? DateTime.now().toIso8601String(),
    );

      bool success;
      if (widget.existingGasto != null) {
        success = await gastoProvider.actualizarGasto(nuevoGasto, _items);
      } else {
        final matchedIds = widget.extractedData?.matchedShoppingItemIds ?? [];
        success = await gastoProvider.agregarGasto(nuevoGasto, _items, shoppingItemIds: matchedIds);
      }
  
      if (!mounted) return;
      setState(() => _isSaving = false);
  
      if (success) {
        // Si venía de la cola offline, lo borramos de ahí
        if (widget.queueItemId != null) {
          final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
          await queueProvider.removeItem(widget.queueItemId!);
        }

        final user = FirebaseAuth.instance.currentUser;
        final isAnon = user == null || user.isAnonymous;

        if (isAnon && widget.existingGasto == null) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: AppColors.card,
              title: const Row(
                children: [
                  Icon(Icons.cloud_done_outlined, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Compra registrada',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                ],
              ),
              content: const Text(
                'Tu compra quedó registrada. Vincula tu cuenta de Google para no perderla si cambias de teléfono.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Ahora no', style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Vincular con Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.secondary,
                  ),
                  onPressed: () async {
                    final error = await Provider.of<GastoProvider>(context, listen: false).vincularCuentaGoogle();
                    if (!mounted) return;
                    if (error != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $error')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cuenta vinculada con éxito', style: TextStyle(color: Colors.black)),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        } else {
          final matchedIds = widget.extractedData?.matchedShoppingItemIds ?? [];
          if (matchedIds.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Gasto registrado y ${matchedIds.length} ítem(s) de tu lista marcados como comprados.'),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Gasto registrado con éxito'),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          }
        }

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gastoProvider.errorMessage ?? 'Error al guardar'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

    @override
    Widget build(BuildContext context) {
      return Scaffold(

      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _isSaving ? null : _guardarGasto,
            child: _isSaving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                : const Text('Guardar Gasto', style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
        ),
      ),
      appBar: AppBar(
          title: const Text('Revisar y Confirmar'),
          actions: [
            if (widget.queueItemId != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                tooltip: 'Descartar Factura',
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.card,
                      title: const Text('Descartar Factura', style: TextStyle(color: AppColors.textPrimary)),
                      content: const Text('¿Seguro que deseas descartar esta factura escaneada? No se guardará en tu historial.', style: TextStyle(color: AppColors.textSecondary)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Descartar', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
                    await queueProvider.removeItem(widget.queueItemId!);
                    if (!mounted) return;
                    Navigator.pop(context);
                  }
                },
              ),
          ],
        ),
        body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageHeader(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Información General',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _comercioCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Comercio o Beneficiario',
                      prefixIcon: Icon(Icons.storefront_outlined, color: AppColors.textSecondary),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de Emisión',
                        prefixIcon: Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary),
                      ),
                      child: Text(
                        DateFormatter.formatDate(_selectedFecha),
                        style: const TextStyle(color: AppColors.textPrimary),
                      ),
                    ),
                  ),

                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
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
                      const Text(
                        'Desglose de Ítems',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, size: 16, color: AppColors.primaryDark),
                        label: const Text('Agregar', style: TextStyle(color: AppColors.textPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No hay ítems detallados.', style: TextStyle(color: AppColors.textMuted)),
                    )
                  else
                      ..._items.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        
                        Widget? priceWarning;
                        if (_priceComparisons.containsKey(idx)) {
                          final prevData = _priceComparisons[idx]!;
                          final prevUsd = prevData['precio_usd'] as double;
                          final prevFecha = prevData['fecha'] as String;
                          final prevComercio = prevData['comercio'] as String;
                          
                          double currentUsd = item.precioUnitario;
                          if (_selectedMoneda == 'VES') {
                            final tasa = double.tryParse(_tasaCambioCtrl.text.replaceAll(',', '.')) ?? 1.0;
                            if (tasa > 0) currentUsd = currentUsd / tasa;
                          }

                          if (currentUsd > (prevUsd * 1.05)) { // 5% de tolerancia
                            final diff = ((currentUsd / prevUsd) - 1) * 100;
                            priceWarning = Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                '🔺 Está ${diff.toStringAsFixed(0)}% más caro que en $prevComercio',
                                style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            );
                          } else if (currentUsd < (prevUsd * 0.95)) {
                            final diff = (1 - (currentUsd / prevUsd)) * 100;
                            priceWarning = Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                '🟢 Te salió un ${diff.toStringAsFixed(0)}% más económico que en $prevComercio',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          elevation: 0,
                          color: AppColors.surface,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: item.descripcion,
                                        decoration: const InputDecoration(
                                          labelText: 'Descripción del Producto',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        onChanged: (v) => _items[idx] = _items[idx].copyWith(descripcion: v),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                      onPressed: () => _removeItem(idx),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: _formatDouble(item.cantidad),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Cant.',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        onChanged: (v) {
                                          final cant = double.tryParse(v) ?? 1.0;
                                          _items[idx] = _items[idx].copyWith(
                                            cantidad: cant,
                                            total: cant * _items[idx].precioUnitario,
                                          );
                                          _recalcularTotal();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: _formatDouble(item.precioUnitario),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Precio',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        onChanged: (v) {
                                          final prec = double.tryParse(v) ?? 0.0;
                                          _items[idx] = _items[idx].copyWith(
                                            precioUnitario: prec,
                                            total: _items[idx].cantidad * prec,
                                          );
                                          _recalcularTotal();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        key: ValueKey('total_$idx\_${_items[idx].total}'),
                                        initialValue: _formatDouble(_items[idx].total),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Total',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        onChanged: (v) {
                                          final tot = double.tryParse(v) ?? 0.0;
                                          final cant = _items[idx].cantidad;
                                          _items[idx] = _items[idx].copyWith(
                                            total: tot,
                                            precioUnitario: cant > 0 ? tot / cant : 0.0,
                                          );
                                          _recalcularTotal();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: AppConstants.categorias.contains(item.categoria) ? item.categoria : 'Otros',
                                  decoration: const InputDecoration(
                                    labelText: 'Categoría',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  dropdownColor: AppColors.surface,
                                  items: AppConstants.categorias.map((cat) {
                                    return DropdownMenuItem(value: cat, child: Text(cat, overflow: TextOverflow.ellipsis));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _items[idx] = _items[idx].copyWith(categoria: val);
                                      });
                                    }
                                  },
                                ),
                                if (priceWarning != null) ...[
                                  const SizedBox(height: 8),
                                  priceWarning,
                                ],
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monto Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  const Text('Moneda', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: AppConstants.monedas.map((m) {
                        return ButtonSegment<String>(
                          value: m,
                          label: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
                        );
                      }).toList(),
                      selected: {_selectedMoneda},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedMoneda = newSelection.first;
                          _recalcularTotalUsd();
                        });
                      },
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return AppColors.secondary;
                            }
                            return AppColors.surface;
                          },
                        ),
                        foregroundColor: MaterialStateProperty.resolveWith<Color>(
                          (Set<MaterialState> states) {
                            if (states.contains(MaterialState.selected)) {
                              return Colors.white;
                            }
                            return AppColors.textPrimary;
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _totalOriginalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Monto Original ($_selectedMoneda)',
                      prefixIcon: const Icon(Icons.payments_outlined, color: AppColors.textSecondary),
                    ),
                    onChanged: (_) => _recalcularTotalUsd(),
                    validator: (val) => (double.tryParse(val ?? '') == null) ? 'Inválido' : null,
                  ),
                  if (_selectedMoneda == 'VES') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _tasaCambioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Tasa de Cambio (VES / USD)',
                        prefixIcon: const Icon(Icons.currency_exchange, color: AppColors.textSecondary),
                        helperText: _fuenteTasa,
                        helperStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 11),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.sync, color: AppColors.primaryDark, size: 20),
                          tooltip: 'Sincronizar tasa BCV de hoy',
                          onPressed: () async {
                            final settings = Provider.of<SettingsProvider>(context, listen: false);
                            final tasa = await ExchangeRateService.getTodayRate(tipo: settings.tipoTasa);
                            setState(() {
                              _tasaCambioCtrl.text = tasa.toStringAsFixed(2);
                              _fuenteTasa = 'Tasa oficial BCV sincronizada';
                              _recalcularTotalUsd();
                            });
                          },
                        ),
                      ),
                      onChanged: (_) => _recalcularTotalUsd(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _totalUsdCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Total Equivalente (USD)',
                      prefixIcon: Icon(Icons.attach_money, color: AppColors.primaryDark),
                    ),
                    validator: (val) => (double.tryParse(val ?? '') == null) ? 'Inválido' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _verImagenCompleta(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
            title: const Text('Comprobante', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.file(file),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageHeader() {
    File? fileToShow;
    if (widget.imageFile != null) {
      fileToShow = widget.imageFile;
    } else {
      final existingRuta = widget.existingGasto?.rutaFotoLocal;
      if (existingRuta != null) {
        final file = File(existingRuta);
        if (file.existsSync()) {
          fileToShow = file;
        }
      }
    }

    Widget imageWidget;
    if (fileToShow != null) {
      imageWidget = Image.file(fileToShow, fit: BoxFit.cover);
    } else if (widget.existingGasto?.rutaFotoLocal != null) {
      imageWidget = const Center(child: Icon(Icons.image_not_supported, color: AppColors.textMuted, size: 48));
    } else {
      imageWidget = const Center(child: Icon(Icons.receipt_long, color: AppColors.textMuted, size: 48));
    }

    final header = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            if (fileToShow != null)
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Tocar para ampliar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (fileToShow != null) {
      return GestureDetector(
        onTap: () => _verImagenCompleta(fileToShow!),
        child: header,
      );
    }

    return header;
  }
}
