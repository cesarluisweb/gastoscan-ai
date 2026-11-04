import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/providers/scan_queue_provider.dart';
import 'package:gastoscan_ai/services/notification_service.dart';

class FakeDatabaseHelperForIntentTray extends DatabaseHelper {
  final List<Map<String, dynamic>> readyDb = [];
  final List<Map<String, dynamic>> pendingDb = [];
  Completer<void>? getReadyDelay;

  FakeDatabaseHelperForIntentTray() : super.test();

  @override
  Future<int> resetStaleProcessingScanQueueItems() async => 0;

  @override
  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async {
    if (getReadyDelay != null) {
      await getReadyDelay!.future;
    }
    return List.from(readyDb);
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async {
    return List.from(pendingDb);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NotificationService notificationService;
  late FakeDatabaseHelperForIntentTray fakeDb;

  setUp(() {
    notificationService = NotificationService.test();
    notificationService.clearPendingAction();
    fakeDb = FakeDatabaseHelperForIntentTray();
  });

  tearDown(() {
    notificationService.clearPendingAction();
  });

  group('Intent Tray (Bandeja de Intenciones) Tests', () {
    test('1. enqueueAction registra PendingLaunchAction y notifica a los escuchas', () {
      expect(notificationService.pendingAction, isNull);

      notificationService.enqueueAction('pending_reviews', 'local_launch');

      expect(notificationService.pendingAction, isNotNull);
      expect(notificationService.pendingAction!.payload, equals('pending_reviews'));
      expect(notificationService.pendingAction!.origin, equals('local_launch'));
      expect(notificationService.pendingAction!.isHandled, isFalse);
      expect(notificationService.pendingActionNotifier.value, isNotNull);
      expect(notificationService.selectedPayloadNotifier.value, equals('pending_reviews'));
    });

    test('2. markActionHandled consume la intención solo cuando coincide el id', () {
      notificationService.enqueueAction('pending_reviews', 'local_tap');
      final actionId = notificationService.pendingAction!.id;

      // Intentar marcar con ID erróneo no debe limpiar la bandeja
      notificationService.markActionHandled('wrong-id');
      expect(notificationService.pendingAction, isNotNull);
      expect(notificationService.pendingActionNotifier.value, isNotNull);

      // Marcar con el ID correcto
      notificationService.markActionHandled(actionId);
      expect(notificationService.pendingAction, isNull);
      expect(notificationService.pendingActionNotifier.value, isNull);
      expect(notificationService.selectedPayloadNotifier.value, isNull);
    });
  });

  group('ScanQueueProvider.ready Tests', () {
    test('3. ready se completa automáticamente tras cargar ítems de SQLite', () async {
      fakeDb.readyDb.add({
        'id': 1,
        'image_path': '/path/to/img.jpg',
        'extracted_data': '{"comercio": "Farmatodo"}',
        'status': 'ready',
      });

      final provider = ScanQueueProvider(
        dbHelper: fakeDb,
        autoProcess: true,
      );

      // El getter ready debe ser un Future completable
      await expectLater(provider.ready, completes);
      expect(provider.readyItems.length, equals(1));
    });

    test('4. ready se completa de inmediato si autoProcess es false', () async {
      final provider = ScanQueueProvider(
        dbHelper: fakeDb,
        autoProcess: false,
      );

      await expectLater(provider.ready, completes);
    });

    test('5. Retención en bandeja: intención capturada antes de que SQLite responda se conserva intacta', () async {
      fakeDb.getReadyDelay = Completer<void>();
      fakeDb.readyDb.add({
        'id': 10,
        'image_path': '/path/to/receipt.jpg',
        'extracted_data': '{"comercio": "Plazas"}',
        'status': 'ready',
      });

      notificationService.enqueueAction('pending_reviews', 'local_launch');

      final provider = ScanQueueProvider(
        dbHelper: fakeDb,
        autoProcess: true,
      );

      // En este instante, SQLite aún no ha respondido. La cola de ítems listos está vacía
      expect(provider.readyItems.isEmpty, isTrue);

      // La intención en la bandeja permanece intacta (no se descarta prematuramente)
      expect(notificationService.pendingAction, isNotNull);
      expect(notificationService.pendingAction!.payload, equals('pending_reviews'));

      // Ahora SQLite responde y se completa el getter ready
      fakeDb.getReadyDelay!.complete();
      await provider.ready;

      // Ahora los readyItems ya están disponibles
      expect(provider.readyItems.length, equals(1));
      expect(provider.readyItems.first['id'], equals(10));

      // El consumidor atiende la intención y la marca como procesada
      notificationService.markActionHandled(notificationService.pendingAction!.id);
      expect(notificationService.pendingAction, isNull);
    });
  });
}
