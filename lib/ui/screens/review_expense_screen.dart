import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/amount_parser.dart';
import '../../core/utils/date_formatter.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/models/gasto_model.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../data/models/item_gasto_model.dart';
import '../../providers/gasto_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/image_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../providers/scan_queue_provider.dart';
import '../../core/utils/uuid_generator.dart';
import '../widgets/receipt_viewer_dialog.dart';
import '../widgets/auth_modal_sheet.dart';

enum MetodoLiquidacionUsd {
  pagadoEnBsBcv,
  pagadoEnBsUsdt,
  pagadoEnDivisa,
}

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
  late TextEditingController _tasaEurCtrl;
  late TextEditingController _totalUsdCtrl;
  late TextEditingController _tasaUsdtCtrl;
  late TextEditingController _totalBsManualCtrl;
  String _monedaTasaSeleccionadaVes = 'USD';
  double? _tasaOficialUsd;
  double? _tasaOficialEur;
  double? _tasaOficialUsdt;
  bool _bolivaresAjustadosManualmente = false;
  MetodoLiquidacionUsd _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnBsBcv;

  late String _selectedFecha;
  late String _selectedMoneda;

  File? _pickedImage;
  bool _imageDeleted = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        setState(() {
          _pickedImage = File(pickedFile.path);
          _imageDeleted = false;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  String _formatDouble(double value) {
    if (value == 0) return '';
    final rounded = (value * 100).round() / 100.0;
    return rounded.truncateToDouble() == rounded ? rounded.toInt().toString() : rounded.toString();
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .trim();
  }
  late List<ItemGastoModel> _items;
  String _fuenteTasa = 'Tasa oficial BCV automática';
  bool _isSaving = false;
  double? _tasaUsdFecha;
  double? _tasaEurFecha;
  double? _tasaUsdtFecha;
  bool _esTasaHistoricaExacta = false;
  bool _esTasaEurExacta = false;
  bool _esTasaUsdtExacta = false;

  String _initialComercio = '';
  String _initialFecha = '';
  String _initialMoneda = '';
  double _initialTotalOriginal = 0.0;
  double _initialTasa = 0.0;
  double _initialRateForItems = 1.0;
  List<ItemGastoModel>? _initialItems;
  bool _initialHasImage = false;
  String _initialTotalUsdStr = '';

  bool _isDirty() {
    if (_isSaving) return false;
    if (_comercioCtrl.text.trim() != _initialComercio.trim()) return true;
    if (_selectedFecha != _initialFecha) return true;
    if (_selectedMoneda != _initialMoneda) return true;
    if (double.tryParse(_totalOriginalCtrl.text.replaceAll(',', '.')) != _initialTotalOriginal) return true;
    if (double.tryParse(_tasaCambioCtrl.text.replaceAll(',', '.')) != _initialTasa) return true;
    if ((_pickedImage != null && !_initialHasImage) || (_imageDeleted && _initialHasImage)) return true;
    if (_totalUsdCtrl.text != _initialTotalUsdStr) return true;
    final initial = _initialItems;
    if (initial != null) {
      if (initial.length != _items.length) return true;
      for (int i = 0; i < _items.length; i++) {
        final a = initial[i];
        final b = _items[i];
        if (a.descripcion != b.descripcion ||
            a.cantidad != b.cantidad ||
            a.precioUnitario != b.precioUnitario ||
            a.total != b.total ||
            a.categoria != b.categoria) return true;
      }
    } else {
      if (_items.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> _cargarTasasChips(String fecha) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    double tUsd;
    double tEur;
    double tUsdt;
    bool esUsdExacta = false;
    bool esEurExacta = false;
    bool esUsdtExacta = false;

    final isToday = fecha.isEmpty || fecha == today;
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (isToday) {
      final allRates = await ExchangeRateService.getAllTodayRates();
      tUsd = allRates.usd;
      tEur = allRates.eur;
      tUsdt = allRates.usdt;
      if (tUsd <= 50.0 && settings.tasaCambioVesUsd > 50.0) {
        tUsd = settings.tasaCambioVesUsd;
      }
      if (tEur <= 50.0 && settings.tasaCambioVesEur > 50.0) {
        tEur = settings.tasaCambioVesEur;
      }
      if (tUsdt <= 50.0 && settings.tasaCambioVesUsdt > 50.0) {
        tUsdt = settings.tasaCambioVesUsdt;
      }
      esUsdExacta = !allRates.esReferencia;
      esEurExacta = !allRates.esReferencia;
      esUsdtExacta = !allRates.esReferencia;
    } else {
      final results = await Future.wait([
        ExchangeRateService.getRateForDate(fecha, moneda: 'USD'),
        ExchangeRateService.getRateForDate(fecha, moneda: 'EUR'),
        ExchangeRateService.getRateForDate(fecha, moneda: 'USDT'),
      ]);
      tUsd = results[0];
      tEur = results[1];
      tUsdt = results[2];

      esUsdExacta = tUsd > 0;
      esEurExacta = tEur > 0;
      // DolarAPI histórico continuo de paralelo inicia el 14 de febrero de 2026
      esUsdtExacta = tUsdt > 0 && fecha.compareTo('2026-02-14') >= 0;

      // Fallback pragmático local-first si no hay red o histórico para esa fecha
      if (tUsd <= 0 && settings.tasaCambioVesUsd > 0) {
        tUsd = settings.tasaCambioVesUsd;
      }
      if (tEur <= 0 && settings.tasaCambioVesEur > 0) {
        tEur = settings.tasaCambioVesEur;
      }
      if (tUsdt <= 0 && settings.tasaCambioVesUsdt > 0) {
        tUsdt = settings.tasaCambioVesUsdt;
      }
    }

    if (mounted && _selectedFecha == fecha) {
      setState(() {
        _tasaUsdFecha = tUsd > 0.0 ? tUsd : null;
        _tasaEurFecha = tEur > 0.0 ? tEur : null;
        _tasaUsdtFecha = tUsdt > 0.0 ? tUsdt : null;
        _tasaOficialUsd = _tasaUsdFecha;
        _tasaOficialEur = _tasaEurFecha;
        _tasaOficialUsdt = _tasaUsdtFecha;
        _esTasaHistoricaExacta = esUsdExacta;
        _esTasaEurExacta = esEurExacta;
        _esTasaUsdtExacta = esUsdtExacta;
        if (tUsdt > 0.0 && _tasaUsdtCtrl.text.isEmpty) {
          _tasaUsdtCtrl.text = tUsdt.toStringAsFixed(2);
        }
        if (tEur > 0.0 && _tasaEurCtrl.text.isEmpty) {
          _tasaEurCtrl.text = tEur.toStringAsFixed(2);
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final double? existingTasaUsdt = widget.existingGasto?.tasaUsdt;
    final double defaultUsdt = (existingTasaUsdt != null && existingTasaUsdt > 0)
        ? existingTasaUsdt
        : settings.tasaCambioVesUsdt;
    _tasaUsdtCtrl = TextEditingController(text: defaultUsdt > 0 ? defaultUsdt.toStringAsFixed(2) : '');

    final double? existingTasaEur = widget.existingGasto?.tasaEur;
    final double defaultEur = (existingTasaEur != null && existingTasaEur > 0)
        ? existingTasaEur
        : settings.tasaCambioVesEur;
    _tasaEurCtrl = TextEditingController(text: defaultEur > 0 ? defaultEur.toStringAsFixed(2) : '');

    if (widget.existingGasto != null) {
      final gasto = widget.existingGasto!;
      _comercioCtrl = TextEditingController(text: gasto.comercio);
      _selectedFecha = gasto.fecha;

      final String fuente = gasto.fuenteTasaCambio ?? '';
      final bool isIndexedEur = gasto.moneda == 'VES' && fuente.contains('indexado a EUR');
      final bool isIndexedBcv = gasto.moneda == 'VES' &&
          (fuente.contains('indexado a USD') ||
              isIndexedEur ||
              fuente.contains('BCV (Pago en Bs.'));
      final bool isIndexedUsdt = gasto.moneda == 'VES' &&
          (fuente.contains('indexado a USDT') ||
              fuente.contains('Binance P2P'));

      double tasa = gasto.tasaCambio;
      if (tasa <= 0 && gasto.moneda == 'VES' && gasto.totalUsd > 0) {
        tasa = gasto.totalOriginalDisplay / gasto.totalUsdDisplay;
      } else if (gasto.moneda == 'EUR' && gasto.totalOriginalDisplay > 0 && gasto.totalUsdDisplay > 0 && tasa > 0) {
        final matchEur = RegExp(r'Euro BCV \(Bs\.\s*([0-9]+(?:\.[0-9]+)?)\)').firstMatch(fuente);
        if (matchEur != null) {
          tasa = double.tryParse(matchEur.group(1)!) ?? ((gasto.totalUsdDisplay * tasa) / gasto.totalOriginalDisplay);
        } else {
          tasa = (gasto.totalUsdDisplay * tasa) / gasto.totalOriginalDisplay;
        }
      }
      _tasaCambioCtrl = TextEditingController(text: tasa.toStringAsFixed(2));
      _fuenteTasa = gasto.fuenteTasaCambio ?? 'Tasa histórica del gasto';

      if (isIndexedBcv || isIndexedUsdt) {
        _selectedMoneda = isIndexedEur ? 'EUR' : 'USD';
        _metodoLiquidacionUsd = isIndexedUsdt
            ? MetodoLiquidacionUsd.pagadoEnBsUsdt
            : MetodoLiquidacionUsd.pagadoEnBsBcv;
        final double indexedAmount = isIndexedUsdt
            ? gasto.totalUsdtDisplay
            : (isIndexedEur && tasa > 0
                ? (gasto.totalOriginalDisplay / tasa)
                : gasto.totalUsdDisplay);
        _totalOriginalCtrl = TextEditingController(text: _formatDouble(indexedAmount));
        _totalBsManualCtrl = TextEditingController(text: gasto.totalOriginalDisplay.toStringAsFixed(2));
        _bolivaresAjustadosManualmente = true;
        _totalUsdCtrl = TextEditingController(text: gasto.totalUsdDisplay.toStringAsFixed(2));
        if (isIndexedEur) {
          _tasaEurFecha = tasa > 0 ? tasa : null;
        } else {
          _tasaUsdFecha = tasa > 0 ? tasa : null;
        }
        if (gasto.tasaUsdt != null && gasto.tasaUsdt! > 0) {
          _tasaUsdtFecha = gasto.tasaUsdt;
        }

        final double rateForItems = isIndexedUsdt
            ? ((gasto.tasaUsdt != null && gasto.tasaUsdt! > 0)
                ? gasto.tasaUsdt!
                : (indexedAmount > 0 ? (gasto.totalOriginalDisplay / indexedAmount) : tasa))
            : (tasa > 0 ? tasa : (indexedAmount > 0 ? (gasto.totalOriginalDisplay / indexedAmount) : 1.0));
        _initialRateForItems = rateForItems;
        _items = gasto.items.map((it) {
          final usdPrice = rateForItems > 0 ? (it.precioUnitarioDisplay / rateForItems) : it.precioUnitarioDisplay;
          final usdTotal = rateForItems > 0 ? (it.totalDisplay / rateForItems) : it.totalDisplay;
          return it.copyWith(
            precioUnitario: (usdPrice * 100).round(),
            total: (usdTotal * 100).round(),
          );
        }).toList();
      } else {
        _selectedMoneda = gasto.moneda;
        _items = List.from(gasto.items);
        _totalOriginalCtrl = TextEditingController(text: _formatDouble(gasto.totalOriginalDisplay));
        _totalBsManualCtrl = TextEditingController(text: gasto.totalOriginalDisplay.toStringAsFixed(2));
        _totalUsdCtrl = TextEditingController(text: gasto.totalUsdDisplay.toStringAsFixed(2));
        if (gasto.moneda == 'EUR') {
          _tasaEurFecha = tasa > 0 ? tasa : null;
        } else {
          _tasaUsdFecha = tasa > 0 ? tasa : null;
        }
        if (gasto.tasaUsdt != null && gasto.tasaUsdt! > 0) {
          _tasaUsdtFecha = gasto.tasaUsdt;
        }

        if (gasto.moneda == 'USD' || gasto.moneda == 'EUR') {
          _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnDivisa;
        } else {
          _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnBsBcv;
        }
      }
    } else {
      final data = widget.extractedData;
      _comercioCtrl = TextEditingController(text: data?.comercio ?? '');
      _selectedFecha = data?.fecha ?? DateTime.now().toIso8601String().substring(0, 10);
      _selectedMoneda = data?.moneda ?? 'USD';
      _items = List.from(data?.items ?? []);
      _totalBsManualCtrl = TextEditingController();

      if (data?.metodoLiquidacion != null) {
        switch (data!.metodoLiquidacion!) {
          case 'BS_BCV':
            _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnBsBcv;
            break;
          case 'BS_USDT':
            _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnBsUsdt;
            break;
          case 'DIVISA':
            _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnDivisa;
            break;
          default:
            _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnBsBcv;
            break;
        }
      } else {
        _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnBsBcv;
      }

      if (_items.isEmpty) {
        _items.add(ItemGastoModel(
          descripcion: '',
          cantidad: 1.0,
          precioUnitario: 0,
          total: 0,
          categoria: 'Otros',
        ));
      }

      final double totalOriginalVal = data?.totalOriginal ?? 0.0;
      _totalOriginalCtrl = TextEditingController(text: _formatDouble(totalOriginalVal));

      double tasaInicial = data?.tasaCambioDetectada ??
          (_selectedMoneda == 'EUR'
              ? (settings.tasaCambioVesEur > 0 ? settings.tasaCambioVesEur : settings.tasaCambioVesUsd)
              : settings.tasaCambioVesUsd);
      _tasaCambioCtrl = TextEditingController(text: tasaInicial.toStringAsFixed(2));

      double totalUsdCalculado;
      if (_selectedMoneda == 'USD') {
        totalUsdCalculado = totalOriginalVal;
      } else if (_selectedMoneda == 'VES') {
        totalUsdCalculado = tasaInicial > 0 ? (totalOriginalVal / tasaInicial) : totalOriginalVal;
      } else if (_selectedMoneda == 'EUR') {
        final tasaEur = tasaInicial > 0 ? tasaInicial : settings.tasaCambioVesEur;
        final tasaUsd = settings.tasaCambioVesUsd;
        final eurToUsdRatio = (tasaUsd > 0 && tasaEur > 0) ? (tasaEur / tasaUsd) : 1.0;
        totalUsdCalculado = totalOriginalVal * eurToUsdRatio;
      } else {
        totalUsdCalculado = totalOriginalVal;
      }
      _totalUsdCtrl = TextEditingController(text: totalUsdCalculado > 0 ? totalUsdCalculado.toStringAsFixed(2) : '');
      final double totalBsInicial = totalOriginalVal * (tasaInicial > 0 ? tasaInicial : 1.0);
      _totalBsManualCtrl.text = totalBsInicial > 0 ? totalBsInicial.toStringAsFixed(2) : '';

      if (data?.tasaCambioDetectada != null && data!.tasaCambioDetectada! > 0) {
        _fuenteTasa = 'Tasa detectada en la factura';
        _tasaUsdFecha = data.tasaCambioDetectada;
      } else {
        _fuenteTasa = 'Buscando tasa de la fecha...';
        _actualizarTasaPorFecha(_selectedFecha, esRellenoInicial: true);
      }
    }
    
    // Verificar precios anteriores para los items recien cargados

    _initialComercio = _comercioCtrl.text;
    _initialFecha = _selectedFecha;
    _initialMoneda = _selectedMoneda;
    _initialTotalOriginal = double.tryParse(_totalOriginalCtrl.text.replaceAll(',', '.')) ?? 0.0;
    _initialTasa = double.tryParse(_tasaCambioCtrl.text.replaceAll(',', '.')) ?? 0.0;
    _initialItems = List.from(_items);
    _initialHasImage = (widget.existingGasto?.rutaFotoLocal != null && !_imageDeleted) ||
        (widget.imageFile != null && !_imageDeleted);
    _initialTotalUsdStr = _totalUsdCtrl.text;
    _verificarPreciosAnteriores();
  }

  Map<int, Map<String, dynamic>> _priceComparisons = {};

  Future<void> _verificarPreciosAnteriores() async {
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
    for (int i = 0; i < _items.length; i++) {
      final desc = _items[i].descripcion;
      if (desc.trim().length > 2 && !DatabaseHelper.isTaxItem(desc)) {
        final previo = await gastoProvider.buscarPrecioAnterior(
          desc,
          excludeGastoId: widget.existingGasto?.id,
        );
        if (previo != null && mounted) {
          setState(() {
            _priceComparisons[i] = previo;
          });
        }
      }
    }
  }

  IconData _getCategoryIcon(String categoria) => AppConstants.getCategoryIcon(categoria);

  double _effectiveBcvRate(SettingsProvider settings) {
    if (_selectedMoneda == 'EUR') {
      if (_tasaEurFecha != null && _tasaEurFecha! > 0) return _tasaEurFecha!;
      final parsed = tryParseAmount(_tasaCambioCtrl.text, isPrice: false) ?? 0.0;
      if (parsed > 0) return parsed;
      return settings.tasaCambioVesEur > 0
          ? settings.tasaCambioVesEur
          : (settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : AppConstants.defaultTasaCambio);
    }
    if (_tasaUsdFecha != null && _tasaUsdFecha! > 0) return _tasaUsdFecha!;
    final parsed = tryParseAmount(_tasaCambioCtrl.text, isPrice: false) ?? 0.0;
    if (parsed > 0) return parsed;
    return settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : (parsed > 0 ? parsed : AppConstants.defaultTasaCambio);
  }

  double get _totalUsdtCalculado {
    final original = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final tasaUsdt = (_tasaUsdtFecha != null && _tasaUsdtFecha! > 0)
        ? _tasaUsdtFecha!
        : (tryParseAmount(_tasaUsdtCtrl.text, isPrice: false) ?? settings.tasaCambioVesUsdt);

    if (_selectedMoneda == 'VES') {
      return tasaUsdt > 0 ? (original / tasaUsdt) : 0.0;
    } else if (_selectedMoneda == 'USD' || _selectedMoneda == 'EUR') {
      if (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsBcv) {
        final manualBs = _bolivaresAjustadosManualmente
            ? tryParseAmount(_totalBsManualCtrl.text, isPrice: false)
            : null;
        final tasaBcv = _effectiveBcvRate(settings);
        final enVes = (manualBs != null && manualBs > 0) ? manualBs : (original * tasaBcv);
        return tasaUsdt > 0 ? (enVes / tasaUsdt) : original;
      } else if (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt) {
        if (_bolivaresAjustadosManualmente) {
          final manualBs = tryParseAmount(_totalBsManualCtrl.text, isPrice: false);
          if (manualBs != null && manualBs > 0 && tasaUsdt > 0) {
            return manualBs / tasaUsdt;
          }
        }
        return original;
      } else {
        // Pagado en divisa directa
        return tryParseAmount(_totalUsdCtrl.text, isPrice: false) ?? original;
      }
    }
    return tryParseAmount(_totalUsdCtrl.text, isPrice: false) ?? original;
  }

  double get _totalEurCalculado {
    final original = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final tasaEur = tryParseAmount(_tasaEurCtrl.text, isPrice: false) ??
        ((_tasaEurFecha != null && _tasaEurFecha! > 0) ? _tasaEurFecha! : settings.tasaCambioVesEur);

    if (_selectedMoneda == 'VES') {
      return tasaEur > 0 ? (original / tasaEur) : 0.0;
    } else if (_selectedMoneda == 'EUR') {
      if (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsBcv ||
          _metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt) {
        final manualBs = _bolivaresAjustadosManualmente
            ? tryParseAmount(_totalBsManualCtrl.text, isPrice: false)
            : null;
        final enVes = (manualBs != null && manualBs > 0) ? manualBs : (original * tasaEur);
        return tasaEur > 0 ? (enVes / tasaEur) : original;
      }
      return original;
    } else if (_selectedMoneda == 'USD' || _selectedMoneda == 'USDT') {
      final tasaBcv = _effectiveBcvRate(settings);
      final enVes = original * (tasaBcv > 0 ? tasaBcv : 1.0);
      return tasaEur > 0 ? (enVes / tasaEur) : original;
    }
    return original;
  }

  @override
  void dispose() {
    _comercioCtrl.dispose();
    _totalOriginalCtrl.dispose();
    _tasaCambioCtrl.dispose();
    _tasaEurCtrl.dispose();
    _totalUsdCtrl.dispose();
    _tasaUsdtCtrl.dispose();
    _totalBsManualCtrl.dispose();
    super.dispose();
  }

  void _recalcularTotalUsd() {
    final original = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    if (_selectedMoneda == 'USD' || _selectedMoneda == 'EUR') {
      final tasaBcv = _effectiveBcvRate(settings);
      final tasaUsdt = (_tasaUsdtFecha != null && _tasaUsdtFecha! > 0)
          ? _tasaUsdtFecha!
          : (tryParseAmount(_tasaUsdtCtrl.text, isPrice: false) ?? settings.tasaCambioVesUsdt);

      if (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsBcv) {
        if (!_bolivaresAjustadosManualmente) {
          final totalBs = original * (tasaBcv > 0 ? tasaBcv : 1.0);
          _totalBsManualCtrl.text = totalBs > 0 ? totalBs.toStringAsFixed(2) : '';
        }
        final manualBs = tryParseAmount(_totalBsManualCtrl.text, isPrice: false);
        if (_bolivaresAjustadosManualmente && manualBs != null && manualBs > 0) {
          final enUsd = tasaBcv > 0 ? (manualBs / tasaBcv) : original;
          _totalUsdCtrl.text = enUsd.toStringAsFixed(2);
        } else {
          _totalUsdCtrl.text = original.toStringAsFixed(2);
        }
      } else if (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt) {
        if (!_bolivaresAjustadosManualmente) {
          final totalBs = original * (tasaUsdt > 0 ? tasaUsdt : 1.0);
          _totalBsManualCtrl.text = totalBs > 0 ? totalBs.toStringAsFixed(2) : '';
        }
        final manualBs = tryParseAmount(_totalBsManualCtrl.text, isPrice: false);
        final finalBs = (_bolivaresAjustadosManualmente && manualBs != null && manualBs > 0)
            ? manualBs
            : (original * (tasaUsdt > 0 ? tasaUsdt : 1.0));
        final enUsdBcv = tasaBcv > 0 ? (finalBs / tasaBcv) : original;
        _totalUsdCtrl.text = enUsdBcv.toStringAsFixed(2);
      } else {
        // Divisa directa
        if (_selectedMoneda == 'EUR') {
          final tasaEur = tasaBcv;
          final tasaUsd = (_tasaUsdFecha != null && _tasaUsdFecha! > 0) ? _tasaUsdFecha! : settings.tasaCambioVesUsd;
          final eurToUsdRatio = (tasaUsd > 0 && tasaEur > 0) ? (tasaEur / tasaUsd) : 1.0;
          _totalUsdCtrl.text = (original * eurToUsdRatio).toStringAsFixed(2);
        } else {
          _totalUsdCtrl.text = original.toStringAsFixed(2);
        }
      }
    } else if (_selectedMoneda == 'VES') {
      final tasa = tryParseAmount(_tasaCambioCtrl.text, isPrice: false) ?? 1.0;
      final enUsd = tasa > 0 ? (original / tasa) : original;
      _totalUsdCtrl.text = enUsd.toStringAsFixed(2);
    } else if (_selectedMoneda == 'USDT') {
      // 1 USDT se valora a la par de USD para totalUsd
      _totalUsdCtrl.text = original.toStringAsFixed(2);
    } else {
      _totalUsdCtrl.text = original.toStringAsFixed(2);
    }
    setState(() {});
  }

  void _recalcularTotal() {
    final int sumCentavos = _items.fold(0, (acc, item) => acc + item.total);
    final double sum = sumCentavos / 100.0;
    if (sum > 0) {
      _bolivaresAjustadosManualmente = false;
      _totalOriginalCtrl.text = _formatDouble(sum);
      _recalcularTotalUsd();
    }
  }

  Future<void> _actualizarTasaPorFecha(String fecha, {bool esRellenoInicial = false}) async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final isToday = fecha.isEmpty || fecha == today;
    setState(() {
      _fuenteTasa = 'Buscando tasa del $fecha...';
      if (!isToday && !esRellenoInicial) {
        _tasaUsdFecha = null;
        _tasaEurFecha = null;
        _tasaUsdtFecha = null;
      }
    });

    await _cargarTasasChips(fecha);

    if (mounted) {
      setState(() {
        _tasaOficialUsd = _tasaUsdFecha;
        _tasaOficialEur = _tasaEurFecha;
        _tasaOficialUsdt = _tasaUsdtFecha;

        if (_tasaUsdtFecha != null && _tasaUsdtFecha! > 0) {
          _tasaUsdtCtrl.text = _tasaUsdtFecha!.toStringAsFixed(2);
        }
        if (_tasaEurFecha != null && _tasaEurFecha! > 0) {
          _tasaEurCtrl.text = _tasaEurFecha!.toStringAsFixed(2);
        }
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final isToday = fecha == today;
        final parsed = DateTime.tryParse(fecha) ?? DateTime.now();
        final now = DateTime.now();
        final isCurrentMonth = (parsed.year == now.year && parsed.month == now.month);
        final offlineSuffix = settings.tasasSonReferencia ? ' · Tasa estimada en caché (sin conexión)' : '';

        if (_selectedMoneda == 'VES') {
          final tasaAplicar = _tasaUsdFecha;
          if (tasaAplicar != null && tasaAplicar > 0) _tasaCambioCtrl.text = tasaAplicar.toStringAsFixed(2);
          if (isToday) {
            _fuenteTasa = 'Tasa oficial BCV (Hoy)$offlineSuffix';
          } else if (_esTasaHistoricaExacta) {
            _fuenteTasa = 'Tasa oficial BCV ($fecha)';
          } else if (isCurrentMonth) {
            _fuenteTasa = 'Tasa referencial actual (sin conexión)';
          } else {
            _fuenteTasa = 'Sin conexión para histórico · Tasa referencial';
          }
        } else if (_selectedMoneda == 'EUR') {
          double? tasaAplicar = _tasaEurFecha ?? _tasaUsdFecha;
          if (tasaAplicar != null && tasaAplicar > 0) _tasaCambioCtrl.text = tasaAplicar.toStringAsFixed(2);
          if (isToday) {
            _fuenteTasa = 'Euro BCV oficial (Hoy)$offlineSuffix';
          } else if (_esTasaEurExacta) {
            _fuenteTasa = 'Euro BCV oficial ($fecha)';
          } else if (isCurrentMonth) {
            _fuenteTasa = 'Tasa referencial actual (sin conexión)';
          } else {
            _fuenteTasa = 'Sin conexión para histórico · Tasa referencial';
          }
        } else if (_selectedMoneda == 'USD') {
          double? tasaAplicar = (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt) ? _tasaUsdtFecha : _tasaUsdFecha;
          if (tasaAplicar != null && tasaAplicar > 0) _tasaCambioCtrl.text = tasaAplicar.toStringAsFixed(2);
          if (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt) {
            if (isToday) {
              _fuenteTasa = 'USDT P2P (Hoy)$offlineSuffix';
            } else if (_esTasaUsdtExacta) {
              _fuenteTasa = 'USDT P2P ($fecha)';
            } else if (_esTasaHistoricaExacta) {
              _fuenteTasa = 'Referencia BCV ($fecha) · Ajusta la tasa P2P';
            } else if (isCurrentMonth) {
              _fuenteTasa = 'Tasa referencial actual (sin conexión)';
            } else {
              _fuenteTasa = 'Sin conexión para histórico · Tasa referencial';
            }
          } else {
            if (isToday) {
              _fuenteTasa = 'Tasa oficial BCV (Hoy)$offlineSuffix';
            } else if (_esTasaHistoricaExacta) {
              _fuenteTasa = 'Tasa oficial BCV ($fecha)';
            } else if (isCurrentMonth) {
              _fuenteTasa = 'Tasa referencial actual (sin conexión)';
            } else {
              _fuenteTasa = 'Sin conexión para histórico · Tasa referencial';
            }
          }
        }
        _recalcularTotalUsd();
        if (esRellenoInicial) {
          _initialTasa = tryParseAmount(_tasaCambioCtrl.text, isPrice: false) ?? 0.0;
          _initialTotalOriginal = double.tryParse(_totalOriginalCtrl.text.replaceAll(',', '.')) ?? 0.0;
          _initialTotalUsdStr = _totalUsdCtrl.text;
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final parsed = DateTime.tryParse(_selectedFecha) ?? now;
    final minDate = AppConstants.fechaMinimaHistoricoTasas;
    final maxDate = DateTime(now.year, now.month, now.day);
    final initialDate = parsed.isBefore(minDate)
        ? minDate
        : (parsed.isAfter(maxDate) ? maxDate : parsed);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.black,
              surface: AppColors.card,
              onSurface: AppColors.textPrimary,
            ),
            datePickerTheme: DatePickerThemeData(
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final nuevaFecha = DateFormatter.toIsoDate(picked);
      if (nuevaFecha != _selectedFecha) {
        setState(() {
          _selectedFecha = nuevaFecha;
          _bolivaresAjustadosManualmente = false;
        });
        await _actualizarTasaPorFecha(nuevaFecha);
      }
    }
  }

  void _addItem() {
    setState(() {
      _items.add(ItemGastoModel(
        descripcion: '',
        cantidad: 1.0,
        precioUnitario: 0,
        total: 0,
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  Future<void> _guardarGasto({bool revisarSiguiente = false}) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);

    String? rutaFotoFinal;
    if (_imageDeleted) {
      rutaFotoFinal = null;
    } else if (_pickedImage != null) {
      rutaFotoFinal = await ImageService.saveImagePermanently(_pickedImage!);
    } else {
      if (widget.existingGasto != null) {
        rutaFotoFinal = widget.existingGasto!.rutaFotoLocal;
        if (widget.imageFile != null && settings.guardarFotos) {
          rutaFotoFinal = await ImageService.saveImagePermanently(widget.imageFile!);
        }
      } else {
        if (settings.guardarFotos && widget.imageFile != null) {
          rutaFotoFinal = await ImageService.saveImagePermanently(widget.imageFile!);
        } else if (widget.imageFile != null && widget.queueItemId != null) {
          final isUsed = await DatabaseHelper.instance.isImagePathUsedByOtherQueueItems(widget.queueItemId!, widget.imageFile!.path);
          if (!isUsed) {
            await ImageService.deleteTempFile(widget.imageFile!);
          }
        } else if (widget.imageFile != null) {
          await ImageService.deleteTempFile(widget.imageFile!);
        }
      }
    }

    double totalOrig = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
    final totalUsd = tryParseAmount(_totalUsdCtrl.text, isPrice: false) ?? 0.0;
    final tasa = tryParseAmount(_tasaCambioCtrl.text, isPrice: false) ?? 1.0;

    if (totalOrig <= 0 || totalUsd <= 0) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El monto del gasto debe ser mayor a 0.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Alerta de discrepancia entre Monto Total y Suma de Ítems (Punto 5)
    final double sumItems = _items.fold(0.0, (acc, it) => acc + it.totalDisplay);
    if (_items.isNotEmpty && sumItems > 0 && (sumItems - totalOrig).abs() > 0.05) {
      final action = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Diferencia en el monto total',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 16),
          ),
          content: Text(
            'La suma de los productos (${sumItems.toStringAsFixed(2)} $_selectedMoneda) no coincide con el Monto Total (${totalOrig.toStringAsFixed(2)} $_selectedMoneda).\n\nDiferencia: ${(sumItems - totalOrig).abs().toStringAsFixed(2)} $_selectedMoneda.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: const Text('Cancelar / Revisar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'keep'),
              child: const Text(
                'Guardar con el monto actual',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => Navigator.pop(ctx, 'adjust'),
              child: const Text('Ajustar total a la suma de ítems', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (action == 'cancel' || action == null) {
        setState(() => _isSaving = false);
        return;
      }

      if (action == 'adjust') {
        _bolivaresAjustadosManualmente = false;
        _totalOriginalCtrl.text = _formatDouble(sumItems);
        _recalcularTotalUsd();
        totalOrig = sumItems;
      }
    }

    double tasaParaGasto = tasa;
    String fuenteFinal = _fuenteTasa;
    final tasaUsdtFinal = (_tasaUsdtFecha != null && _tasaUsdtFecha! > 0)
        ? _tasaUsdtFecha!
        : (tryParseAmount(_tasaUsdtCtrl.text, isPrice: false) ?? settings.tasaCambioVesUsdt);
    final tasaEurFinal = tryParseAmount(_tasaEurCtrl.text, isPrice: false) ??
        ((_tasaEurFecha != null && _tasaEurFecha! > 0) ? _tasaEurFecha! : settings.tasaCambioVesEur);

    String monedaFinal = _selectedMoneda;
    int totalOriginalCentavos;
    int totalUsdCentavos;
    int totalUsdtCentavos;
    int? totalEurCentavos;
    double totalVesCalculado = 0.0;

    if (_selectedMoneda == 'VES') {
      final tUsd = tryParseAmount(_tasaCambioCtrl.text, isPrice: false) ?? (_tasaUsdFecha ?? settings.tasaCambioVesUsd);
      tasaParaGasto = tUsd > 0 ? tUsd : tasa;
      totalOriginalCentavos = (totalOrig * 100).round();
      final enUsd = tasaParaGasto > 0 ? (totalOrig / tasaParaGasto) : totalOrig;
      totalUsdCentavos = (enUsd * 100).round();
      final enEur = tasaEurFinal > 0 ? (totalOrig / tasaEurFinal) : enUsd;
      totalEurCentavos = (enEur * 100).round();
      final enUsdt = tasaUsdtFinal > 0 ? (totalOrig / tasaUsdtFinal) : enUsd;
      totalUsdtCentavos = (enUsdt * 100).round();
    } else if ((_selectedMoneda == 'USD' || _selectedMoneda == 'EUR') && _metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsBcv) {
      // Opción 1: En Bs. · precio a tasa BCV
      monedaFinal = 'VES';
      final tasaBcv = _effectiveBcvRate(settings);
      final double tasaRefUsd = (_tasaUsdFecha != null && _tasaUsdFecha! > 0)
          ? _tasaUsdFecha!
          : (settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : tasaBcv);
      final manualBs = _bolivaresAjustadosManualmente
          ? tryParseAmount(_totalBsManualCtrl.text, isPrice: false)
          : null;
      totalVesCalculado = (manualBs != null && manualBs > 0) ? manualBs : (totalOrig * tasaBcv);
      totalOriginalCentavos = (totalVesCalculado * 100).round();
      final enUsdBcv = _selectedMoneda == 'EUR'
          ? (tasaRefUsd > 0 ? (totalVesCalculado / tasaRefUsd) : totalOrig)
          : (tasaBcv > 0 ? (totalVesCalculado / tasaBcv) : totalOrig);
      totalUsdCentavos = (enUsdBcv * 100).round();
      final enEur = tasaEurFinal > 0 ? (totalVesCalculado / tasaEurFinal) : (_selectedMoneda == 'EUR' ? totalOrig : enUsdBcv);
      totalEurCentavos = (enEur * 100).round();
      final enUsdt = tasaUsdtFinal > 0 ? (totalVesCalculado / tasaUsdtFinal) : enUsdBcv;
      totalUsdtCentavos = (enUsdt * 100).round();
      tasaParaGasto = tasaBcv;
      fuenteFinal = 'BCV (Pago en Bs. indexado a $_selectedMoneda)';
    } else if ((_selectedMoneda == 'USD' || _selectedMoneda == 'EUR') && _metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt) {
      // Opción 2: En Bs. · precio a tasa P2P
      monedaFinal = 'VES';
      final tasaUsdtEfectiva = tasaUsdtFinal > 0 ? tasaUsdtFinal : settings.tasaCambioVesUsdt;
      final tasaBcv = _effectiveBcvRate(settings);
      final double tasaRefUsd = (_tasaUsdFecha != null && _tasaUsdFecha! > 0)
          ? _tasaUsdFecha!
          : (settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : tasaBcv);
      final manualBs = _bolivaresAjustadosManualmente
          ? tryParseAmount(_totalBsManualCtrl.text, isPrice: false)
          : null;
      totalVesCalculado = (manualBs != null && manualBs > 0) ? manualBs : (totalOrig * tasaUsdtEfectiva);
      totalOriginalCentavos = (totalVesCalculado * 100).round();
      final enUsdBcv = tasaRefUsd > 0 ? (totalVesCalculado / tasaRefUsd) : totalOrig;
      totalUsdCentavos = (enUsdBcv * 100).round();
      final enEur = tasaEurFinal > 0 ? (totalVesCalculado / tasaEurFinal) : (_selectedMoneda == 'EUR' ? totalOrig : enUsdBcv);
      totalEurCentavos = (enEur * 100).round();
      final enUsdt = tasaUsdtEfectiva > 0 ? (totalVesCalculado / tasaUsdtEfectiva) : totalOrig;
      totalUsdtCentavos = (enUsdt * 100).round();
      tasaParaGasto = tasaBcv;
      fuenteFinal = _selectedMoneda == 'EUR'
          ? 'Binance P2P (Pago en Bs. indexado a EUR)'
          : 'Binance P2P (Pago en Bs. indexado a USDT)';
    } else if (_selectedMoneda == 'EUR') {
      final eurRate = tasaEurFinal > 0 ? tasaEurFinal : (tasa > 0 ? tasa : settings.tasaCambioVesEur);
      final usdRate = (_tasaUsdFecha != null && _tasaUsdFecha! > 0) ? _tasaUsdFecha! : settings.tasaCambioVesUsd;
      final totalVes = totalOrig * eurRate;
      tasaParaGasto = usdRate > 0 ? usdRate : 1.0;
      totalOriginalCentavos = (totalOrig * 100).round();
      totalEurCentavos = (totalOrig * 100).round();
      final double equivUsd = (usdRate > 0 && eurRate > 0 ? (totalVes / usdRate) : (totalUsd > 0 ? totalUsd : totalOrig));
      totalUsdCentavos = (equivUsd * 100).round();
      totalUsdtCentavos = totalUsdCentavos;
      if (!fuenteFinal.contains('Euro BCV')) {
        fuenteFinal = 'Euro BCV (Bs. ${eurRate.toStringAsFixed(2)})';
      }
    } else if (_selectedMoneda == 'USDT') {
      final usdRate = (_tasaUsdFecha != null && _tasaUsdFecha! > 0) ? _tasaUsdFecha! : settings.tasaCambioVesUsd;
      final eurRate = tasaEurFinal > 0 ? tasaEurFinal : settings.tasaCambioVesEur;
      tasaParaGasto = usdRate > 0 ? usdRate : 1.0;
      totalOriginalCentavos = (totalOrig * 100).round();
      totalUsdCentavos = (totalOrig * 100).round();
      totalUsdtCentavos = (totalOrig * 100).round();
      final double equivEur = (eurRate > 0 && usdRate > 0) ? (totalOrig * usdRate / eurRate) : totalOrig;
      totalEurCentavos = (equivEur * 100).round();
    } else {
      // USD directo (Pagado en Divisa)
      final tasaRefUsd = (_tasaUsdFecha != null && _tasaUsdFecha! > 0) ? _tasaUsdFecha! : settings.tasaCambioVesUsd;
      final eurRate = tasaEurFinal > 0 ? tasaEurFinal : settings.tasaCambioVesEur;
      tasaParaGasto = tasaRefUsd > 0 ? tasaRefUsd : 1.0;
      totalOriginalCentavos = (totalOrig * 100).round();
      totalUsdCentavos = (totalOrig * 100).round();
      totalUsdtCentavos = (totalOrig * 100).round();
      final double equivEur = (eurRate > 0 && tasaParaGasto > 0) ? (totalOrig * tasaParaGasto / eurRate) : totalOrig;
      totalEurCentavos = (equivEur * 100).round();
      fuenteFinal = 'Divisa Directa';
    }

    final double ratioConversionItems = (monedaFinal == 'VES' && (_selectedMoneda == 'USD' || _selectedMoneda == 'EUR') && totalOrig > 0)
        ? (totalVesCalculado / totalOrig)
        : 1.0;

    int unnamedCounter = 1;
    final itemsFinal = <ItemGastoModel>[];
    for (int idx = 0; idx < _items.length; idx++) {
      final it = _items[idx];
      final desc = it.descripcion.trim().isEmpty ? 'Producto ${unnamedCounter++}' : it.descripcion.trim();
      if (ratioConversionItems != 1.0) {
        final bool canPreserveOriginalBsCents = widget.existingGasto != null &&
            (ratioConversionItems - _initialRateForItems).abs() < 0.0001 &&
            _initialItems != null &&
            idx < _initialItems!.length &&
            idx < widget.existingGasto!.items.length &&
            it.cantidad == _initialItems![idx].cantidad &&
            it.precioUnitario == _initialItems![idx].precioUnitario &&
            it.total == _initialItems![idx].total;

        if (canPreserveOriginalBsCents) {
          final origBsItem = widget.existingGasto!.items[idx];
          itemsFinal.add(it.copyWith(
            descripcion: desc,
            precioUnitario: origBsItem.precioUnitario,
            total: origBsItem.total,
          ));
        } else {
          final bsPrice = it.precioUnitarioDisplay * ratioConversionItems;
          final bsTotal = it.totalDisplay * ratioConversionItems;
          itemsFinal.add(it.copyWith(
            descripcion: desc,
            precioUnitario: (bsPrice * 100).round(),
            total: (bsTotal * 100).round(),
          ));
        }
      } else {
        itemsFinal.add(it.copyWith(descripcion: desc));
      }
    }

    final String predominantCat = ItemGastoModel.calcularCategoriaDominante(itemsFinal);
    for (int i = 0; i < itemsFinal.length; i++) {
      if (ItemGastoModel.isTaxDescription(itemsFinal[i].descripcion)) {
        itemsFinal[i] = itemsFinal[i].copyWith(categoria: predominantCat);
      }
    }

    final comercioFinal = _comercioCtrl.text.trim().isEmpty ? 'Compra general' : _comercioCtrl.text.trim();

    final nuevoGasto = GastoModel(
      id: widget.existingGasto?.id,
      uuid: widget.existingGasto?.uuid ?? UuidGenerator.generate(),
      fecha: _selectedFecha,
      comercio: comercioFinal,
      moneda: monedaFinal,
      totalOriginal: totalOriginalCentavos,
      totalUsd: totalUsdCentavos,
      totalUsdt: totalUsdtCentavos,
      totalEur: totalEurCentavos,
      tasaCambio: tasaParaGasto,
      tasaUsdt: tasaUsdtFinal,
      tasaEur: tasaEurFinal,
      fuenteTasaCambio: fuenteFinal,
      fechaTasaCambio: _selectedFecha,
      categoria: predominantCat,
      rutaFotoLocal: rutaFotoFinal,
      creadoEn: widget.existingGasto?.creadoEn ?? DateTime.now().toIso8601String(),
    );

    bool success;
    final matchedIds = List<int>.from(widget.extractedData?.matchedShoppingItemIds ?? []);

    if (widget.existingGasto != null) {
      success = await gastoProvider.actualizarGasto(nuevoGasto, itemsFinal);
    } else {
      try {
        final pendingShopping = await DatabaseHelper.instance.getPendingShoppingItems();
        for (final item in itemsFinal) {
          final descNorm = _normalizeText(item.descripcion);
          if (descNorm.length >= 2) {
            for (final shopItem in pendingShopping) {
              final shopNorm = _normalizeText(shopItem.name);
              if (shopNorm.isNotEmpty && (descNorm == shopNorm || descNorm.contains(shopNorm) || shopNorm.contains(descNorm))) {
                if (shopItem.id != null && !matchedIds.contains(shopItem.id!)) {
                  matchedIds.add(shopItem.id!);
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Error cotejando lista de compras: $e');
      }

      success = await gastoProvider.agregarGasto(nuevoGasto, itemsFinal, shoppingItemIds: matchedIds);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      final queueProvider = Provider.of<ScanQueueProvider>(context, listen: false);
      if (widget.queueItemId != null) {
        await queueProvider.removeItem(widget.queueItemId!);
      }

      // Si el usuario eligió revisar la siguiente y hay más facturas en la cola
      if (revisarSiguiente && queueProvider.readyItems.isNotEmpty) {
        final nextItem = queueProvider.readyItems.first;
        Map<String, dynamic> data = {};
        if (nextItem['extracted_data'] != null) {
          data = Map<String, dynamic>.from(jsonDecode(nextItem['extracted_data']));
        }
        final result = GeminiExtractionResult.fromJson(data);
        final file = File(nextItem['image_path']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gasto registrado. Cargando siguiente factura...', style: TextStyle(color: Colors.black)),
              backgroundColor: AppColors.primaryDark,
              duration: Duration(seconds: 1),
            ),
          );

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ReviewExpenseScreen(
                imageFile: file.existsSync() ? file : null,
                extractedData: result,
                queueItemId: nextItem['id'],
              ),
            ),
          );
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final isAnon = user == null || user.isAnonymous;

      if (isAnon && widget.existingGasto == null) {
        final rootMessenger = ScaffoldMessenger.of(context);
        bool cuentaVinculada = false;

        final authAction = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) {
            bool isLinking = false;
            String? errorMessage;

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return PopScope(
                  canPop: !isLinking,
                  child: AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    backgroundColor: AppColors.card,
                    title: const Row(
                      children: [
                        Icon(Icons.check_circle_outline, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Compra registrada',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tu compra se guardó en tu teléfono.\n\nSi lo deseas, puedes vincular con Google para respaldar y sincronizar tus gastos entre dispositivos.',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                        ),
                        if (isLinking) ...[
                          const SizedBox(height: 20),
                          const Center(
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: Colors.black),
                                SizedBox(height: 12),
                                Text(
                                  'Conectando con Google y respaldando...',
                                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      if (errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(fontSize: 12, color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  actions: isLinking
                      ? []
                      : [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.login, size: 18),
                                  label: Text(
                                    errorMessage != null ? 'Reintentar vinculación' : 'Vincular con Google',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () async {
                                    final gastoProvider = Provider.of<GastoProvider>(context, listen: false);
                                    bool descartarLocales = false;

                                    if (gastoProvider.gastos.isNotEmpty) {
                                      final decision = await mostrarDialogoFusionarOReemplazar(context);
                                      if (!ctx.mounted) return;
                                      if (decision == null) return;
                                      descartarLocales = decision;
                                    }

                                    setDialogState(() {
                                      isLinking = true;
                                      errorMessage = null;
                                    });

                                    final error = await gastoProvider
                                        .vincularCuentaGoogle(descartarDatosLocales: descartarLocales);
                                    if (!ctx.mounted) return;

                                    if (error == 'CANCELLED') {
                                      setDialogState(() {
                                        isLinking = false;
                                      });
                                    } else if (error != null) {
                                      setDialogState(() {
                                        isLinking = false;
                                        errorMessage = error;
                                      });
                                    } else {
                                      cuentaVinculada = true;
                                      await Provider.of<SettingsProvider>(context, listen: false).loadSettings();
                                      if (!ctx.mounted) return;
                                      Navigator.pop(ctx, 'google');
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.alternate_email, size: 18, color: AppColors.primaryDark),
                                  label: const Text(
                                    'Vincular con correo',
                                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, 'email'),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, 'skip'),
                                child: const Text('Ahora no', style: TextStyle(color: AppColors.textSecondary)),
                              ),
                            ],
                          ),
                        ],
                  ),
                );
              },
            );
          },
        );

        if (authAction == 'email' && mounted) {
          await mostrarModalAutenticacionEmail(
            context,
            onSuccess: () {
              cuentaVinculada = true;
            },
          );
        }

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
          if (cuentaVinculada) {
            rootMessenger.showSnackBar(
              const SnackBar(
                content: Text('Cuenta vinculada con éxito. Gastos sincronizados.', style: TextStyle(color: Colors.white)),
                backgroundColor: AppColors.secondary,
              ),
            );
          } else {
            rootMessenger.showSnackBar(
              const SnackBar(
                content: Text('Gasto registrado con éxito', style: TextStyle(color: Colors.black)),
                backgroundColor: AppColors.primaryDark,
              ),
            );
          }
        }
      } else {
        if (matchedIds.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gasto registrado y ${matchedIds.length} ítem(s) de tu lista marcados como comprados.', style: const TextStyle(color: Colors.black)),
              backgroundColor: AppColors.primaryDark,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gasto registrado con éxito', style: TextStyle(color: Colors.black)),
              backgroundColor: AppColors.primaryDark,
            ),
          );
        }

        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(gastoProvider.errorMessage?.isNotEmpty == true ? gastoProvider.errorMessage! : 'No se pudo guardar el gasto. Intenta de nuevo.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _buildLiquidacionPill({
    required Key key,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: key,
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : AppColors.cardLighter,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final queueProvider = Provider.of<ScanQueueProvider>(context);
    final readyCount = queueProvider.readyItems.length;
    final isQueueItem = widget.queueItemId != null;
    final hasMoreInQueue = isQueueItem && readyCount > 1;

    return PopScope(
      canPop: !_isDirty() || _isSaving,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: AppColors.card,
            title: const Text('Descartar cambios', style: TextStyle(color: AppColors.textPrimary)),
            content: const Text('¿Quieres descartar el formulario?', style: TextStyle(color: AppColors.textSecondary)),
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
        if (confirm == true && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
      bottomNavigationBar: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
          child: hasMoreInQueue
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      onPressed: _isSaving ? null : () => _guardarGasto(revisarSiguiente: true),
                      icon: const Icon(Icons.arrow_forward, color: Colors.black),
                      label: _isSaving
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                          : Text(
                              'Guardar y revisar siguiente (${readyCount - 1} más)',
                              style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      onPressed: _isSaving ? null : () => _guardarGasto(revisarSiguiente: false),
                      child: const Text(
                        'Guardar y salir al inicio',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _isSaving ? null : () => _guardarGasto(revisarSiguiente: false),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Text('Guardar Gasto', style: TextStyle(color: Colors.black, fontSize: 16)),
                ),
            ),
          ),
        ),
      ),
      appBar: AppBar(
        title: Text(
          isQueueItem && readyCount > 1
              ? (widget.imageFile != null
                  ? 'Revisar Factura ($readyCount en cola)'
                  : 'Revisar Gasto ($readyCount en cola)')
              : (widget.queueItemId != null || widget.imageFile != null
                  ? (widget.imageFile != null ? 'Revisar Factura' : 'Revisar Gasto')
                  : 'Registrar gasto'),
        ),
        actions: [
          if (widget.queueItemId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: widget.imageFile != null ? 'Descartar Factura' : 'Descartar Gasto',
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
                  final qProvider = Provider.of<ScanQueueProvider>(context, listen: false);
                  await qProvider.removeItem(widget.queueItemId!);
                  if (!mounted) return;

                  if (qProvider.readyItems.isNotEmpty) {
                    final nextItem = qProvider.readyItems.first;
                    Map<String, dynamic> data = {};
                    if (nextItem['extracted_data'] != null) {
                      data = Map<String, dynamic>.from(jsonDecode(nextItem['extracted_data']));
                    }
                    final result = GeminiExtractionResult.fromJson(data);
                    final file = File(nextItem['image_path']);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Factura descartada. Cargando siguiente...', style: TextStyle(color: Colors.black)),
                        backgroundColor: AppColors.primaryDark,
                        duration: Duration(seconds: 1),
                      ),
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReviewExpenseScreen(
                          imageFile: file.existsSync() ? file : null,
                          extractedData: result,
                          queueItemId: nextItem['id'],
                        ),
                      ),
                    );
                  } else {
                    Navigator.pop(context);
                  }
                }
              },
            ),
        ],
      ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageHeader(),
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
                      labelText: 'Comercio o Beneficiario (opcional)',
                      hintText: 'Ej. Automercado Plaza',
                      prefixIcon: Icon(Icons.storefront_outlined, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _selectDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Fecha de gasto',
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
                  const Text(
                    'Desglose de Ítems',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                          final prevUsd = (prevData['precio_usd'] as num?)?.toDouble() ?? 0.0;
                          final prevComercio = prevData['comercio'] as String? ?? '';
                          
                          final cant = item.cantidad > 0 ? item.cantidad : 1.0;
                          double unitPrice = item.precioUnitarioDisplay;
                          if (item.totalDisplay > 0) {
                            unitPrice = item.totalDisplay / cant;
                          }

                          double currentUsd = unitPrice;
                          final tasa = tryParseAmount(_tasaCambioCtrl.text, isPrice: false) ?? 1.0;
                          if (_selectedMoneda == 'VES') {
                            if (tasa > 0) currentUsd = unitPrice / tasa;
                          } else {
                            double sumItems = _items.fold(0.0, (prev, it) => prev + it.totalDisplay);
                            final totalOrig = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
                            if (totalOrig > 0 && sumItems > totalOrig * 5 && tasa > 0) {
                              currentUsd = unitPrice / tasa;
                            }
                          }

                          if (prevUsd > 0 && currentUsd > 0) {
                            if (currentUsd > (prevUsd * 1.05)) { // 5% de tolerancia
                              final diff = ((currentUsd / prevUsd) - 1) * 100;
                              priceWarning = Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4),
                                child: Text(
                                  '🔺 Está ${diff.toStringAsFixed(0)}% más caro por unidad que en $prevComercio',
                                  style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              );
                            } else if (currentUsd < (prevUsd * 0.95)) {
                              final diff = (1 - (currentUsd / prevUsd)) * 100;
                              priceWarning = Padding(
                                padding: const EdgeInsets.only(top: 4, left: 4),
                                child: Text(
                                  '🟢 Te salió un ${diff.toStringAsFixed(0)}% más económico por unidad que en $prevComercio',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              );
                            }
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
                                          final cant = tryParseAmount(v, isPrice: false) ?? 1.0;
                                          setState(() {
                                            _items[idx] = _items[idx].copyWith(
                                              cantidad: cant,
                                              total: (cant * _items[idx].precioUnitarioDisplay * 100).round(),
                                            );
                                          });
                                          _recalcularTotal();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: _formatDouble(item.precioUnitarioDisplay),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          labelText: 'Precio',
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                        onChanged: (v) {
                                          final prec = tryParseAmount(v, isPrice: false) ?? 0.0;
                                          setState(() {
                                            _items[idx] = _items[idx].copyWith(
                                              precioUnitario: (prec * 100).round(),
                                              total: (_items[idx].cantidad * prec * 100).round(),
                                            );
                                          });
                                          _recalcularTotal();
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                    child: InputDecorator(
                                      decoration: const InputDecoration(
                                        labelText: 'Total',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      ),
                                      child: Text(
                                        _formatDouble(_items[idx].totalDisplay),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
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
                                    final catColor = AppColors.categoryColors[cat] ?? AppColors.textSecondary;
                                    final catIcon = _getCategoryIcon(cat);
                                    return DropdownMenuItem(
                                      value: cat,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: catColor.withValues(alpha: 0.15),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(catIcon, size: 14, color: catColor),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(cat, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _items[idx] = _items[idx].copyWith(categoria: val);
                                        if (!ItemGastoModel.isTaxDescription(_items[idx].descripcion)) {
                                          final domCat = ItemGastoModel.calcularCategoriaDominante(_items);
                                          for (int i = 0; i < _items.length; i++) {
                                            if (ItemGastoModel.isTaxDescription(_items[i].descripcion)) {
                                              _items[i] = _items[i].copyWith(categoria: domCat);
                                            }
                                          }
                                        }
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
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('review_expense_add_item_btn'),
                    onPressed: _addItem,
                    icon: const Icon(Icons.add, size: 18, color: AppColors.primaryDark),
                    label: Text(
                      _items.isEmpty ? 'Agregar ítem' : 'Agregar otro ítem',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: AppColors.cardLighter,
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
                  const Text(
                    'Monto Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  const Text('Moneda de pago', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.cardLighter,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        for (final m in AppConstants.monedas)
                          Expanded(
                            child: InkWell(
                              key: Key('expense_currency_${m.toLowerCase()}_btn'),
                              onTap: () {
                                setState(() {
                                  _selectedMoneda = m;
                                  _bolivaresAjustadosManualmente = false;
                                  final today = DateTime.now().toIso8601String().substring(0, 10);
                                  final isToday = _selectedFecha == today;
                                  if (m == 'EUR') {
                                    final val = _tasaEurFecha ?? settings.tasaCambioVesEur;
                                    if (val > 0) _tasaCambioCtrl.text = val.toStringAsFixed(2);
                                    _fuenteTasa = isToday
                                        ? 'Euro BCV oficial (Hoy)'
                                        : (_esTasaEurExacta
                                            ? 'Euro BCV oficial ($_selectedFecha)'
                                            : 'Euro referencial ($_selectedFecha)');
                                  } else if (m == 'VES' || m == 'USD') {
                                    final val = _tasaUsdFecha ?? settings.tasaCambioVesUsd;
                                    if (val > 0) _tasaCambioCtrl.text = val.toStringAsFixed(2);
                                    _fuenteTasa = isToday
                                        ? 'Dólar BCV oficial (Hoy)'
                                        : (_esTasaHistoricaExacta
                                            ? 'Dólar BCV oficial ($_selectedFecha)'
                                            : 'Dólar referencial ($_selectedFecha)');
                                  }
                                  _recalcularTotalUsd();
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _selectedMoneda == m ? AppColors.surface : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: _selectedMoneda == m
                                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                                      : null,
                                ),
                                child: Text(
                                  m,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _selectedMoneda == m ? FontWeight.bold : FontWeight.normal,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_selectedMoneda == 'VES') ...[
                    TextFormField(
                      controller: _totalOriginalCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto Original (VES)',
                        prefixIcon: Icon(Icons.payments_outlined, color: AppColors.textSecondary),
                      ),
                      onChanged: (_) => _recalcularTotalUsd(),
                      validator: (val) => validatePositiveAmount(val),
                    ),
                    const SizedBox(height: 12),
                    // Chips rápidos de tasa para Bolívares
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            key: const Key('chip_rate_usd_bcv'),
                            avatar: const Icon(Icons.attach_money, size: 14, color: AppColors.primaryDark),
                            selected: _monedaTasaSeleccionadaVes == 'USD',
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            label: Text(
                              'Dólar BCV: Bs. ${(_tasaUsdFecha ?? settings.tasaCambioVesUsd).toStringAsFixed(2)}${(_selectedFecha != DateTime.now().toIso8601String().substring(0, 10) && !_esTasaHistoricaExacta) ? ' (Ref.)' : ''}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: _monedaTasaSeleccionadaVes == 'USD' ? AppColors.primaryDark : AppColors.border,
                              width: _monedaTasaSeleccionadaVes == 'USD' ? 1.5 : 1.0,
                            ),
                            onSelected: (sel) {
                              if (sel) setState(() => _monedaTasaSeleccionadaVes = 'USD');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            key: const Key('chip_rate_eur_bcv'),
                            avatar: const Icon(Icons.euro, size: 14, color: AppColors.primaryDark),
                            selected: _monedaTasaSeleccionadaVes == 'EUR',
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            label: Text(
                              'Euro BCV: Bs. ${(_tasaEurFecha ?? settings.tasaCambioVesEur).toStringAsFixed(2)}${(_selectedFecha != DateTime.now().toIso8601String().substring(0, 10) && !_esTasaEurExacta) ? ' (Ref.)' : ''}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: _monedaTasaSeleccionadaVes == 'EUR' ? AppColors.primaryDark : AppColors.border,
                              width: _monedaTasaSeleccionadaVes == 'EUR' ? 1.5 : 1.0,
                            ),
                            onSelected: (sel) {
                              if (sel) setState(() => _monedaTasaSeleccionadaVes = 'EUR');
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            key: const Key('chip_rate_usdt_binance'),
                            avatar: const Icon(Icons.currency_bitcoin, size: 14, color: AppColors.primaryDark),
                            selected: _monedaTasaSeleccionadaVes == 'USDT',
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            label: Text(
                              'USDT P2P: Bs. ${(_tasaUsdtFecha ?? settings.tasaCambioVesUsdt).toStringAsFixed(2)}${(_selectedFecha != DateTime.now().toIso8601String().substring(0, 10) && !_esTasaUsdtExacta) ? (_esTasaHistoricaExacta ? ' (Ref. BCV)' : ' (Ref.)') : ''}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                            ),
                            backgroundColor: AppColors.surface,
                            side: BorderSide(
                              color: _monedaTasaSeleccionadaVes == 'USDT' ? AppColors.primaryDark : AppColors.border,
                              width: _monedaTasaSeleccionadaVes == 'USDT' ? 1.5 : 1.0,
                            ),
                            onSelected: (sel) {
                              if (sel) setState(() => _monedaTasaSeleccionadaVes = 'USDT');
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Campo editable de la tasa seleccionada con botón de restaurar
                    Builder(builder: (context) {
                      final TextEditingController activeCtrl;
                      final String activeLabel;
                      final IconData activeIcon;
                      final double officialRate;

                      if (_monedaTasaSeleccionadaVes == 'EUR') {
                        activeCtrl = _tasaEurCtrl;
                        activeLabel = 'Tasa Euro BCV';
                        activeIcon = Icons.euro;
                        officialRate = _tasaOficialEur ?? (_tasaEurFecha ?? settings.tasaCambioVesEur);
                      } else if (_monedaTasaSeleccionadaVes == 'USDT') {
                        activeCtrl = _tasaUsdtCtrl;
                        activeLabel = 'Tasa USDT P2P (Binance)';
                        activeIcon = Icons.currency_bitcoin;
                        officialRate = _tasaOficialUsdt ?? (_tasaUsdtFecha ?? settings.tasaCambioVesUsdt);
                      } else {
                        activeCtrl = _tasaCambioCtrl;
                        activeLabel = 'Tasa Dólar BCV';
                        activeIcon = Icons.attach_money;
                        officialRate = _tasaOficialUsd ?? (_tasaUsdFecha ?? settings.tasaCambioVesUsd);
                      }

                      final parsedVal = tryParseAmount(activeCtrl.text, isPrice: false);
                      final bool isModified = parsedVal != null && officialRate > 0 && (parsedVal - officialRate).abs() > 0.009;

                      return TextFormField(
                        controller: activeCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: activeLabel,
                          prefixIcon: Icon(activeIcon, color: AppColors.textSecondary, size: 18),
                          suffixIcon: isModified
                              ? IconButton(
                                  icon: const Icon(Icons.restart_alt, color: AppColors.primaryDark),
                                  tooltip: 'Restaurar tasa oficial (Bs. ${officialRate.toStringAsFixed(2)})',
                                  onPressed: () {
                                    setState(() {
                                      activeCtrl.text = officialRate.toStringAsFixed(2);
                                      _recalcularTotalUsd();
                                    });
                                  },
                                )
                              : null,
                          helperText: isModified
                              ? 'Tasa modificada manualmente (Sugerida: Bs. ${officialRate.toStringAsFixed(2)})'
                              : 'Tasa oficial correspondiente al $_selectedFecha',
                          helperStyle: TextStyle(
                            color: isModified ? AppColors.primaryDark : AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: isModified ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onChanged: (_) => _recalcularTotalUsd(),
                      );
                    }),
                    const SizedBox(height: 12),
                    // Tarjeta con las 3 equivalencias simultáneas
                    Builder(builder: (context) {
                      final orig = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
                      final tUsd = tryParseAmount(_tasaCambioCtrl.text, isPrice: false) ?? (_tasaUsdFecha ?? settings.tasaCambioVesUsd);
                      final totalUsdDisp = tUsd > 0 ? (orig / tUsd) : orig;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.cardLighter,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Equiv. USD (BCV)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 3),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '\$ ${totalUsdDisp.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 26, color: AppColors.border),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Equiv. EUR (BCV)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 3),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '€ ${_totalEurCalculado.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 26, color: AppColors.border),
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Equiv. USDT (P2P)', style: TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 3),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${_totalUsdtCalculado.toStringAsFixed(2)} USDT',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else if (_selectedMoneda == 'USD' || _selectedMoneda == 'EUR') ...[
                    // Selector: 3 opciones de liquidación para USD / EUR
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'Forma de pago en Venezuela',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLiquidacionPill(
                            key: const Key('btn_pagado_en_bs'),
                            title: 'En Bs.',
                            subtitle: 'a tasa BCV',
                            isSelected: _metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsBcv,
                            onTap: () {
                              setState(() {
                                _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnBsBcv;
                                _bolivaresAjustadosManualmente = false;
                                _recalcularTotalUsd();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildLiquidacionPill(
                            key: const Key('btn_pagado_en_bs_usdt'),
                            title: 'En Bs.',
                            subtitle: 'a tasa P2P',
                            isSelected: _metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt,
                            onTap: () {
                              setState(() {
                                _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnBsUsdt;
                                _bolivaresAjustadosManualmente = false;
                                _recalcularTotalUsd();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildLiquidacionPill(
                            key: const Key('btn_pagado_en_divisa'),
                            title: 'En divisa',
                            subtitle: 'directa',
                            isSelected: _metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnDivisa,
                            onTap: () {
                              setState(() {
                                _metodoLiquidacionUsd = MetodoLiquidacionUsd.pagadoEnDivisa;
                                _bolivaresAjustadosManualmente = false;
                                _recalcularTotalUsd();
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _totalOriginalCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _metodoLiquidacionUsd != MetodoLiquidacionUsd.pagadoEnDivisa
                            ? 'Monto en etiqueta ($_selectedMoneda)'
                            : 'Monto Total ($_selectedMoneda)',
                        prefixIcon: Icon(
                          _selectedMoneda == 'EUR' ? Icons.euro : Icons.attach_money,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      onChanged: (val) {
                        _bolivaresAjustadosManualmente = false;
                        _totalUsdCtrl.text = val;
                        _recalcularTotalUsd();
                      },
                      validator: (val) => validatePositiveAmount(val),
                    ),
                    if (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsBcv) ...[
                      const SizedBox(height: 10),
                      Builder(builder: (context) {
                        final val = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
                        final tBcv = _effectiveBcvRate(settings);
                        final manualBs = _bolivaresAjustadosManualmente
                            ? tryParseAmount(_totalBsManualCtrl.text, isPrice: false)
                            : null;
                        final totalBs = (manualBs != null && manualBs > 0) ? manualBs : (val * (tBcv > 0 ? tBcv : 1.0));
                        final equivUsdOficial = tBcv > 0 ? (totalBs / tBcv) : val;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardLighter,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: 4,
                                  children: [
                                    const Text('Se guardará en Bolívares (VES):', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text('Tasa BCV: Bs. ${tBcv.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              if (settings.tasasSonReferencia) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  'Tasa estimada en caché (sin conexión)',
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const Key('input_total_bs_manual'),
                                controller: _totalBsManualCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Bolívares finales cobrados (editable)',
                                  labelStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  prefixText: 'Bs. ',
                                  prefixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) {
                                  _bolivaresAjustadosManualmente = true;
                                  _recalcularTotalUsd();
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedMoneda == 'EUR'
                                    ? '≈ €${(tBcv > 0 ? (totalBs / tBcv) : val).toStringAsFixed(2)} EUR Oficial  •  \$${(settings.tasaCambioVesUsd > 0 ? (totalBs / settings.tasaCambioVesUsd) : val).toStringAsFixed(2)} USD  •  ${_totalUsdtCalculado.toStringAsFixed(2)} USDT'
                                    : '≈ \$${equivUsdOficial.toStringAsFixed(2)} USD Oficial  •  €${_totalEurCalculado.toStringAsFixed(2)} EUR  •  ${_totalUsdtCalculado.toStringAsFixed(2)} USDT',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else if (_metodoLiquidacionUsd == MetodoLiquidacionUsd.pagadoEnBsUsdt) ...[
                      const SizedBox(height: 10),
                      Builder(builder: (context) {
                        final val = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
                        final tUsdt = (_tasaUsdtFecha != null && _tasaUsdtFecha! > 0)
                            ? _tasaUsdtFecha!
                            : (tryParseAmount(_tasaUsdtCtrl.text, isPrice: false) ?? settings.tasaCambioVesUsdt);
                        final tBcv = _effectiveBcvRate(settings);
                        final manualBs = _bolivaresAjustadosManualmente
                            ? tryParseAmount(_totalBsManualCtrl.text, isPrice: false)
                            : null;
                        final totalBs = (manualBs != null && manualBs > 0) ? manualBs : (val * (tUsdt > 0 ? tUsdt : 1.0));
                        final equivUsdBcv = tBcv > 0 ? (totalBs / tBcv) : val;
                        final equivUsdt = tUsdt > 0 ? (totalBs / tUsdt) : val;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardLighter,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: 4,
                                  children: [
                                    const Text('Se guardará en Bolívares (VES):', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text('Tasa P2P: Bs. ${tUsdt.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              if (settings.tasasSonReferencia) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  'Tasa estimada en caché (sin conexión)',
                                  style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                ),
                              ],
                              const SizedBox(height: 8),
                              TextFormField(
                                key: const Key('input_total_bs_manual'),
                                controller: _totalBsManualCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Bolívares finales cobrados (editable)',
                                  labelStyle: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  prefixText: 'Bs. ',
                                  prefixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (_) {
                                  _bolivaresAjustadosManualmente = true;
                                  _recalcularTotalUsd();
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _selectedMoneda == 'EUR'
                                    ? '≈ ${_totalUsdtCalculado.toStringAsFixed(2)} USDT P2P  •  €${(tUsdt > 0 ? (totalBs / tUsdt) : val).toStringAsFixed(2)} EUR  •  \$${equivUsdBcv.toStringAsFixed(2)} USD'
                                    : '≈ ${_totalUsdtCalculado.toStringAsFixed(2)} USDT P2P  •  \$${equivUsdBcv.toStringAsFixed(2)} USD Oficial  •  €${_totalEurCalculado.toStringAsFixed(2)} EUR',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardLighter,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Se guardará directamente en $_selectedMoneda (Efectivo / Tarjeta / Divisa)',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    TextFormField(
                      controller: _totalOriginalCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Monto Total ($_selectedMoneda)',
                        prefixIcon: const Icon(Icons.currency_bitcoin, color: AppColors.primaryDark),
                        helperText: 'Paridad 1:1 con USD',
                      ),
                      onChanged: (val) {
                        _totalUsdCtrl.text = val;
                        _recalcularTotalUsd();
                      },
                      validator: (val) => validatePositiveAmount(val),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardLighter,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Builder(builder: (context) {
                              final val = tryParseAmount(_totalOriginalCtrl.text, isPrice: false) ?? 0.0;
                              final tUsd = (_tasaUsdFecha != null && _tasaUsdFecha! > 0) ? _tasaUsdFecha! : settings.tasaCambioVesUsd;
                              final tEur = (_tasaEurFecha != null && _tasaEurFecha! > 0) ? _tasaEurFecha! : settings.tasaCambioVesEur;
                              final tUsdt = (_tasaUsdtFecha != null && _tasaUsdtFecha! > 0) ? _tasaUsdtFecha! : settings.tasaCambioVesUsdt;
                              final bsEquiv = val * (tUsdt > 0 ? tUsdt : (tUsd > 0 ? tUsd : 1.0));
                              final eurEquiv = (tEur > 0 && bsEquiv > 0) ? (bsEquiv / tEur) : (tEur > 0 && tUsd > 0 ? (val * tUsd / tEur) : val);
                              return Text(
                                'Se guardará en USDT (≈ \$${val.toStringAsFixed(2)} USD 1:1  •  €${eurEquiv.toStringAsFixed(2)} EUR  •  Bs. ${bsEquiv.toStringAsFixed(2)})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  ),
),
  );
  }

  void _verImagenCompleta(File file) {
    ReceiptViewerDialog.show(
      context,
      imagePath: file.path,
      title: _comercioCtrl.text.trim().isNotEmpty ? _comercioCtrl.text.trim() : 'Comprobante',
      subtitle: DateFormatter.formatDate(_selectedFecha),
      amount: _totalUsdCtrl.text.trim().isNotEmpty ? '\$ ${_totalUsdCtrl.text.trim()}' : null,
    );
  }

  Widget _buildImageHeader() {
    File? fileToShow;

    if (_imageDeleted) {
      fileToShow = null;
    } else if (_pickedImage != null) {
      fileToShow = _pickedImage;
    } else if (widget.imageFile != null) {
      fileToShow = widget.imageFile;
    } else if (widget.existingGasto?.rutaFotoLocal != null) {
      final file = File(widget.existingGasto!.rutaFotoLocal!);
      if (file.existsSync()) {
        fileToShow = file;
      }
    }

    if (fileToShow == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: OutlinedButton.icon(
          onPressed: _showImagePickerOptions,
          icon: const Icon(Icons.add_a_photo, color: AppColors.primaryDark),
          label: const Text(
            'Adjuntar comprobante (Opcional)',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.border),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => _verImagenCompleta(fileToShow!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 140,
                width: double.infinity,
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(fileToShow, fit: BoxFit.cover),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
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
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: _showImagePickerOptions,
                icon: const Icon(Icons.edit, size: 18, color: AppColors.textPrimary),
                label: const Text('Cambiar comprobante', style: TextStyle(color: AppColors.textPrimary)),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _imageDeleted = true;
                    _pickedImage = null;
                  });
                },
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                label: const Text('Eliminar comprobante', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final mediaQuery = MediaQuery.of(ctx);
        final systemBottom = mediaQuery.padding.bottom > 0
            ? mediaQuery.padding.bottom
            : mediaQuery.viewPadding.bottom;
        final effectiveBottom = (systemBottom > 0 ? systemBottom : 16.0) + 20.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, effectiveBottom),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Adjuntar comprobante',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.camera_alt, color: AppColors.primaryDark),
                    title: const Text('Tomar foto con la cámara'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: AppColors.primaryDark),
                    title: const Text('Elegir de la galería'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
