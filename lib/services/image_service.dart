import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageService {
  /// Comprime la imagen para reducir el peso antes de enviarla a Gemini
  /// Reduce el tiempo de subida de 5-10MB a menos de 300KB
  static Future<Uint8List> compressImage(File file) async {
    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1200,
        minHeight: 1600,
        quality: 80,
        format: CompressFormat.jpeg,
      );

      if (compressedBytes != null) {
        return compressedBytes;
      }
    } catch (_) {
      // Fallback seguro a lectura directa de bytes si falla el compresor nativo
    }
    return await file.readAsBytes();
  }

  /// Guarda permanentemente la foto si el usuario activó la opción en ajustes
  static Future<String> saveImagePermanently(File tempFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'recibo_${DateTime.now().millisecondsSinceEpoch}${p.extension(tempFile.path)}';
    final targetPath = p.join(appDir.path, fileName);

    final savedImage = await tempFile.copy(targetPath);
    return savedImage.path;
  }

  /// Limpia de inmediato el archivo temporal si no se va a conservar
  static Future<void> deleteTempFile(File? file) async {
    if (file != null && await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
}
