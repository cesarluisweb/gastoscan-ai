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

class ReceiptGalleryScreen extends StatelessWidget {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final gastos = Provider.of<GastoProvider>(context).gastos;
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gastoProvider = Provider.of<GastoProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final mesNombre = DateFormatter.getMonthName(gastoProvider.selectedMonth);
    final anio = gastoProvider.selectedYear;

    final List<GastoModel> receipts = _validReceipts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobantes Guardados'),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack ?? () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: widget.showBackButton,
      ),
      body: Column(
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
                          side: const BorderSide(color: AppColors.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () {
                            ReceiptViewerDialog.show(
                              context,
                              imagePath: gasto.rutaFotoLocal!,
                              title: gasto.comercio,
                              subtitle: DateFormatter.formatDate(gasto.fecha),
                              amount: formattedAmount,
                            );
                          },
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Imagen de fondo
                              Image.file(
                                file,
                                fit: BoxFit.cover,
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
                              // Botón de lupa en esquina superior
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
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
    );
  }
}
