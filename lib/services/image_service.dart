import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:gal/gal.dart';

class ImageService {
  /// Comprime la imagen para reducir el peso antes de enviarla a Gemini
  /// Reduce el tiempo de subida de 5-10MB a menos de 300KB
  static Future<Uint8List> compressImage(File file) async {
    try {
      final compressedBytes = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: 1200,
        minHeight: 1600,
        quality: 82,
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

    // Intentar registrar también en la galería de fotos del sistema en el álbum "Rinde Más"
    try {
      await Gal.putImage(savedImage.path, album: 'Rinde Más');
    } catch (e) {
      debugPrint("No se pudo registrar la imagen en la galería del sistema: $e");
    }

    return savedImage.path;
  }

  /// Guarda explícitamente una imagen local en el álbum de la galería del teléfono
  static Future<bool> saveToGallery(String filePath) async {
    try {
      await Gal.putImage(filePath, album: 'Rinde Más');
      return true;
    } catch (e) {
      debugPrint("Error guardando imagen en galería: $e");
      return false;
    }
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
