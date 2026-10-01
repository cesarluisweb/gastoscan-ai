import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/datasources/local/database_helper.dart';
import '../data/datasources/remote/gemini_service.dart';
import '../data/models/gemini_extraction_result.dart';
import '../services/image_service.dart';
import '../services/notification_service.dart';
import '../services/local_ocr_service.dart';
import '../services/semantic_validator.dart';
import 'dart:io';

class ScanQueueProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  final GeminiService _geminiService;
  final LocalOcrService _localOcrService;
  final SemanticValidator _semanticValidator;
  final bool autoProcess;

  List<Map<String, dynamic>> _readyItems = [];
  List<Map<String, dynamic>> get readyItems => _readyItems;

  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> get pendingItems => _pendingItems;
  int get pendingCount => _pendingItems.length;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String? _lastError;
  String? get lastError => _lastError;

  ScanQueueProvider({
    DatabaseHelper? dbHelper,
    GeminiService? geminiService,
    LocalOcrService? localOcrService,
    SemanticValidator? semanticValidator,
    this.autoProcess = true,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _geminiService = geminiService ?? GeminiService(),
        _localOcrService = localOcrService ?? LocalOcrService(),
        _semanticValidator = semanticValidator ?? const SemanticValidator(),
        super() {
    if (autoProcess) {
      loadQueue();
    }
  }

  Future<void> loadQueue() async {
    await loadReadyItems();
    await loadPendingItems();
    processPendingItems(); // Intenta procesar al iniciar
  }

  Future<void> loadReadyItems() async {
    _readyItems = await _dbHelper.getReadyScanQueueItems();
    notifyListeners();
    
    if (_readyItems.isNotEmpty) {
      NotificationService.instance.schedulePendingReviewReminder(
        count: _readyItems.length,
        duration: const Duration(hours: 2),
      );
    } else {
      NotificationService.instance.cancelPendingReviewReminder();
    }
  }

  Future<void> loadPendingItems() async {
    _pendingItems = await _dbHelper.getPendingScanQueueItems();
    notifyListeners();
  }

  /// Persistencia temprana: Extrae el OCR local y guarda el comprobante en SQLite
  /// ANTES de cualquier llamada a la red.
  Future<void> enqueue(String imagePath) async {
    String? initialOcr;
    final file = File(imagePath);
    if (await file.exists()) {
      try {
        final ocrResult = await _localOcrService.processImage(file);
        initialOcr = ocrResult.structuredText;
      } catch (e) {
        debugPrint('Fallo silencioso en OCR previo: $e');
      }
    }

    await _dbHelper.insertScanQueueItem(imagePath, ocrText: initialOcr);
    await loadPendingItems();
    if (autoProcess) {
      processPendingItems();
    }
  }

  Future<void> enqueueMultiple(List<String> imagePaths) async {
    for (final path in imagePaths) {
      String? initialOcr;
      final file = File(path);
      if (await file.exists()) {
        try {
          final ocrResult = await _localOcrService.processImage(file);
          initialOcr = ocrResult.structuredText;
        } catch (e) {
          debugPrint('Fallo silencioso en OCR previo: $e');
        }
      }
      await _dbHelper.insertScanQueueItem(path, ocrText: initialOcr);
    }
    await loadPendingItems();
    if (autoProcess) {
      processPendingItems();
    }
  }

  Future<void> addPendingItem(String imagePath) async {
    await enqueue(imagePath);
  }

  void setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void setPendingItems(List<Map<String, dynamic>> items) {
    _pendingItems = List.from(items);
    notifyListeners();
  }

  void setReadyItems(List<Map<String, dynamic>> items) {
    _readyItems = List.from(items);
    notifyListeners();
  }

  bool _cancelRequested = false;

  Future<void> cancelProcessing() async {
    _cancelRequested = true;
    _lastError = null;
    await _dbHelper.clearPendingScanQueueItems();
    _pendingItems = [];
    _isProcessing = false;
    notifyListeners();
  }

  Future<void> processPendingItems() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _cancelRequested = false;
    _lastError = null;
    await loadPendingItems();
    notifyListeners();

    try {
      final pending = await _dbHelper.getPendingScanQueueItems();
      _pendingItems = List.from(pending);
      notifyListeners();

      for (final item in pending) {
        if (_cancelRequested) break;

        final int id = item['id'];
        final String imagePath = item['image_path'];
        String? ocrText = item['ocr_text'] as String?;
        final int currentAttempts = (item['attempt_count'] as num?)?.toInt() ?? 0;
        final File file = File(imagePath);

        if (await file.exists()) {
          try {
            await _dbHelper.updateScanQueueItem(
              id,
              'processing',
              attemptCount: currentAttempts + 1,
            );

            // 1. Asegurar extracción OCR si aún no estaba presente
            if (ocrText == null || ocrText.trim().isEmpty) {
              final ocrResult = await _localOcrService.processImage(file);
              ocrText = ocrResult.structuredText;
              await _dbHelper.updateScanQueueItem(id, 'processing', ocrText: ocrText);
            }

            if (_cancelRequested) break;

            final compressedBytes = await ImageService.compressImage(file);
            if (_cancelRequested) break;

            final pendingShopping = await _dbHelper.getPendingShoppingItems();

            List<GeminiExtractionResult> extractedList = [];
            bool processedByText = false;

            // 2. Evaluar evidencia para intentar Gemini Texto
            if (ocrText != null && ocrText.trim().isNotEmpty) {
              // Heurística rápida sobre el texto estructurado
              final upper = ocrText.toUpperCase();
              final hasAmounts = RegExp(r'\b\d+[\.,]\d{2}\b').hasMatch(upper);
              final hasTotal = upper.contains('TOTAL') || upper.contains('SUBTOTAL') || upper.contains('MONTO');
              final lineCount = upper.split('\n').where((l) => l.trim().isNotEmpty).length;

              int score = 0;
              if (hasAmounts) score += 2;
              if (hasTotal) score += 2;
              if (lineCount >= 5) score += 2;
              if (upper.contains('BS') || upper.contains('VES') || upper.contains('REF') || upper.contains('\$')) score += 1;
              if (RegExp(r'\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b').hasMatch(upper)) score += 1;

              final shouldAttemptText = score >= 6;

              if (shouldAttemptText) {
                try {
                  extractedList = await _geminiService.analyzeReceiptText(
                    ocrText: ocrText,
                    pendingShoppingItems: pendingShopping,
                  );

                  // 3. Validación Semántica Multicriterio con tolerancia
                  final validation = _semanticValidator.validate(extractedList);
                  if (validation.isValid) {
                    processedByText = true;
                  } else {
                    debugPrint('Validación semántica falló: ${validation.reason}. Activando fallback a Visión.');
                    extractedList = []; // Dispara fallback a Visión
                  }
                } catch (textErr) {
                  debugPrint('Error en Gemini Texto: $textErr. Activando fallback a Visión.');
                  extractedList = [];
                }
              }
            }

            // 4. Fallback a Gemini Visión si el texto no fue suficiente o falló la validación
            if (!processedByText || extractedList.isEmpty) {
              if (_cancelRequested) break;
              extractedList = await _geminiService.analyzeReceiptImage(
                imageBytes: compressedBytes,
                apiKey: 'proxy',
                pendingShoppingItems: pendingShopping,
              );
            }

            if (_cancelRequested) break;

            if (extractedList.isNotEmpty) {
              final firstJson = jsonEncode(extractedList.first.toMap());
              await _dbHelper.updateScanQueueItem(
                id,
                'ready',
                extractedData: firstJson,
                ocrText: ocrText,
              );

              for (int i = 1; i < extractedList.length; i++) {
                final extraJson = jsonEncode(extractedList[i].toMap());
                await _dbHelper.insertReadyScanQueueItem(imagePath, extraJson, ocrText: ocrText);
              }
            } else {
              await _dbHelper.deleteScanQueueItem(id);
            }
          } catch (e) {
            final msg = e.toString().replaceFirst('Exception: ', '').trim();
            _lastError = msg.isNotEmpty ? msg : 'Error al procesar el comprobante.';
            debugPrint('Fallo al procesar item en cola offline: $e');
            await _dbHelper.updateScanQueueItem(
              id,
              'pending',
              lastError: _lastError,
            );
            break;
          }
        } else {
          try {
            await _dbHelper.deleteScanQueueItem(id);
          } catch (_) {}
        }
        await loadPendingItems();
        await loadReadyItems();
      }
      await loadReadyItems();
    } finally {
      _isProcessing = false;
      await loadPendingItems();
      notifyListeners();
    }
  }

  Future<void> removeItem(int id) async {
    await _dbHelper.deleteScanQueueItem(id);
    await loadReadyItems();
    await loadPendingItems();
  }
}
