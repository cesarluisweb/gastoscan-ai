import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late String _selectedCategoria;

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
      _selectedCategoria = gasto.categoria;
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
      _selectedCategoria = data.categoriaSugerida;
      _items = List.from(data.items);

      _totalOriginalCtrl = TextEditingController(text: _formatDouble(data.totalOriginal));

      double tasaInicial = data.tasaCambioDetectada ?? settings.tasaCambioVesUsd;
      _tasaCambioCtrl = TextEditingController(text: tasaInicial.toStringAsFixed(2));

      if (data.tasaCambioDetectada != null && data.tasaCambioDetectada! > 0) {
        _fuenteTasa = 'Tasa detectada en el comprobante';
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
      // Si la factura no traÃ­a tasa fija impresa, busca la tasa correspondiente a la fecha elegida
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
      categoria: _selectedCategoria,
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
        // Si venÃ­a de la cola offline, lo borramos de ahÃ­
        if (widget.queueItemId != null) {
          final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
          await queueProvider.removeItem(widget.queueItemId!);
        }

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
        Navigator.pop(context);
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedCategoria,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      prefixIcon: Icon(Icons.category_outlined, color: AppColors.textSecondary),
                    ),
                    dropdownColor: AppColors.surface,
                    items: AppConstants.categorias.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategoria = val);
                    },
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
                  const Text(
                    'Montos y Conversión',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedMoneda,
                          decoration: const InputDecoration(labelText: 'Moneda'),
                          dropdownColor: AppColors.surface,
                          items: AppConstants.monedas.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              _selectedMoneda = val;
                              _recalcularTotalUsd();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _totalOriginalCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Monto Original'),
                          onChanged: (_) => _recalcularTotalUsd(),
                          validator: (val) => (double.tryParse(val ?? '') == null) ? 'Inválido' : null,
                        ),
                      ),
                    ],
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
                        helperStyle: const TextStyle(color: AppColors.primary, fontSize: 11),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.sync, color: AppColors.primary, size: 20),
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
                      prefixIcon: Icon(Icons.attach_money, color: AppColors.primary),
                    ),
                    validator: (val) => (double.tryParse(val ?? '') == null) ? 'Inválido' : null,
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
                        icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                        label: const Text('Agregar', style: TextStyle(color: AppColors.primary)),
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
                                style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            );
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      initialValue: item.descripcion,
                                      decoration: const InputDecoration(
                                        labelText: 'Desc.',
                                        hintText: 'Concepto',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      ),
                                      onChanged: (v) => _items[idx] = _items[idx].copyWith(descripcion: v),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: _formatDouble(item.cantidad),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Cant.',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      initialValue: _formatDouble(item.precioUnitario),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Precio',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                  const SizedBox(width: 4),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      key: ValueKey('total_$idx\_${_items[idx].total}'),
                                      initialValue: _formatDouble(_items[idx].total),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        labelText: 'Total',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 20),
                                    onPressed: () => _removeItem(idx),
                                  ),
                                ],
                              ),
                              if (priceWarning != null) priceWarning,
                            ],
                          ),
                        );
                      }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _guardarGasto,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('Guardar Gasto'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildImageHeader() {
    Widget imageWidget;
    if (widget.imageFile != null) {
      imageWidget = Image.file(widget.imageFile!, fit: BoxFit.cover);
    } else if (widget.existingGasto?.rutaFotoLocal != null) {
      final file = File(widget.existingGasto!.rutaFotoLocal!);
      if (file.existsSync()) {
        imageWidget = Image.file(file, fit: BoxFit.cover);
      } else {
        imageWidget = const Center(child: Icon(Icons.image_not_supported, color: AppColors.textMuted, size: 48));
      }
    } else {
      imageWidget = const Center(child: Icon(Icons.receipt_long, color: AppColors.textMuted, size: 48));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        width: double.infinity,
        color: Colors.black,
        child: imageWidget,
      ),
    );
  }
}
