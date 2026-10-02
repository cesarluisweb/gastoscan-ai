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
    ScanQueueProvider? scanQueue;
    try {
      scanQueue = Provider.of<ScanQueueProvider>(context);
    } catch (_) {
      scanQueue = null;
    }

    if (scanQueue == null) {
      return const SizedBox.shrink();
    }

    Widget content = const SizedBox.shrink();

    // 1. Facturas listas para revisar (máxima prioridad)
    if (scanQueue.readyItems.isNotEmpty) {
      final count = scanQueue.readyItems.length;
      final label = count == 1
          ? 'Factura lista para revisar'
          : '$count facturas listas para revisar';

      content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Material(
          key: const Key('global_scan_ready_banner'),
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.primaryLight,
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
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: AppColors.textPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textPrimary),
                ],
              ),
            ),
          ),
        ),
      );
    } else if (scanQueue.isProcessing) {
      // 2. Procesamiento activo con IA
      final count = scanQueue.pendingCount > 0 ? scanQueue.pendingCount : 1;
      final itemText = count == 1 ? 'factura' : 'facturas';

      content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Material(
          key: const Key('global_scan_processing_banner'),
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: const [
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
                      size: 12,
                      color: AppColors.primaryDark,
                    ),
                  ],
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
                          fontSize: 12,
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
      );
    } else if (scanQueue.pendingItems.isNotEmpty) {
      // 3. Ítems pendientes cuando no hay proceso activo
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

      content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Material(
          key: isOffline
              ? const Key('global_scan_offline_banner')
              : const Key('global_scan_error_banner'),
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          color: AppColors.card,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOffline ? AppColors.border : AppColors.warning,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
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
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: content,
    );
  }
}
