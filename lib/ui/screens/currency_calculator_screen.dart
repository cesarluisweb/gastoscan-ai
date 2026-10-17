import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/amount_parser.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../data/models/item_gasto_model.dart';
import '../../providers/settings_provider.dart';
import 'review_expense_screen.dart';

enum TipoTasaCalculadora { dolarBcv, euroBcv, usdtBinance, personalizada }

class CurrencyCalculatorScreen extends StatefulWidget {
  final bool showBackButton;
  final VoidCallback? onBack;

  const CurrencyCalculatorScreen({
    Key? key,
    this.showBackButton = true,
    this.onBack,
  }) : super(key: key);

  @override
  State<CurrencyCalculatorScreen> createState() => _CurrencyCalculatorScreenState();
}

class _CurrencyCalculatorScreenState extends State<CurrencyCalculatorScreen> {
  late TextEditingController _divisaCtrl;
  late TextEditingController _vesCtrl;
  late TextEditingController _customRateCtrl;
  late FocusNode _divisaFocusNode;
  late FocusNode _vesFocusNode;

  String _selectedCurrency = 'USD';
  TipoTasaCalculadora _selectedTipoTasa = TipoTasaCalculadora.dolarBcv;
  double _customRate = 0.0;
  bool _isSyncing = false;
  bool _isVesOnTop = false;

  @override
  void initState() {
    super.initState();
    _divisaCtrl = TextEditingController();
    _vesCtrl = TextEditingController();
    _customRateCtrl = TextEditingController();
    _divisaFocusNode = FocusNode();
    _vesFocusNode = FocusNode();

    _divisaFocusNode.addListener(() {
      if (_divisaFocusNode.hasFocus && _divisaCtrl.text.isNotEmpty) {
        _divisaCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _divisaCtrl.text.length);
      }
    });

    _vesFocusNode.addListener(() {
      if (_vesFocusNode.hasFocus && _vesCtrl.text.isNotEmpty) {
        _vesCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _vesCtrl.text.length);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalcularDesdeDivisa();
    });
  }

  @override
  void dispose() {
    _divisaCtrl.dispose();
    _vesCtrl.dispose();
    _customRateCtrl.dispose();
    _divisaFocusNode.dispose();
    _vesFocusNode.dispose();
    super.dispose();
  }

  double _obtenerTasaActiva(SettingsProvider settings) {
    switch (_selectedTipoTasa) {
      case TipoTasaCalculadora.dolarBcv:
        return settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : AppConstants.defaultTasaCambio;
      case TipoTasaCalculadora.euroBcv:
        return settings.tasaCambioVesEur > 0 ? settings.tasaCambioVesEur : settings.tasaCambioVesUsd;
      case TipoTasaCalculadora.usdtBinance:
        return settings.tasaCambioVesUsdt > 0 ? settings.tasaCambioVesUsdt : settings.tasaCambioVesUsd;
      case TipoTasaCalculadora.personalizada:
        return _customRate > 0 ? _customRate : (settings.tasaCambioVesUsd > 0 ? settings.tasaCambioVesUsd : AppConstants.defaultTasaCambio);
    }
  }

  void _recalcularDesdeDivisa() {
    if (_isSyncing) return;
    _isSyncing = true;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final tasa = _obtenerTasaActiva(settings);
    final double? montoDivisa = tryParseAmount(_divisaCtrl.text, isPrice: false);

    if (montoDivisa == null || montoDivisa <= 0) {
      _vesCtrl.text = '';
    } else {
      final double montoVes = montoDivisa * tasa;
      _vesCtrl.text = montoVes.toStringAsFixed(2);
    }
    _isSyncing = false;
  }

  void _recalcularDesdeVes() {
    if (_isSyncing) return;
    _isSyncing = true;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final tasa = _obtenerTasaActiva(settings);
    final double? montoVes = tryParseAmount(_vesCtrl.text, isPrice: false);

    if (montoVes == null || montoVes <= 0 || tasa <= 0) {
      _divisaCtrl.text = '';
    } else {
      final double montoDivisa = montoVes / tasa;
      _divisaCtrl.text = montoDivisa.toStringAsFixed(2);
    }
    _isSyncing = false;
  }

  void _seleccionarTipoTasa(TipoTasaCalculadora tipo, SettingsProvider settings) {
    setState(() {
      _selectedTipoTasa = tipo;
      if (tipo == TipoTasaCalculadora.euroBcv) {
        _selectedCurrency = 'EUR';
      } else if (tipo == TipoTasaCalculadora.usdtBinance) {
        _selectedCurrency = 'USDT';
      } else if (tipo == TipoTasaCalculadora.dolarBcv) {
        _selectedCurrency = 'USD';
      }
    });
    if (_isVesOnTop) {
      _recalcularDesdeVes();
    } else {
      _recalcularDesdeDivisa();
    }
  }

  void _copiarMonto() {
    if (_isVesOnTop) {
      final double? montoDivisa = tryParseAmount(_divisaCtrl.text, isPrice: false);
      if (montoDivisa == null || montoDivisa <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un monto para copiar.')),
        );
        return;
      }

      final String textoCopiar = montoDivisa.toStringAsFixed(2);
      Clipboard.setData(ClipboardData(text: textoCopiar));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Monto en $_selectedCurrency copiado: $_selectedCurrency $textoCopiar',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      final double? montoVes = tryParseAmount(_vesCtrl.text, isPrice: false);
      if (montoVes == null || montoVes <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa un monto para copiar.')),
        );
        return;
      }

      final String textoCopiar = montoVes.toStringAsFixed(2);
      Clipboard.setData(ClipboardData(text: textoCopiar));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Monto en Bs. copiado: Bs. ${CurrencyFormatter.formatVes(montoVes)}',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _registrarComoGasto(double activeRate) {
    final double? montoVes = tryParseAmount(_vesCtrl.text, isPrice: false);
    final double? montoDivisa = tryParseAmount(_divisaCtrl.text, isPrice: false);

    if ((montoVes == null || montoVes <= 0) && (montoDivisa == null || montoDivisa <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un monto válido para registrar el gasto.')),
      );
      return;
    }

    final double totalFinal;
    final String monedaFinal;
    if (_isVesOnTop) {
      totalFinal = (montoVes != null && montoVes > 0) ? montoVes : (montoDivisa! * activeRate);
      monedaFinal = 'VES';
    } else {
      totalFinal = (montoDivisa != null && montoDivisa > 0) ? montoDivisa : (montoVes! / activeRate);
      monedaFinal = _selectedCurrency;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewExpenseScreen(
          extractedData: GeminiExtractionResult(
            comercio: '',
            fecha: DateTime.now().toIso8601String().substring(0, 10),
            totalOriginal: totalFinal,
            impuestoIva: 0.0,
            moneda: monedaFinal,
            tasaCambioDetectada: activeRate,
            items: [
              ItemGastoModel(
                descripcion: 'Gasto calculado',
                cantidad: 1.0,
                precioUnitario: (totalFinal * 100).round(),
                total: (totalFinal * 100).round(),
                categoria: 'Otros',
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
    final double tasaActiva = _obtenerTasaActiva(settings);
    final double? montoDivisaActual = tryParseAmount(_divisaCtrl.text, isPrice: false);
    final double montoBaseDivisa = (montoDivisaActual != null && montoDivisaActual > 0)
        ? montoDivisaActual
        : 1.0;

    final double tasaUsd = settings.tasaCambioVesUsd > 0
        ? settings.tasaCambioVesUsd
        : AppConstants.defaultTasaCambio;
    final double tasaEur = settings.tasaCambioVesEur > 0
        ? settings.tasaCambioVesEur
        : settings.tasaCambioVesUsd;
    final double tasaUsdt = settings.tasaCambioVesUsdt > 0
        ? settings.tasaCambioVesUsdt
        : settings.tasaCambioVesUsd;

    final double brechaUsdtBcv = (tasaUsd > 0 && tasaUsdt > 0)
        ? ((tasaUsdt - tasaUsd) / tasaUsd) * 100
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Calculadora Cambiaria'),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else {
                    Navigator.pop(context);
                  }
                },
              )
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Selector de Chips de Tasa Rápida
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRateChip(
                  key: const Key('calc_chip_dolar_bcv'),
                  label: 'Dólar BCV',
                  sub: 'Bs. ${tasaUsd.toStringAsFixed(2)}',
                  isSelected: _selectedTipoTasa == TipoTasaCalculadora.dolarBcv,
                  onTap: () => _seleccionarTipoTasa(TipoTasaCalculadora.dolarBcv, settings),
                ),
                const SizedBox(width: 8),
                _buildRateChip(
                  key: const Key('calc_chip_euro_bcv'),
                  label: 'Euro BCV',
                  sub: 'Bs. ${tasaEur.toStringAsFixed(2)}',
                  isSelected: _selectedTipoTasa == TipoTasaCalculadora.euroBcv,
                  onTap: () => _seleccionarTipoTasa(TipoTasaCalculadora.euroBcv, settings),
                ),
                const SizedBox(width: 8),
                _buildRateChip(
                  key: const Key('calc_chip_usdt'),
                  label: 'USDT Binance',
                  sub: 'Bs. ${tasaUsdt.toStringAsFixed(2)}',
                  isSelected: _selectedTipoTasa == TipoTasaCalculadora.usdtBinance,
                  onTap: () => _seleccionarTipoTasa(TipoTasaCalculadora.usdtBinance, settings),
                ),
                const SizedBox(width: 8),
                _buildRateChip(
                  key: const Key('calc_chip_custom'),
                  label: 'Personalizada ✏️',
                  sub: _customRate > 0 ? 'Bs. ${_customRate.toStringAsFixed(2)}' : 'Manual',
                  isSelected: _selectedTipoTasa == TipoTasaCalculadora.personalizada,
                  onTap: () => _seleccionarTipoTasa(TipoTasaCalculadora.personalizada, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Campo Tasa Personalizada (si está seleccionada)
          if (_selectedTipoTasa == TipoTasaCalculadora.personalizada) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryDark),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tasa de Cambio Personalizada (Bs. / divisa)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const Key('calc_custom_rate_input'),
                    controller: _customRateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: 'Bs. ',
                      hintText: '0.00',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      final parsed = tryParseAmount(val, isPrice: false);
                      setState(() {
                        _customRate = parsed ?? 0.0;
                      });
                      if (_isVesOnTop) {
                        _recalcularDesdeVes();
                      } else {
                        _recalcularDesdeDivisa();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Tarjeta Principal de Conversión Bidireccional
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
                if (!_isVesOnTop) ...[
                  _buildDivisaField(tasaActiva),
                  const SizedBox(height: 12),
                  Center(child: _buildSwapPill(tasaActiva)),
                  const SizedBox(height: 12),
                  _buildVesField(),
                ] else ...[
                  _buildVesField(),
                  const SizedBox(height: 12),
                  Center(child: _buildSwapPill(tasaActiva)),
                  const SizedBox(height: 12),
                  _buildDivisaField(tasaActiva),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botones de Acción Rápida (Copiar y Registrar)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: Key(_isVesOnTop ? 'calc_copy_divisa_button' : 'calc_copy_ves_button'),
                  onPressed: _copiarMonto,
                  icon: const Icon(Icons.copy, size: 18, color: AppColors.textPrimary),
                  label: Text(
                    _isVesOnTop ? 'Copiar $_selectedCurrency' : 'Copiar Bs.',
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('calc_register_expense_button'),
                  onPressed: () => _registrarComoGasto(tasaActiva),
                  icon: const Icon(Icons.add, size: 18, color: Colors.black),
                  label: const Text(
                    'Registrar gasto',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cuadro Comparativo Simultáneo de Tasas y Brecha
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
                      'Comparativa simultánea',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Para ${montoBaseDivisa.toStringAsFixed(2)} divisa',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildComparisonRow(
                  title: 'Dólar BCV',
                  rate: 'Bs. ${tasaUsd.toStringAsFixed(2)}',
                  total: 'Bs. ${CurrencyFormatter.formatVes(montoBaseDivisa * tasaUsd).replaceAll('Bs. ', '')}',
                  isHighlighted: _selectedTipoTasa == TipoTasaCalculadora.dolarBcv,
                ),
                const Divider(height: 16, color: AppColors.border),
                _buildComparisonRow(
                  title: 'Euro BCV',
                  rate: 'Bs. ${tasaEur.toStringAsFixed(2)}',
                  total: 'Bs. ${CurrencyFormatter.formatVes(montoBaseDivisa * tasaEur).replaceAll('Bs. ', '')}',
                  isHighlighted: _selectedTipoTasa == TipoTasaCalculadora.euroBcv,
                ),
                const Divider(height: 16, color: AppColors.border),
                _buildComparisonRow(
                  title: 'USDT Binance',
                  rate: 'Bs. ${tasaUsdt.toStringAsFixed(2)}',
                  total: 'Bs. ${CurrencyFormatter.formatVes(montoBaseDivisa * tasaUsdt).replaceAll('Bs. ', '')}',
                  isHighlighted: _selectedTipoTasa == TipoTasaCalculadora.usdtBinance,
                ),
                const SizedBox(height: 14),

                // Indicador de Brecha Cambiaria
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardLighter,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, size: 18, color: AppColors.primaryDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Brecha USDT vs Dólar BCV: ${brechaUsdtBcv >= 0 ? '+' : ''}${brechaUsdtBcv.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Descargo oficial de fuentes públicas
          Container(
            key: const Key('calc_bcv_disclaimer_card'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text(
                      'Aviso legal sobre tasas oficiales',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Las tasas «Dólar BCV» y «Euro BCV» corresponden a información pública publicada por el Banco Central de Venezuela (BCV). Rinde Más es una aplicación independiente y no representa, no está afiliada ni cuenta con respaldo del BCV ni de ninguna entidad gubernamental.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  key: const Key('calc_bcv_source_link'),
                  onTap: _abrirFuenteBcv,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Fuente oficial: www.bcv.org.ve',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.open_in_new, size: 12, color: AppColors.textPrimary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildRateChip({
    required Key key,
    required String label,
    required String sub,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.black : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.black87 : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivisaField(double tasaActiva) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Monto en $_selectedCurrency',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('calc_divisa_input'),
          controller: _divisaCtrl,
          focusNode: _divisaFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              _selectedCurrency == 'EUR'
                  ? Icons.euro
                  : (_selectedCurrency == 'USDT' ? Icons.currency_bitcoin : Icons.attach_money),
              color: AppColors.primaryDark,
            ),
            suffixIcon: _divisaCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      _divisaCtrl.clear();
                      _recalcularDesdeDivisa();
                      setState(() {});
                    },
                  )
                : null,
            hintText: '0.00',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onTap: () {
            if (_divisaCtrl.text.isNotEmpty) {
              _divisaCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _divisaCtrl.text.length);
            }
          },
          onChanged: (_) {
            _recalcularDesdeDivisa();
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildVesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monto en Bolívares (VES)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          key: const Key('calc_ves_input'),
          controller: _vesCtrl,
          focusNode: _vesFocusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixText: 'Bs. ',
            prefixStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            suffixIcon: _vesCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      _vesCtrl.clear();
                      _recalcularDesdeVes();
                      setState(() {});
                    },
                  )
                : null,
            hintText: '0.00',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onTap: () {
            if (_vesCtrl.text.isNotEmpty) {
              _vesCtrl.selection = TextSelection(baseOffset: 0, extentOffset: _vesCtrl.text.length);
            }
          },
          onChanged: (_) {
            _recalcularDesdeVes();
            setState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildSwapPill(double tasaActiva) {
    return InkWell(
      key: const Key('calc_swap_button'),
      onTap: () {
        setState(() {
          _isVesOnTop = !_isVesOnTop;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cardLighter,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_vert, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: 4),
            Text(
              '1 $_selectedCurrency = Bs. ${tasaActiva.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonRow({
    required String title,
    required String rate,
    required String total,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.cardLighter : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                rate,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          Text(
            total,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFuenteBcv() async {
    final uri = Uri.parse('https://www.bcv.org.ve/');
    try {
      bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {}
  }
}

