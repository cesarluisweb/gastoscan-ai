import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/notification_service.dart';

class FakeSecureStorageForNotifications extends Fake implements FlutterSecureStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #read) {
      return Future<String?>.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

class MockNotificationServiceForSettings extends NotificationService {
  int cancelInactivityCount = 0;
  int scheduleInactivityCount = 0;
  int cancelWeekendCount = 0;
  int scheduleWeekendCount = 0;
  int subscribeCount = 0;
  int unsubscribeCount = 0;

  MockNotificationServiceForSettings() : super.test();

  @override
  Future<void> cancelInactivityReminder() async {
    cancelInactivityCount++;
  }

  @override
  Future<void> scheduleInactivityReminder({
    Duration duration = const Duration(days: 30),
    String title = NotificationService.defaultNotificationTitle,
    String body = NotificationService.defaultNotificationBody,
  }) async {
    scheduleInactivityCount++;
  }

  @override
  Future<void> cancelBiweeklyWeekendReminder() async {
    cancelWeekendCount++;
  }

  @override
  Future<void> scheduleBiweeklyWeekendReminder({
    DateTime? targetDate,
    String? customTitle,
    String? customBody,
  }) async {
    scheduleWeekendCount++;
  }

  @override
  Future<void> subscribeToBroadcastTopic() async {
    subscribeCount++;
  }

  @override
  Future<void> unsubscribeFromBroadcastTopic() async {
    unsubscribeCount++;
  }
}

class TestableSettingsProviderWithMockSync extends SettingsProvider {
  TestableSettingsProviderWithMockSync({super.secureStorage}) : super(autoLoad: false);

  @override
  Future<bool> actualizarTasaAutomatica({http.Client? client}) async => false;

  @override
  Future<void> sincronizarRecordatoriosRemotos({dynamic firestore}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider Notifications & Reminders Preferences Tests', () {
    late MockNotificationServiceForSettings mockNotifications;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockNotifications = MockNotificationServiceForSettings();
      NotificationService.instance = mockNotifications;
    });

    test('Default values for notification preferences are true and use defaults', () async {
      final provider = TestableSettingsProviderWithMockSync(
        secureStorage: FakeSecureStorageForNotifications(),
      );
      await provider.loadSettings();

      expect(provider.recordatoriosActivos, isTrue);
      expect(provider.recordatorioFinDeSemana, isTrue);
      expect(provider.anunciosActivos, isTrue);
      expect(provider.mensajesQuincenales.length, equals(4));
      expect(provider.tituloInactividad, equals(AppConstants.defaultInactivityTitle));
      expect(provider.cuerpoInactividad, equals(AppConstants.defaultInactivityBody));
    });

    test('setRecordatorioFinDeSemana persists and calls NotificationService', () async {
      final provider = TestableSettingsProviderWithMockSync(
        secureStorage: FakeSecureStorageForNotifications(),
      );
      await provider.loadSettings();

      // Desactivar
      await provider.setRecordatorioFinDeSemana(false);
      expect(provider.recordatorioFinDeSemana, isFalse);
      expect(mockNotifications.cancelWeekendCount, equals(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.prefRecordatorioFinDeSemana), isFalse);

      // Reactivar
      await provider.setRecordatorioFinDeSemana(true);
      expect(provider.recordatorioFinDeSemana, isTrue);
      expect(mockNotifications.scheduleWeekendCount, equals(1));
      expect(prefs.getBool(AppConstants.prefRecordatorioFinDeSemana), isTrue);
    });

    test('setAnunciosActivos persists and toggles topic subscription', () async {
      final provider = TestableSettingsProviderWithMockSync(
        secureStorage: FakeSecureStorageForNotifications(),
      );
      await provider.loadSettings();

      // Desactivar
      await provider.setAnunciosActivos(false);
      expect(provider.anunciosActivos, isFalse);
      expect(mockNotifications.unsubscribeCount, equals(1));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppConstants.prefAnunciosActivos), isFalse);

      // Reactivar
      await provider.setAnunciosActivos(true);
      expect(provider.anunciosActivos, isTrue);
      expect(mockNotifications.subscribeCount, equals(1));
      expect(prefs.getBool(AppConstants.prefAnunciosActivos), isTrue);
    });

    test('setRecordatoriosActivos persists and toggles inactivity schedule', () async {
      final provider = TestableSettingsProviderWithMockSync(
        secureStorage: FakeSecureStorageForNotifications(),
      );
      await provider.loadSettings();

      // Desactivar
      await provider.setRecordatoriosActivos(false);
      expect(provider.recordatoriosActivos, isFalse);
      expect(mockNotifications.cancelInactivityCount, equals(1));

      // Reactivar
      await provider.setRecordatoriosActivos(true);
      expect(provider.recordatoriosActivos, isTrue);
      expect(mockNotifications.scheduleInactivityCount, equals(1));
    });

    test('Cached custom messages in SharedPreferences are loaded on init', () async {
      final customList = [
        {
          'titulo': 'Mensaje Custom 1',
          'cuerpo': 'Cuerpo Custom 1',
        },
      ];
      SharedPreferences.setMockInitialValues({
        AppConstants.prefCachedMensajesQuincenalesJson: jsonEncode(customList),
      });

      final provider = TestableSettingsProviderWithMockSync(
        secureStorage: FakeSecureStorageForNotifications(),
      );
      await provider.loadSettings();

      expect(provider.mensajesQuincenales.length, equals(1));
      expect(provider.mensajesQuincenales[0]['titulo'], equals('Mensaje Custom 1'));
    });
  });
}
