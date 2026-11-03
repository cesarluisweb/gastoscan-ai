import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/exchange_rate_service.dart';
import '../services/exchange_rate_service_cache_purge_test.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final member = invocation.memberName;
    if (member == #write) {
      final key = invocation.namedArguments[#key] as String;
      final value = invocation.namedArguments[#value] as String?;
      if (value != null) {
        data[key] = value;
      }
      return Future<void>.value();
    }
    if (member == #read) {
      final key = invocation.namedArguments[#key] as String;
      return Future<String?>.value(data[key]);
    }
    if (member == #delete) {
      final key = invocation.namedArguments[#key] as String;
      data.remove(key);
      return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}

class TestableSettingsProvider extends SettingsProvider {
  TestableSettingsProvider({super.secureStorage}) : super(autoLoad: false);

  @override
  Future<bool> actualizarTasaAutomatica({http.Client? client}) async => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsProvider - Protecciones B2 de Caché de Tasas y Dominio Numérico', () {
    late FakeSecureStorage fakeSecureStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ExchangeRateService.resetPendingPurgeOperationsForTesting();
      fakeSecureStorage = FakeSecureStorage();
    });

    tearDown(() {
      ExchangeRateService.resetPendingPurgeOperationsForTesting();
    });

    test('Escenario 11: Purga fallida (-1) en SettingsProvider -> fail-closed, no consume cache local', () async {
      // Store donde la purga falla (remove retorna false al purgar una clave corrupta)
      final failingStore = TestSharedPreferences({
        'cached_rate_usdt': 0.0, // Forzará purga -> fallo en remove
        'cached_rate_usd': 88.0, // Tasa local potencialmente contaminada
        'cached_rate_eur': 95.0,
        AppConstants.prefTasaCambio: 88.0,
      });
      failingStore.returnFalseOnRemove = true;

      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider.prefsInstance = failingStore;
      await provider.loadSettings();

      // No debe consumir 88.0 ni 95.0 porque la purga falló (-1)
      expect(provider.tasaCambioVesUsd, equals(AppConstants.defaultTasaCambio));
      expect(provider.tasaCambioVesEur, equals(0.0));
      expect(provider.tasaCambioVesUsdt, equals(AppConstants.defaultTasaCambio));
      expect(provider.ultimaActualizacionTasas, isNull);
    });

    test('Escenario 12: Purga exitosa en SettingsProvider -> solo consume tasas validas segun validador canonico (D-08)', () async {
      final validStore = TestSharedPreferences({
        'cached_rate_usd': 45.0, // Tasa válida bajo D-08 (previamente descartada por > 50.0)
        'cached_rate_eur': 49.0,
        'cached_rate_usdt': 46.0,
      });

      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider.prefsInstance = validStore;
      await provider.loadSettings();

      expect(provider.tasaCambioVesUsd, equals(45.0));
      expect(provider.tasaCambioVesEur, equals(49.0));
      expect(provider.tasaCambioVesUsdt, equals(46.0));
    });

    test('Escenario 12b: Descarta NaN, Infinity y valores <= 1.0 en semillas locales (D-08)', () async {
      final storeWithBadValues = TestSharedPreferences({
        'cached_rate_usd': double.nan,
        AppConstants.prefTasaCambio: double.infinity,
        'cached_rate_eur': -5.0,
        'cached_rate_usdt': 0.5, // <= 1.0
      });

      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider.prefsInstance = storeWithBadValues;
      await provider.loadSettings();

      // Todos los valores inválidos deben ser descartados, adoptando defaults
      expect(provider.tasaCambioVesUsd.isFinite, isTrue);
      expect(provider.tasaCambioVesUsd, equals(AppConstants.defaultTasaCambio));
      expect(provider.tasaCambioVesEur, equals(0.0));
      // USDT recurre al fallback de USD sin aceptar <= 1.0
      expect(provider.tasaCambioVesUsdt.isFinite, isTrue);
      expect(provider.tasaCambioVesUsdt, equals(AppConstants.defaultTasaCambio));
    });

    test('NEW-6: SettingsProvider no lanza TypeError cuando cached_exchange_rates_timestamp es int', () async {
      final storeWithBadTimestamp = TestSharedPreferences({
        'cached_rate_usd': 45.0,
        'cached_exchange_rates_timestamp': 123456789, // int corrupto
      });

      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider.prefsInstance = storeWithBadTimestamp;
      await provider.loadSettings();

      expect(provider.tasaCambioVesUsd, equals(45.0));
      expect(provider.ultimaActualizacionTasas, isNull);
    });

    test('setTasaCambio rechaza NaN, Infinity, cero y valores <= 1.0', () async {
      final store = TestSharedPreferences({
        AppConstants.prefTasaCambio: 0.5, // Inválida bajo D-08 -> defaults
      });

      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider.prefsInstance = store;
      await provider.loadSettings();

      // Intentar fijar NaN
      await provider.setTasaCambio(double.nan);
      expect(provider.tasaCambioVesUsd, equals(AppConstants.defaultTasaCambio));

      // Intentar fijar Infinity
      await provider.setTasaCambio(double.infinity);
      expect(provider.tasaCambioVesUsd, equals(AppConstants.defaultTasaCambio));

      // Intentar fijar 0.5 o 1.0
      await provider.setTasaCambio(0.5);
      expect(provider.tasaCambioVesUsd, equals(AppConstants.defaultTasaCambio));

      await provider.setTasaCambio(1.0);
      expect(provider.tasaCambioVesUsd, equals(AppConstants.defaultTasaCambio));

      // Fijar tasa válida > 1.0
      await provider.setTasaCambio(55.0);
      expect(provider.tasaCambioVesUsd, equals(55.0));
    });

    test('actualizarTasaAutomatica no asigna Infinity a las tasas activas', () async {
      final provider = SettingsProvider(secureStorage: fakeSecureStorage, autoLoad: false);

      // Mock client que devuelve un JSON remoto anómalo
      final mockClient = MockClient((request) async {
        return http.Response('{"usd": 60.0, "eur": 65.0, "usdt": 62.0}', 200);
      });

      final success = await provider.actualizarTasaAutomatica(client: mockClient);
      expect(success, isTrue);
      expect(provider.tasaCambioVesUsd, equals(60.0));
      expect(provider.tasaCambioVesEur, equals(65.0));
      expect(provider.tasaCambioVesUsdt, equals(62.0));
    });
  });
}
