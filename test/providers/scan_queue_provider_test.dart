import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gemini_extraction_result.dart';
import 'package:gastoscan_ai/data/models/shopping_item_model.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> pendingDb = [];
  final List<Map<String, dynamic>> readyDb = [];
  int _nextId = 1;

  FakeDatabaseHelper() : super.test();

  @override
  Future<int> insertScanQueueItem(String imagePath, {String? ocrText}) async {
    final id = _nextId++;
    pendingDb.add({
      'id': id,
      'image_path': imagePath,
      'status': 'pending',
      'ocr_text': ocrText,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async {
    return List.from(pendingDb);
  }

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async {
    return List.from(readyDb);
  }

  @override
  Future<int> updateScanQueueItem(
    int id,
    String status, {
    String? extractedData,
    String? ocrText,
    int? attemptCount,
    String? lastError,
  }) async {
    final index = pendingDb.indexWhere((it) => it['id'] == id);
    if (index != -1) {
      final item = Map<String, dynamic>.from(pendingDb.removeAt(index));
      item['status'] = status;
      if (extractedData != null) item['extracted_data'] = extractedData;
      if (ocrText != null) item['ocr_text'] = ocrText;
      if (attemptCount != null) item['attempt_count'] = attemptCount;
      if (lastError != null) item['last_error'] = lastError;
      if (status == 'ready') {
        readyDb.add(item);
      } else {
        pendingDb.insert(index, item);
      }
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteScanQueueItem(int id) async {
    pendingDb.removeWhere((it) => it['id'] == id);
    readyDb.removeWhere((it) => it['id'] == id);
    return 1;
  }

  @override
  Future<int> insertReadyScanQueueItem(String imagePath, String extractedData, {String? ocrText}) async {
    final id = _nextId++;
    readyDb.add({
      'id': id,
      'image_path': imagePath,
      'status': 'ready',
      'extracted_data': extractedData,
      'ocr_text': ocrText,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id;
  }

  @override
  Future<bool> isImagePathUsedByOtherQueueItems(int currentId, String imagePath) async {
    final count = pendingDb.where((it) => it['image_path'] == imagePath && it['id'] != currentId).length +
        readyDb.where((it) => it['image_path'] == imagePath && it['id'] != currentId).length;
    return count > 0;
  }

  @override
  Future<int> resetStaleProcessingScanQueueItems() async {
    int updated = 0;
    for (final it in pendingDb) {
      if (it['status'] == 'processing') {
        it['status'] = 'pending';
        updated++;
      }
    }
    return updated;
  }

  @override
  Future<int> resetFailedScanQueueItems() async {
    int updated = 0;
    for (final it in pendingDb) {
      if (it['status'] == 'error') {
        it['status'] = 'pending';
        it['attempt_count'] = 0;
        updated++;
      }
    }
    return updated;
  }

  @override
  Future<int> clearPendingScanQueueItems() async {
    final count = pendingDb.length;
    pendingDb.clear();
    return count;
  }

  @override
  Future<List<ShoppingItemModel>> getPendingShoppingItems() async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ScanQueueProvider Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider provider;
    late Directory tempDir;

    setUp(() {
      fakeDb = FakeDatabaseHelper();
      provider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
      tempDir = Directory.systemTemp.createTempSync('scan_queue_test_');
    });

    tearDown(() {
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('initial state has empty pending and ready items', () {
      expect(provider.pendingItems, isEmpty);
      expect(provider.readyItems, isEmpty);
      expect(provider.pendingCount, equals(0));
      expect(provider.isProcessing, isFalse);
    });

    test('enqueue inserts single image and updates pendingCount', () async {
      int notifications = 0;
      provider.addListener(() {
        notifications++;
      });

      await provider.enqueue('/path/to/invoice1.jpg');

      expect(provider.pendingCount, equals(1));
      expect(provider.pendingItems.first['image_path'], equals('/path/to/invoice1.jpg'));
      expect(fakeDb.pendingDb.length, equals(1));
      expect(notifications, greaterThan(0));
    });

    test('enqueueMultiple enqueues all images and updates pendingItems', () async {
      int notifications = 0;
      provider.addListener(() {
        notifications++;
      });

      final testPaths = [
        '/path/to/invoice_a.jpg',
        '/path/to/invoice_b.jpg',
        '/path/to/invoice_c.jpg',
      ];

      await provider.enqueueMultiple(testPaths);

      expect(provider.pendingCount, equals(3));
      expect(provider.pendingItems.length, equals(3));
      expect(provider.pendingItems[0]['image_path'], equals('/path/to/invoice_a.jpg'));
      expect(provider.pendingItems[1]['image_path'], equals('/path/to/invoice_b.jpg'));
      expect(provider.pendingItems[2]['image_path'], equals('/path/to/invoice_c.jpg'));
      expect(fakeDb.pendingDb.length, equals(3));
      expect(notifications, greaterThan(0));
    });

    test('addPendingItem delegates to enqueue and preserves backwards compatibility', () async {
      await provider.addPendingItem('/legacy/path.jpg');

      expect(provider.pendingCount, equals(1));
      expect(provider.pendingItems.first['image_path'], equals('/legacy/path.jpg'));
    });

    test('removeItem removes item from database and refreshes queue', () async {
      await provider.enqueue('/path/to/remove.jpg');
      expect(provider.pendingCount, equals(1));
      final itemId = provider.pendingItems.first['id'] as int;

      await provider.removeItem(itemId);

      expect(provider.pendingCount, equals(0));
      expect(fakeDb.pendingDb, isEmpty);
    });

    test('manual state mutation helpers update state and notify listeners', () {
      int notifications = 0;
      provider.addListener(() {
        notifications++;
      });

      provider.setProcessing(true);
      expect(provider.isProcessing, isTrue);
      expect(notifications, equals(1));

      provider.setPendingItems([
        {'id': 10, 'image_path': 'test1.jpg'},
        {'id': 11, 'image_path': 'test2.jpg'},
      ]);
      expect(provider.pendingCount, equals(2));
      expect(notifications, equals(2));

      provider.setReadyItems([
        {'id': 20, 'image_path': 'ready1.jpg', 'extracted_data': '{}'},
      ]);
      expect(provider.readyItems.length, equals(1));
      expect(notifications, equals(3));
    });

    test('offline enqueue marks queue as waiting for connection without crashing', () async {
      final offlineConn = ConnectivityService(testConnected: false);
      final offlineProvider = ScanQueueProvider(
        dbHelper: fakeDb,
        autoProcess: true,
        connectivityService: offlineConn,
      );

      await offlineProvider.enqueue('/path/to/offline_receipt.jpg');

      expect(offlineProvider.pendingCount, equals(1));
      expect(offlineProvider.isWaitingForConnection, isTrue);
      expect(offlineProvider.lastError, contains('Guardada sin conexión'));
      expect(offlineProvider.isProcessing, isFalse);
    });

    test('reconnection stream triggers processing of pending offline items', () async {
      final streamController = StreamController<bool>.broadcast();
      final dynamicConn = ConnectivityService(
        testConnected: false,
        testController: streamController,
      );
      final dynamicProvider = ScanQueueProvider(
        dbHelper: fakeDb,
        autoProcess: true,
        connectivityService: dynamicConn,
      );

      await dynamicProvider.enqueue('/path/to/offline_receipt2.jpg');
      expect(dynamicProvider.isWaitingForConnection, isTrue);

      // Simular reconexión de red
      streamController.add(true);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(dynamicProvider.isWaitingForConnection, isFalse);
      await streamController.close();
    });

    test('removeItem preserves physical file on disk when path is shared with other queue item', () async {
      final realFile = File('${tempDir.path}/shared_batch.jpg')..writeAsStringSync('dummy image data');
      expect(realFile.existsSync(), isTrue);

      await provider.enqueue(realFile.path);
      await provider.enqueue(realFile.path);
      expect(provider.pendingCount, equals(2));

      final firstId = provider.pendingItems.first['id'] as int;
      final secondId = provider.pendingItems.last['id'] as int;

      await provider.removeItem(firstId);

      // Fila borrada de la cola, pero archivo fisico en disco conservado por fila hermana
      expect(provider.pendingCount, equals(1));
      expect(provider.pendingItems.first['id'], equals(secondId));
      expect(realFile.existsSync(), isTrue);

      // Al remover la ultima referencia, el archivo fisico se elimina
      await provider.removeItem(secondId);
      expect(provider.pendingCount, equals(0));
      expect(realFile.existsSync(), isFalse);
    });

    test('removeItem deletes physical file on disk when it is the only reference in queue', () async {
      final realFile = File('${tempDir.path}/sole_receipt.jpg')..writeAsStringSync('dummy image data');
      expect(realFile.existsSync(), isTrue);

      await provider.enqueue(realFile.path);
      expect(provider.pendingCount, equals(1));
      final itemId = provider.pendingItems.first['id'] as int;

      await provider.removeItem(itemId);

      // Fila borrada de la cola y archivo fisico eliminado de disco
      expect(provider.pendingCount, equals(0));
      expect(realFile.existsSync(), isFalse);
    });

    test('cancelProcessing preserves physical file shared with ready item and cleans up unshared', () async {
      final sharedFile = File('${tempDir.path}/ready_shared.jpg')..writeAsStringSync('shared image data');
      final unsharedFile = File('${tempDir.path}/pending_only.jpg')..writeAsStringSync('unshared image data');

      fakeDb.readyDb.add({
        'id': 99,
        'image_path': sharedFile.path,
        'status': 'ready',
        'extracted_data': '{}',
      });

      await provider.enqueue(sharedFile.path);
      await provider.enqueue(unsharedFile.path);
      await provider.loadQueue();

      expect(provider.readyItems.length, equals(1));
      expect(provider.pendingCount, equals(2));

      await provider.cancelProcessing();

      expect(provider.pendingCount, equals(0));
      expect(fakeDb.pendingDb, isEmpty);
      expect(provider.readyItems.length, equals(1));

      // El archivo compartido con ready debe seguir existiendo en disco
      expect(sharedFile.existsSync(), isTrue);
      // El archivo que solo pertenecia a pending debe ser eliminado
      expect(unsharedFile.existsSync(), isFalse);
    });

    test('loadQueue recovers stale processing items back to pending', () async {
      fakeDb.pendingDb.add({
        'id': 42,
        'image_path': '${tempDir.path}/stale.jpg',
        'status': 'processing',
      });

      await provider.loadQueue();

      expect(fakeDb.pendingDb.first['status'], equals('pending'));
      expect(provider.pendingItems.first['status'], equals('pending'));
    });

    test('processPendingItems skips items already in error status without extra DB updates', () async {
      fakeDb.pendingDb.add({
        'id': 55,
        'image_path': '${tempDir.path}/error_item.jpg',
        'status': 'error',
        'attempt_count': 3,
        'last_error': 'Error previo',
      });

      await provider.loadPendingItems();
      expect(provider.pendingItems.length, equals(1));

      await provider.processPendingItems();

      expect(fakeDb.pendingDb.first['status'], equals('error'));
      expect(fakeDb.pendingDb.first['attempt_count'], equals(3));
    });
  });

  group('GeminiExtractionResult.listFromJson Tests', () {
    test('parses single legacy JSON correctly', () {
      final json = {
        'comercio': 'Supermercado Central',
        'fecha': '2026-09-24',
        'moneda': 'USD',
        'total_original': 15.50,
        'items': [
          {'descripcion': 'Leche', 'cantidad': 2, 'precio_unitario': 2.50, 'total': 5.00}
        ]
      };

      final results = GeminiExtractionResult.listFromJson(json);
      expect(results.length, equals(1));
      expect(results.first.comercio, equals('Supermercado Central'));
      expect(results.first.totalOriginal, equals(15.50));
    });

    test('parses multiple facturas JSON array correctly', () {
      final json = {
        'facturas': [
          {
            'comercio': 'Farmacia',
            'fecha': '2026-09-24',
            'moneda': 'USD',
            'total_original': 10.00,
            'items': []
          },
          {
            'comercio': 'Panadería',
            'fecha': '2026-09-24',
            'moneda': 'VES',
            'total_original': 120.00,
            'items': []
          }
        ]
      };

      final results = GeminiExtractionResult.listFromJson(json);
      expect(results.length, equals(2));
      expect(results[0].comercio, equals('Farmacia'));
      expect(results[1].comercio, equals('Panadería'));
      expect(results[1].moneda, equals('VES'));
    });

    test('parses fiscal markers (E) and (G) into item descriptions', () {
      final json = {
        'comercio': 'Automercado Plaza',
        'fecha': '2026-09-25',
        'moneda': 'VES',
        'total_original': 250.00,
        'impuesto_iva': 32.00,
        'items': [
          {
            'descripcion': 'Harina de Maiz',
            'cantidad': 2,
            'precio_unitario': 50.00,
            'total': 100.00,
            'alicuota_fiscal': 'E'
          },
          {
            'descripcion': 'Detergente Liquido',
            'cantidad': 1,
            'precio_unitario': 100.00,
            'total': 100.00,
            'alicuota_fiscal': 'G'
          }
        ]
      };

      final results = GeminiExtractionResult.listFromJson(json);
      expect(results.length, equals(1));
      final items = results.first.items;
      expect(items.any((it) => it.descripcion.contains('Harina de Maiz (E)')), isTrue);
      expect(items.any((it) => it.descripcion.contains('Detergente Liquido (G)')), isTrue);
    });
  });
}
