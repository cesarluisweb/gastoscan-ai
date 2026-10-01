import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_picker/image_picker.dart';

/// Servicio de captura documental utilizando Google ML Kit Document Scanner
/// con degradación elegante a cámara estándar (ImagePicker) ante cualquier fallo.
class DocumentScannerService {
  DocumentScanner? _scanner;
  final ImagePicker _fallbackPicker;

  DocumentScannerService({
    DocumentScanner? scanner,
    ImagePicker? fallbackPicker,
  })  : _scanner = scanner,
        _fallbackPicker = fallbackPicker ?? ImagePicker();

  DocumentScanner _getScanner() {
    return _scanner ??= DocumentScanner(
      options: DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.full,
        pageLimit: 1,
        isGalleryImport: false,
      ),
    );
  }

  /// Inicia el flujo de escaneo. Retorna una lista con las rutas de los archivos
  /// corregidos y limpios. Si el usuario cancela, retorna una lista vacía.
  Future<List<String>> scanDocuments() async {
    try {
      // 1. Intento primario con Document Scanner de Google
      final result = await _getScanner().scanDocument();
      if (result.images != null && result.images!.isNotEmpty) {
        return result.images!;
      }
      return [];
    } catch (e) {
      debugPrint('DocumentScanner no disponible o falló: $e. Activando fallback a cámara.');
      // 2. Degradación elegante: Fallback transparente a cámara convencional
      return await _scanWithFallbackCamera();
    }
  }

  /// Captura alternativa con la cámara nativa si el módulo de Play Services no está listo
  Future<List<String>> _scanWithFallbackCamera() async {
    try {
      final pickedFile = await _fallbackPicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (pickedFile != null && File(pickedFile.path).existsSync()) {
        return [pickedFile.path];
      }
    } catch (fallbackError) {
      debugPrint('Error en fallback de cámara: $fallbackError');
    }
    return [];
  }

  void dispose() {
    _scanner?.close();
  }
}
