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

  /// Elimina los comprobantes y archivos temporales propios de la aplicación.
  /// No borra archivos arbitrarios ni fotos exportadas del usuario:
  /// solo elimina archivos dentro de directorios de la app (documentos o caché)
  /// o archivos con prefijo interno 'recibo_'.
  static Future<void> limpiarArchivosApp({List<String>? rutasConocidas}) async {
    try {
      Directory? appDir;
      try {
        appDir = await getApplicationDocumentsDirectory();
      } catch (_) {}

      Directory? tempDir;
      try {
        tempDir = await getTemporaryDirectory();
      } catch (_) {}

      // 1. Borrar archivos de rutas conocidas únicamente si residen en appDir, tempDir o son 'recibo_'
      if (rutasConocidas != null) {
        for (final ruta in rutasConocidas) {
          if (ruta.trim().isEmpty) continue;
          try {
            final file = File(ruta);
            if (await file.exists()) {
              final esArchivoApp = (appDir != null && p.isWithin(appDir.path, file.path)) ||
                  (tempDir != null && p.isWithin(tempDir.path, file.path)) ||
                  p.basename(file.path).startsWith('recibo_');
              if (esArchivoApp) {
                await file.delete();
              }
            }
          } catch (_) {}
        }
      }

      // 2. Limpiar comprobantes internos en el directorio de documentos de la app (prefijo 'recibo_')
      if (appDir != null && await appDir.exists()) {
        try {
          final entidades = appDir.listSync();
          for (final entidad in entidades) {
            if (entidad is File && p.basename(entidad.path).startsWith('recibo_')) {
              try {
                await entidad.delete();
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // 3. Limpiar temporales creados por la app en tempDir
      if (tempDir != null && await tempDir.exists()) {
        try {
          final entidades = tempDir.listSync();
          for (final entidad in entidades) {
            if (entidad is File) {
              final nombre = p.basename(entidad.path);
              if (nombre.startsWith('recibo_') ||
                  nombre.startsWith('scan_') ||
                  nombre.startsWith('scaled_')) {
                try {
                  await entidad.delete();
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint("Error al limpiar archivos de la app: $e");
    }
  }
}
