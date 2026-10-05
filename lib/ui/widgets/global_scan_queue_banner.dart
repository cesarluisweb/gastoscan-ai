import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/gemini_extraction_result.dart';
import '../../providers/scan_queue_provider.dart';
import '../screens/review_expense_screen.dart';

/// Banner flotante global superior que unifica todos los estados de la cola de escaneo
/// (listo para revisar, procesando con IA, guardado sin conexión y error).
class GlobalScanQueueBanner extends StatelessWidget {
  const GlobalScanQueueBanner({super.key});

  @override
  Widget build(BuildContext context) {
    ScanQueueProvider? nullableQueue;
    try {
      nullableQueue = Provider.of<ScanQueueProvider>(context);
    } catch (_) {
      nullableQueue = null;
    }

    if (nullableQueue == null) {
      return const SizedBox.shrink();
    }

    final ScanQueueProvider scanQueue = nullableQueue;

    // Los estados se apilan verticalmente (uno debajo del otro) para que
    // ninguno oculte a otro: p. ej. "lista para revisar" + "procesando".
    final List<Widget> banners = [];

    // 1. Facturas listas para revisar
    if (scanQueue.readyItems.isNotEmpty) {
      final count = scanQueue.readyItems.length;
      final label = count == 1
          ? 'Factura lista para revisar'
          : '$count facturas listas para revisar';

      banners.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          key: const Key('global_scan_ready_banner'),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF5), // Fondo cálido sutil Asistente IA
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFEF08A)), // Borde amarillo sutil
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                final item = scanQueue.readyItems.first;
                final data = jsonDecode(item['extracted_data']);
                final result = GeminiExtractionResult.fromJson(data);
                final file = File(item['image_path']);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReviewExpenseScreen(
                      imageFile: file.existsSync() ? file : null,
                      extractedData: result,
                      queueItemId: item['id'],
                    ),
                  ),
                ).then((_) {
                  scanQueue.loadReadyItems();
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF9C3),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFDE047), width: 1),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.receipt_long,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Toca para validar y guardar',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Revisar',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(Icons.arrow_forward, size: 11, color: AppColors.textPrimary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ));
    }

    if (scanQueue.isProcessing) {
      // 2. Procesamiento activo con IA (se muestra debajo de "lista para revisar")
      final count = scanQueue.pendingCount > 0 ? scanQueue.pendingCount : 1;
      final itemText = count == 1 ? 'factura' : 'facturas';

      banners.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          key: const Key('global_scan_processing_banner'),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF5), // Fondo cálido sutil Asistente IA
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFEF08A)), // Borde amarillo sutil
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF9C3),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFDE047), width: 1),
                  ),
                  child: const Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                          ),
                        ),
                        Icon(
                          Icons.auto_awesome,
                          size: 11,
                          color: AppColors.primaryDark,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Procesando $count $itemText con IA...',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Extrayendo datos en segundo plano',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    await scanQueue.cancelProcessing();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ));
    } else if (scanQueue.pendingItems.isNotEmpty) {
      // 3. Ítems pendientes cuando no hay proceso activo (sin conexión o error)
      final count = scanQueue.pendingCount;
      final itemText = count == 1 ? 'factura' : 'facturas';
      final isOffline = scanQueue.isWaitingForConnection;

      final title = isOffline
          ? '$count $itemText guardada${count == 1 ? '' : 's'} sin conexión'
          : 'Pausado: $count $itemText';
      final subtitle = isOffline
          ? 'Se procesará automáticamente al reconectar.'
          : (scanQueue.lastError ?? 'Fallo al procesar. Toca reintentar.');
      final icon = isOffline
          ? Icons.wifi_off_rounded
          : Icons.warning_amber_rounded;
      final iconColor = isOffline
          ? AppColors.textSecondary
          : AppColors.warning;

      final backgroundColor = isOffline
          ? AppColors.card
          : const Color(0xFFFFFBEB);
      final borderColor = isOffline
          ? AppColors.border
          : const Color(0xFFFDE68A);
      final iconContainerBg = isOffline
          ? const Color(0xFFF3F4F6)
          : const Color(0xFFFEF3C7);
      final iconContainerBorder = isOffline
          ? AppColors.border
          : const Color(0xFFF59E0B).withOpacity(0.3);

      banners.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Container(
          key: isOffline
              ? const Key('global_scan_offline_banner')
              : const Key('global_scan_error_banner'),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconContainerBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: iconContainerBorder, width: 1),
                  ),
                  child: Center(
                    child: Icon(icon, color: iconColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primaryDark, size: 20),
                  tooltip: 'Reintentar ahora',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await scanQueue.processPendingItems();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  tooltip: 'Descartar',
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    await scanQueue.cancelProcessing();
                  },
                ),
              ],
            ),
          ),
        ),
      ));
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: banners.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: banners,
              ),
            ),
    );
  }
}
