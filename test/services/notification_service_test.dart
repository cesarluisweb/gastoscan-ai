import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
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
  int cancelWeekendCount = 0;
  int scheduleWeekendCount = 0;
  int recordActivityCount = 0;
  Duration? lastDurationPassed;

  MockNotificationService() : super.test();

  bool _scheduled = false;
  DateTime? _time;

  bool _weekendScheduled = false;
  DateTime? _weekendTime;

  @override
  Future<void> cancelInactivityReminder() async {
    cancelCount++;
    _scheduled = false;
  }

  @override
  Future<void> scheduleInactivityReminder({
    Duration duration = const Duration(days: 30),
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
  Future<void> cancelBiweeklyWeekendReminder() async {
    cancelWeekendCount++;
    _weekendScheduled = false;
  }

  @override
  Future<void> scheduleBiweeklyWeekendReminder({
    DateTime? targetDate,
    String? customTitle,
    String? customBody,
  }) async {
    await cancelBiweeklyWeekendReminder();
    scheduleWeekendCount++;
    _weekendScheduled = true;
    _weekendTime = targetDate ?? DateTime.now().add(const Duration(days: 14));
  }

  @override
  Future<void> recordActivityAndReschedule() async {
    recordActivityCount++;
  }

  @override
  DateTime? get lastScheduledTime => _time;

  @override
  bool get isReminderScheduled => _scheduled;

  @override
  bool get isWeekendReminderScheduled => _weekendScheduled;

  @override
  DateTime? get lastWeekendScheduledTime => _weekendTime;
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
  Future<Map<String, double>> getCategoryTotals(int year, int month, {String moneda = 'USD'}) async {
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

  group('NotificationService — R4 Inactivity Reminders Tests (30 Días)', () {
    late NotificationService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = NotificationService.test();
      NotificationService.instance = service;
    });

    test('Default singleton instance is available and accessible', () {
      expect(NotificationService.instance, isNotNull);
      expect(NotificationService(), isNotNull);
    });

    test('Scheduling function defaults to Duration(days: 30)', () async {
      final before = DateTime.now();
      await service.scheduleInactivityReminder();
      final after = DateTime.now();

      expect(service.isReminderScheduled, isTrue);
      expect(service.lastScheduledDuration, equals(const Duration(days: 30)));
      expect(service.lastScheduledTime, isNotNull);

      // El tiempo programado debe estar a 30 días a partir de ahora (+/- unos milisegundos de margen)
      final expectedMin = before.add(const Duration(days: 30));
      final expectedMax = after.add(const Duration(days: 30));

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
      await service.scheduleInactivityReminder(duration: const Duration(days: 30));
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
      await mock.scheduleInactivityReminder(duration: const Duration(days: 30));
      expect(mock.scheduleCount, equals(1));
      expect(mock.cancelCount, equals(1));
      final firstScheduledTime = mock.lastScheduledTime;

      // Simular paso de tiempo y reprogramación
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await mock.scheduleInactivityReminder(duration: const Duration(days: 30));

      expect(mock.scheduleCount, equals(2));
      expect(mock.cancelCount, equals(2));
      expect(mock.isReminderScheduled, isTrue);
      expect(mock.lastScheduledTime!.isAfter(firstScheduledTime!), isTrue);
    });

    test('recordActivityAndReschedule updates activity time and reschedules for 30 days', () async {
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
      expect(service.lastScheduledDuration, equals(const Duration(days: 30)));
    });

    test('Channel configuration and constants are correctly defined for Inactivity', () {
      expect(NotificationService.inactivityNotificationId, equals(1001));
      expect(NotificationService.inactivityChannelId, equals('inactivity_reminders'));
      expect(NotificationService.inactivityChannelName, equals('Recordatorios de Inactividad'));
      expect(
        NotificationService.inactivityChannelDesc,
        equals(AppConstants.channelInactivityDesc),
      );
      expect(
        NotificationService.defaultNotificationTitle,
        equals(AppConstants.defaultInactivityTitle),
      );
      expect(
        NotificationService.defaultNotificationBody,
        equals(AppConstants.defaultInactivityBody),
      );
    });
  });

  group('NotificationService — Biweekly Weekend Reminders Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });
    test('Channel constants are correctly defined for Weekend Reminders', () {
      expect(NotificationService.weekendNotificationId, equals(1003));
      expect(NotificationService.weekendChannelId, equals('weekend_reminders'));
      expect(NotificationService.weekendChannelName, equals('Recordatorios de Compras'));
      expect(NotificationService.weekendChannelDesc, equals(AppConstants.channelWeekendDesc));
    });

    test('calcularProximaFechaQuincenal returns next Saturday at 18:30 from weekday', () {
      // 2026-10-28 es miércoles (Wednesday)
      final wednesday = DateTime(2026, 10, 28, 10, 0);
      final nextSat = NotificationService.calcularProximaFechaQuincenal(wednesday);

      expect(nextSat.weekday, equals(DateTime.saturday));
      expect(nextSat.hour, equals(18));
      expect(nextSat.minute, equals(30));
      expect(nextSat.year, equals(2026));
      expect(nextSat.month, equals(10));
      expect(nextSat.day, equals(31)); // Miércoles 28 + 3 = Sábado 31
    });

    test('calcularProximaFechaQuincenal on Saturday after 18:30 advances 7 days', () {
      // Sábado 31 de octubre a las 19:00 (ya pasó la hora límite)
      final saturdayNight = DateTime(2026, 10, 31, 19, 0);
      final nextSat = NotificationService.calcularProximaFechaQuincenal(saturdayNight);

      expect(nextSat.weekday, equals(DateTime.saturday));
      expect(nextSat.day, equals(7)); // Siguiente sábado (7 de noviembre)
      expect(nextSat.month, equals(11));
      expect(nextSat.hour, equals(18));
      expect(nextSat.minute, equals(30));
    });

    test('calcularProximaFechaQuincenal enforces 14-day cadence if recently scheduled', () {
      final now = DateTime(2026, 10, 28, 10, 0);
      // Simular que el sábado 31 de octubre ya fue programado
      final ultimoProgramado = DateTime(2026, 10, 31, 18, 30);
      final nextSat = NotificationService.calcularProximaFechaQuincenal(now, ultimoProgramado: ultimoProgramado);

      // Debe programar para el siguiente sábado quincenal (7 de noviembre)
      expect(nextSat.weekday, equals(DateTime.saturday));
      expect(nextSat.day, equals(7));
      expect(nextSat.month, equals(11));
    });

    test('Assistant default messages pool has 4 distinct options', () {
      expect(AppConstants.defaultMensajesAsistenteQuincenal.length, equals(4));
      for (final msg in AppConstants.defaultMensajesAsistenteQuincenal) {
        expect(msg['titulo'], isNotEmpty);
        expect(msg['cuerpo'], isNotEmpty);
      }
    });
  });

  group('NotificationService — Broadcast Announcements Tests', () {
    test('Channel constants are correctly defined for Broadcast', () {
      expect(NotificationService.broadcastNotificationId, equals(1004));
      expect(NotificationService.broadcastChannelId, equals('broadcast_announcements'));
      expect(NotificationService.broadcastChannelName, equals('Avisos y Novedades'));
      expect(AppConstants.fcmTopicGeneral, equals('anuncios_generales'));
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
        categoria: 'Alimentación',
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

    test('clearPayload resets initialPayload and selectedPayloadNotifier', () {
      final realService = NotificationService.test();
      realService.selectedPayloadNotifier.value = 'test_payload';
      expect(realService.selectedPayloadNotifier.value, equals('test_payload'));

      realService.clearPayload();
      expect(realService.initialPayload, isNull);
      expect(realService.selectedPayloadNotifier.value, isNull);
    });
  });

  group('NotificationService — AndroidManifest Permissions & Configuration Verification', () {
    test('android/app/src/main/AndroidManifest.xml contains all required permissions and receivers', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue, reason: 'AndroidManifest.xml must exist');

      final content = manifestFile.readAsStringSync();

      // Verificar los permisos requeridos
      expect(content.contains('android.permission.POST_NOTIFICATIONS'), isTrue,
          reason: 'Must declare POST_NOTIFICATIONS permission');
      expect(content.contains('android.permission.RECEIVE_BOOT_COMPLETED'), isTrue,
          reason: 'Must declare RECEIVE_BOOT_COMPLETED permission');
      expect(content.contains('android.permission.VIBRATE'), isTrue,
          reason: 'Must declare VIBRATE permission');
      // Asegurar que permisos de alarma exacta restringidos por Google Play no estan presentes
      expect(content.contains('android.permission.USE_EXACT_ALARM'), isFalse,
          reason: 'Must NOT declare USE_EXACT_ALARM permission for Google Play compliance');

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

    test('pubspec.yaml declares flutter_local_notifications, timezone and firebase_messaging', () {
      final pubspecFile = File('pubspec.yaml');
      expect(pubspecFile.existsSync(), isTrue);

      final content = pubspecFile.readAsStringSync();
      expect(content.contains('flutter_local_notifications:'), isTrue);
      expect(content.contains('timezone:'), isTrue);
      expect(content.contains('firebase_messaging:'), isTrue);
    });
  });
}
