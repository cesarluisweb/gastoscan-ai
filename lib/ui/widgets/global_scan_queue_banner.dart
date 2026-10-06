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
                  onPressed: () => _confirmCancelOrDiscard(context, scanQueue, isProcessing: true),
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
                    await scanQueue.processPendingItems(forceRetry: true);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                  tooltip: 'Descartar',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    if (scanQueue.pendingItems.length <= 1) {
                      final int? singleId = scanQueue.pendingItems.isNotEmpty
                          ? (scanQueue.pendingItems.first['id'] as num?)?.toInt()
                          : null;
                      _confirmCancelOrDiscard(context, scanQueue, isProcessing: false, itemId: singleId);
                    } else {
                      _showQueueDiscardSheet(context, scanQueue);
                    }
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

  Future<void> _showQueueDiscardSheet(
    BuildContext context,
    ScanQueueProvider scanQueue,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetCtx) {
        return Consumer<ScanQueueProvider>(
          builder: (ctx, queue, _) {
            final items = queue.pendingItems;
            if (items.isEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.of(ctx).canPop()) {
                  Navigator.of(ctx).pop();
                }
              });
              return const SizedBox.shrink();
            }

            return Material(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                top: false,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(ctx).size.height * 0.75,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long, color: AppColors.primaryDark),
                            const SizedBox(width: 8),
                            Text(
                              'Comprobantes en cola (${items.length})',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_sweep, size: 18, color: AppColors.error),
                              label: const Text(
                                'Descartar todos',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => AlertDialog(
                                    title: const Text('¿Descartar todos?'),
                                    content: const Text(
                                      '¿Deseas descartar todos los comprobantes de la cola? Esta acción no se puede deshacer.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(dCtx).pop(false),
                                        child: const Text('Volver'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(dCtx).pop(true),
                                        style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                        child: const Text('Descartar todos', style: TextStyle(fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await queue.cancelProcessing();
                                  if (Navigator.of(ctx).canPop()) {
                                    Navigator.of(ctx).pop();
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (listCtx, index) {
                            final item = items[index];
                            final int id = item['id'];
                            final String imagePath = item['image_path'] ?? '';
                            final String status = item['status'] ?? 'pending';
                            final String? lastError = item['last_error'] as String?;
                            final File imageFile = File(imagePath);

                            return Material(
                              type: MaterialType.transparency,
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: imageFile.existsSync()
                                      ? Image.file(
                                          imageFile,
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          width: 44,
                                          height: 44,
                                          color: Colors.grey.shade200,
                                          child: const Icon(Icons.image_not_supported, size: 20, color: Colors.grey),
                                        ),
                                ),
                                title: Text(
                                  status == 'error'
                                      ? 'Error de procesamiento'
                                      : (status == 'processing' ? 'Procesando con IA...' : 'En cola de espera'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: status == 'error' ? AppColors.error : AppColors.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  lastError?.isNotEmpty == true
                                      ? lastError!
                                      : (status == 'processing' ? 'Extrayendo datos de la factura' : 'Pendiente por analizar'),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                                  tooltip: 'Descartar este comprobante',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dCtx) => AlertDialog(
                                        title: const Text('¿Descartar este comprobante?'),
                                        content: const Text(
                                          '¿Deseas descartar esta factura de la cola? Esta acción no se puede deshacer.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(dCtx).pop(false),
                                            child: const Text('Volver'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(dCtx).pop(true),
                                            style: TextButton.styleFrom(foregroundColor: AppColors.error),
                                            child: const Text('Descartar', style: TextStyle(fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await queue.removeItem(id);
                                    }
                                  },
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
            );
          },
        );
      },
    );
  }

  Future<void> _confirmCancelOrDiscard(
    BuildContext context,
    ScanQueueProvider scanQueue, {
    required bool isProcessing,
    int? itemId,
  }) async {
    final String title;
    final String content;

    if (isProcessing) {
      title = '¿Detener escaneo?';
      content = 'Se cancelará el análisis actual y se descartarán los comprobantes pendientes de la cola.';
    } else if (itemId != null) {
      title = '¿Descartar este comprobante?';
      content = '¿Deseas descartar esta factura de la cola? Esta acción no se puede deshacer.';
    } else {
      title = '¿Descartar comprobantes?';
      content = '¿Deseas descartar las facturas pendientes de la cola? Esta acción no se puede deshacer.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Descartar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (itemId != null) {
        await scanQueue.removeItem(itemId);
      } else {
        await scanQueue.cancelProcessing();
      }
    }
  }
}
