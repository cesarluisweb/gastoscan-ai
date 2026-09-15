import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/shopping_item_model.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';

class FakeDatabaseHelper extends DatabaseHelper {
  final List<Map<String, dynamic>> pendingDb = [];
  final List<Map<String, dynamic>> readyDb = [];
  int _nextId = 1;

  FakeDatabaseHelper() : super.test();

  @override
  Future<int> insertScanQueueItem(String imagePath) async {
    final id = _nextId++;
    pendingDb.add({
      'id': id,
      'image_path': imagePath,
      'status': 'pending',
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
  Future<int> updateScanQueueItem(int id, String status, {String? extractedData}) async {
    final index = pendingDb.indexWhere((it) => it['id'] == id);
    if (index != -1) {
      final item = Map<String, dynamic>.from(pendingDb.removeAt(index));
      item['status'] = status;
      if (extractedData != null) item['extracted_data'] = extractedData;
      if (status == 'ready') {
        readyDb.add(item);
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
  Future<List<ShoppingItemModel>> getPendingShoppingItems() async {
    return [];
  }
}

void main() {
  group('ScanQueueProvider Tests', () {
    late FakeDatabaseHelper fakeDb;
    late ScanQueueProvider provider;

    setUp(() {
      fakeDb = FakeDatabaseHelper();
      provider = ScanQueueProvider(dbHelper: fakeDb, autoProcess: false);
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
  });
}
