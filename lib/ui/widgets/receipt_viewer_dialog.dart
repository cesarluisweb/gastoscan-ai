import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../services/image_service.dart';

class ReceiptViewerDialog extends StatelessWidget {
  final String imagePath;
  final String? title;
  final String? subtitle;
  final String? amount;

  const ReceiptViewerDialog({
    Key? key,
    required this.imagePath,
    this.title,
    this.subtitle,
    this.amount,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    String? title,
    String? subtitle,
    String? amount,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReceiptViewerDialog(
          imagePath: imagePath,
          title: title,
          subtitle: subtitle,
          amount: amount,
        ),
      ),
    );
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
