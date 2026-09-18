import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/services/notification_service.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';

/// Implementación simulada de NotificationService para registrar llamadas durante tests.
class MockNotificationService extends NotificationService {
  int cancelCount = 0;
  int scheduleCount = 0;
  int recordActivityCount = 0;
  Duration? lastDurationPassed;

  MockNotificationService() : super.test();

  bool _scheduled = false;
  DateTime? _time;

  @override
  Future<void> cancelInactivityReminder() async {
    cancelCount++;
    _scheduled = false;
  }

  @override
  Future<void> scheduleInactivityReminder({
    Duration duration = const Duration(days: 3),
    String title = NotificationService.defaultNotificationTitle,
    String body = NotificationService.defaultNotificationBody,
  }) async {
    await cancelInactivityReminder();
    lastDurationPassed = duration;
    scheduleCount++;
    _scheduled = true;
    _time = DateTime.now().add(duration);
  }

  @override
  Future<void> recordActivityAndReschedule() async {
    recordActivityCount++;
  }
  
  @override
  DateTime? get lastScheduledTime => _time;
  
  @override
  bool get isReminderScheduled => _scheduled;
}

/// Fake DatabaseHelper para probar GastoProvider sin SQLite real
class FakeDatabaseHelperForNotifications extends DatabaseHelper {
  final List<GastoModel> gastos = [];
  final List<ItemGastoModel> items = [];
  int _nextId = 1;

  FakeDatabaseHelperForNotifications() : super.test();

  @override
  Future<int> insertGasto(GastoModel gasto, List<ItemGastoModel> itemsList) async {
    final id = _nextId++;
    gastos.add(gasto.copyWith(id: id));
    items.addAll(itemsList);
    return id;
  }

  @override
  Future<void> updateGasto(GastoModel gasto, List<ItemGastoModel> itemsList) async {
    final idx = gastos.indexWhere((g) => g.id == gasto.id);
    if (idx != -1) {
      gastos[idx] = gasto;
    }
  }

  @override
  Future<List<GastoModel>> getGastosByMonth(int year, int month) async {
    return List.from(gastos);
  }

  @override
  Future<Map<String, double>> getMonthlyTotals(int year, int month) async {
    return {'USD': 0.0, 'VES': 0.0};
  }

  @override
  Future<Map<String, double>> getCategoryTotals(int year, int month) async {
    return {};
  }

  @override
  Future<Map<String, double>> getAllPresupuestosCategorias() async {
    return {};
  }

  @override
  Future<List<GastoModel>> getUnsyncedGastos() async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationService — R4 Inactivity Reminders Tests', () {
    late NotificationService service;

    setUp(() {
      service = NotificationService.test();
      NotificationService.instance = service;
    });

    test('Default singleton instance is available and accessible', () {
      expect(NotificationService.instance, isNotNull);
      expect(NotificationService(), isNotNull);
    });

    test('3-day scheduling function defaults to Duration(days: 3)', () async {
      final before = DateTime.now();
      await service.scheduleInactivityReminder();
      final after = DateTime.now();

      expect(service.isReminderScheduled, isTrue);
      expect(service.lastScheduledDuration, equals(const Duration(days: 3)));
      expect(service.lastScheduledTime, isNotNull);

      // El tiempo programado debe estar a 3 días a partir de ahora (+/- unos milisegundos de margen)
      final expectedMin = before.add(const Duration(days: 3));
      final expectedMax = after.add(const Duration(days: 3));

      expect(
        service.lastScheduledTime!.isAfter(expectedMin.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        service.lastScheduledTime!.isBefore(expectedMax.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('Custom duration is respected when specified', () async {
      const customDuration = Duration(hours: 12);
      await service.scheduleInactivityReminder(duration: customDuration);

      expect(service.isReminderScheduled, isTrue);
      expect(service.lastScheduledDuration, equals(customDuration));
    });

    test('cancelInactivityReminder cancels and clears scheduled state', () async {
      await service.scheduleInactivityReminder(duration: const Duration(days: 3));
      expect(service.isReminderScheduled, isTrue);
      expect(service.lastScheduledTime, isNotNull);

      await service.cancelInactivityReminder();
      expect(service.isReminderScheduled, isFalse);
      expect(service.lastScheduledTime, isNull);
      expect(service.lastScheduledDuration, isNull);
    });

    test('Rescheduling logic cancels previous notification and schedules new one', () async {
      final mock = MockNotificationService();
      NotificationService.instance = mock;

      // Primera programación
      await mock.scheduleInactivityReminder(duration: const Duration(days: 3));
      expect(mock.scheduleCount, equals(1));
      expect(mock.cancelCount, equals(1)); // cancelInactivityReminder se llama dentro de scheduleInactivityReminder
      final firstScheduledTime = mock.lastScheduledTime;

      // Simular paso de tiempo y reprogramación
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await mock.scheduleInactivityReminder(duration: const Duration(days: 3));

      expect(mock.scheduleCount, equals(2));
      expect(mock.cancelCount, equals(2));
      expect(mock.isReminderScheduled, isTrue);
      expect(mock.lastScheduledTime!.isAfter(firstScheduledTime!), isTrue);
    });

    test('recordActivityAndReschedule updates activity time and reschedules for 3 days', () async {
      final before = DateTime.now();
      await service.recordActivityAndReschedule();
      final after = DateTime.now();

      expect(service.lastActivityTime, isNotNull);
      expect(
        service.lastActivityTime!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        service.lastActivityTime!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );

      expect(service.isReminderScheduled, isTrue);
      expect(service.lastScheduledDuration, equals(const Duration(days: 3)));
    });

    test('Channel configuration and constants are correctly defined', () {
      expect(NotificationService.inactivityNotificationId, equals(1001));
      expect(NotificationService.inactivityChannelId, equals('inactivity_reminders'));
      expect(NotificationService.inactivityChannelName, equals('Recordatorios de Inactividad'));
      expect(
        NotificationService.inactivityChannelDesc,
        equals('Notificaciones automáticas si no registras gastos en 3 días'),
      );
      expect(
        NotificationService.defaultNotificationTitle,
        equals('¡Te extrañamos en Rinde Más!'),
      );
      expect(
        NotificationService.defaultNotificationBody,
        equals('Han pasado 3 días desde tu último registro. ¡No olvides registrar tus facturas!'),
      );
    });
  });

  group('NotificationService — Integration with GastoProvider', () {
    late MockNotificationService mockNotifications;
    late FakeDatabaseHelperForNotifications fakeDb;
    late GastoRepository repository;
    late GastoProvider gastoProvider;

    setUp(() {
      mockNotifications = MockNotificationService();
      NotificationService.instance = mockNotifications;

      fakeDb = FakeDatabaseHelperForNotifications();
      repository = GastoRepository(dbHelper: fakeDb);
      gastoProvider = GastoProvider(repository: repository, autoLoad: false);
    });

    test('agregarGasto triggers recordActivityAndReschedule on NotificationService', () async {
      expect(mockNotifications.recordActivityCount, equals(0));

      final dummyGasto = GastoModel(
        uuid: 'test-uuid-1',
        comercio: 'Supermercado Central',
        totalUsd: 2550,
        totalOriginal: 2550,
        moneda: 'USD',
        categoria: 'Comida',
        fecha: '2026-09-15',
        tasaCambio: 36.5,
        creadoEn: DateTime.now().toIso8601String(),
      );

      final dummyItems = [
        ItemGastoModel(
          descripcion: 'Harina PAN',
          cantidad: 2,
          precioUnitario: 150,
          total: 300,
        ),
      ];

      final success = await gastoProvider.agregarGasto(dummyGasto, dummyItems);

      expect(success, isTrue);
      expect(mockNotifications.recordActivityCount, equals(1));
    });

    test('actualizarGasto triggers recordActivityAndReschedule on NotificationService', () async {
      expect(mockNotifications.recordActivityCount, equals(0));

      final dummyGasto = GastoModel(
        id: 1,
        uuid: 'test-uuid-2',
        comercio: 'Farmacia',
        totalUsd: 1000,
        totalOriginal: 1000,
        moneda: 'USD',
        categoria: 'Salud',
        fecha: '2026-09-15',
        tasaCambio: 36.5,
        creadoEn: DateTime.now().toIso8601String(),
      );

      final success = await gastoProvider.actualizarGasto(dummyGasto, []);

      expect(success, isTrue);
      expect(mockNotifications.recordActivityCount, equals(1));
    });
  });

  group('NotificationService — AndroidManifest Permissions & Configuration Verification', () {
    test('android/app/src/main/AndroidManifest.xml contains all required permissions and receivers', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();

      // Verificar los 5 permisos requeridos
      expect(content.contains('android.permission.POST_NOTIFICATIONS'), isTrue,
          reason: 'Must declare POST_NOTIFICATIONS permission');
      expect(content.contains('android.permission.RECEIVE_BOOT_COMPLETED'), isTrue,
          reason: 'Must declare RECEIVE_BOOT_COMPLETED permission');
      expect(content.contains('android.permission.SCHEDULE_EXACT_ALARM'), isTrue,
          reason: 'Must declare SCHEDULE_EXACT_ALARM permission');
      expect(content.contains('android.permission.USE_EXACT_ALARM'), isTrue,
          reason: 'Must declare USE_EXACT_ALARM permission');
      expect(content.contains('android.permission.VIBRATE'), isTrue,
          reason: 'Must declare VIBRATE permission');

      // Verificar los receptores de flutter_local_notifications
      expect(
        content.contains('com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver'),
        isTrue,
        reason: 'Must declare ScheduledNotificationReceiver',
      );
      expect(
        content.contains('com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver'),
        isTrue,
        reason: 'Must declare ScheduledNotificationBootReceiver',
      );
      expect(content.contains('android.intent.action.BOOT_COMPLETED'), isTrue,
          reason: 'Must handle BOOT_COMPLETED intent action');
    });

    test('AndroidManifest.xml contains permissions and receivers', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'android/app/src/main/AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();

      expect(content.contains('android.permission.POST_NOTIFICATIONS'), isTrue);
      expect(content.contains('android.permission.RECEIVE_BOOT_COMPLETED'), isTrue);
      expect(content.contains('android.permission.SCHEDULE_EXACT_ALARM'), isTrue);
      expect(content.contains('android.permission.USE_EXACT_ALARM'), isTrue);
      expect(content.contains('android.permission.VIBRATE'), isTrue);
      expect(
        content.contains('com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver'),
        isTrue,
      );
      expect(
        content.contains('com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver'),
        isTrue,
      );
    });

    test('pubspec.yaml declares flutter_local_notifications and timezone', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final content = pubspecFile.readAsStringSync();
      expect(content.contains('flutter_local_notifications:'), isTrue);
      expect(content.contains('timezone:'), isTrue);
    });
  });
}
