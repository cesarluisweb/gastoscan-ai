import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/gasto_model.dart';
import '../../providers/gasto_provider.dart';
import '../../services/image_service.dart';
import '../screens/review_expense_screen.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final String imagePath;
  final String? title;
  final String? subtitle;
  final String? amount;
  final GastoModel? gasto;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;

  const ReceiptViewerDialog({
    Key? key,
    required this.imagePath,
    this.title,
    this.subtitle,
    this.amount,
    this.gasto,
    this.onDelete,
    this.onEdit,
  }) : super(key: key);

  static Future<bool?> show(
    BuildContext context, {
    required String imagePath,
    String? title,
    String? subtitle,
    String? amount,
    GastoModel? gasto,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
  }) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReceiptViewerDialog(
          imagePath: imagePath,
          title: title,
          subtitle: subtitle,
          amount: amount,
          gasto: gasto,
          onDelete: onDelete,
          onEdit: onEdit,
        ),
      ),
    );
  }

  Future<void> _confirmarYEliminarFoto(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Eliminar foto del comprobante?',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'La foto se borrará del teléfono para liberar espacio.\n\nEl registro del gasto, sus montos y detalles se conservarán intactos en tu historial.',
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
            child: const Text('Eliminar foto'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      if (onDelete != null) {
        onDelete!();
        Navigator.pop(context, true);
      } else if (gasto != null) {
        final provider = Provider.of<GastoProvider>(context, listen: false);
        final ok = await provider.eliminarFotoComprobante(gasto!);
        if (context.mounted) {
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Foto del comprobante eliminada del teléfono.'),
                backgroundColor: Colors.black87,
              ),
            );
            Navigator.pop(context, true);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudo eliminar el archivo.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      }
    }
  }

  void _abrirEdicionGasto(BuildContext context) {
    if (onEdit != null) {
      onEdit!();
      return;
    }
    if (gasto != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReviewExpenseScreen(existingGasto: gasto),
        ),
      ).then((_) {
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);
    final fileExists = file.existsSync();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title ?? 'Comprobante',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null || amount != null)
              Text(
                [if (subtitle != null) subtitle, if (amount != null) amount].join(' • '),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (gasto != null || onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Ver o editar gasto',
              onPressed: () => _abrirEdicionGasto(context),
            ),
          if (fileExists && (gasto != null || onDelete != null))
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              tooltip: 'Eliminar foto',
              onPressed: () => _confirmarYEliminarFoto(context),
            ),
          if (fileExists) ...[
            IconButton(
              icon: const Icon(Icons.download_outlined, color: Colors.white),
              tooltip: 'Guardar en galería',
              onPressed: () async {
                final success = await ImageService.saveToGallery(imagePath);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Comprobante guardado en el álbum "Rinde Más" de tu galería.'
                            : 'No se pudo guardar en la galería.',
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: success ? Colors.green.shade800 : AppColors.error,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              tooltip: 'Compartir comprobante',
              onPressed: () async {
                try {
                  await Share.shareXFiles(
                    [XFile(imagePath)],
                    text: title != null ? 'Comprobante: $title' : 'Comprobante de compra',
                  );
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No se pudo compartir la imagen.')),
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
      bottomNavigationBar: (gasto != null || onEdit != null)
          ? Container(
              color: Colors.black.withOpacity(0.85),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('btn_ver_editar_gasto_viewer'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text(
                          'Ver o editar gasto',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () => _abrirEdicionGasto(context),
                      ),
                    ),
                    if (fileExists && (gasto != null || onDelete != null)) ...[
                      const SizedBox(width: 12),
                      IconButton.filledTonal(
                        key: const Key('btn_eliminar_foto_viewer_bottom'),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.withOpacity(0.2),
                          foregroundColor: Colors.redAccent.shade100,
                          padding: const EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Eliminar foto del comprobante',
                        onPressed: () => _confirmarYEliminarFoto(context),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : null,
      body: Center(
        child: fileExists
            ? InteractiveViewer(
                panEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.file(
                  file,
                  fit: BoxFit.contain,
                ),
              )
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No se encontró el archivo de imagen.',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
      ),
    );
  }
}
