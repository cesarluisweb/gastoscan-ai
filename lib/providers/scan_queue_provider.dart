import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/datasources/local/database_helper.dart';
import '../data/datasources/remote/gemini_service.dart';
import '../data/models/gemini_extraction_result.dart';
import '../services/image_service.dart';
import 'dart:io';

class ScanQueueProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper;
  final GeminiService _geminiService;
  final bool autoProcess;

  List<Map<String, dynamic>> _readyItems = [];
  List<Map<String, dynamic>> get readyItems => _readyItems;

  List<Map<String, dynamic>> _pendingItems = [];
  List<Map<String, dynamic>> get pendingItems => _pendingItems;
  int get pendingCount => _pendingItems.length;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  ScanQueueProvider({
    DatabaseHelper? dbHelper,
    GeminiService? geminiService,
    this.autoProcess = true,
  })  : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _geminiService = geminiService ?? GeminiService() {
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
  }

  Future<void> loadPendingItems() async {
    _pendingItems = await _dbHelper.getPendingScanQueueItems();
    notifyListeners();
  }

  Future<void> enqueue(String imagePath) async {
    await _dbHelper.insertScanQueueItem(imagePath);
    await loadPendingItems();
    processPendingItems();
  }

  Future<void> enqueueMultiple(List<String> imagePaths) async {
    for (final path in imagePaths) {
      await _dbHelper.insertScanQueueItem(path);
    }
    await loadPendingItems();
    processPendingItems();
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
    await _dbHelper.clearPendingScanQueueItems();
    _pendingItems = [];
    _isProcessing = false;
    notifyListeners();
  }

  Future<void> processPendingItems() async {
    if (_isProcessing) return;
    _isProcessing = true;
    _cancelRequested = false;
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
        final File file = File(imagePath);

        if (await file.exists()) {
          try {
            final compressedBytes = await ImageService.compressImage(file);
            if (_cancelRequested) break;

            final pendingShopping = await _dbHelper.getPendingShoppingItems();

            final extracted = await _geminiService.analyzeReceiptImage(
              imageBytes: compressedBytes,
              apiKey: 'proxy',
              pendingShoppingItems: pendingShopping,
            );
            
            if (_cancelRequested) break;

            final jsonStr = jsonEncode(extracted.toMap());
            await _dbHelper.updateScanQueueItem(id, 'ready', extractedData: jsonStr);
          } catch (e) {
            debugPrint('Fallo al procesar item en cola offline: $e');
            // Fallback para no perder la foto y no atascar la cola
            final fallback = GeminiExtractionResult(
              comercio: 'Error al extraer datos',
              fecha: DateTime.now().toIso8601String().substring(0, 10),
              moneda: 'USD',
              totalOriginal: 0.0,
              impuestoIva: 0.0,
              items: [],
            );
            final jsonStr = jsonEncode(fallback.toMap());
            await _dbHelper.updateScanQueueItem(id, 'ready', extractedData: jsonStr);
          }
        } else {
          await _dbHelper.deleteScanQueueItem(id);
        }
        await loadPendingItems();
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
