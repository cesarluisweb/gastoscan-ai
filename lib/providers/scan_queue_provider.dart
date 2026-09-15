import 'dart:convert';
import 'package:flutter/material.dart';
import '../data/datasources/local/database_helper.dart';
import '../data/datasources/remote/gemini_service.dart';
import '../data/models/gemini_extraction_result.dart';
import '../services/image_service.dart';
import 'dart:io';

class ScanQueueProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final GeminiService _geminiService = GeminiService();

  List<Map<String, dynamic>> _readyItems = [];
  List<Map<String, dynamic>> get readyItems => _readyItems;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  ScanQueueProvider() {
    loadReadyItems();
    processPendingItems(); // Intenta procesar al iniciar
  }

  Future<void> loadReadyItems() async {
    _readyItems = await _dbHelper.getReadyScanQueueItems();
    notifyListeners();
  }

  Future<void> addPendingItem(String imagePath) async {
    await _dbHelper.insertScanQueueItem(imagePath);
    // Intentar procesar enseguida si hay internet
    processPendingItems();
  }

  Future<void> processPendingItems() async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    try {
      final pending = await _dbHelper.getPendingScanQueueItems();
      for (final item in pending) {
        final int id = item['id'];
        final String imagePath = item['image_path'];
        final File file = File(imagePath);

        if (await file.exists()) {
          try {
            final compressedBytes = await ImageService.compressImage(file);
            final pendingShopping = await DatabaseHelper.instance.getPendingShoppingItems();

            final extracted = await _geminiService.analyzeReceiptImage(
              imageBytes: compressedBytes,
              apiKey: 'proxy',
              pendingShoppingItems: pendingShopping,
            );
            
            final jsonStr = jsonEncode(extracted.toMap());
            await _dbHelper.updateScanQueueItem(id, 'ready', extractedData: jsonStr);
          } catch (e) {
            print('Fallo al procesar item en cola offline: $e');
          }
        } else {
          await _dbHelper.deleteScanQueueItem(id);
        }
      }
      await loadReadyItems();
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> removeItem(int id) async {
    await _dbHelper.deleteScanQueueItem(id);
    await loadReadyItems();
  }
}
