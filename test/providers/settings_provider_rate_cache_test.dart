import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/domain/monetary/rate_market.dart';
import 'package:gastoscan_ai/providers/settings_provider.dart';
import 'package:gastoscan_ai/services/connectivity_service.dart';
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
  TestableSettingsProvider({
    super.secureStorage,
    super.connectivityService,
    super.nowProvider,
    super.reconnectDebounce,
    super.autoRefreshCooldown,
    super.httpClient,
  }) : super(autoLoad: false);

  bool disableAutoSyncOnLoad = true;

  @override
  Future<bool> actualizarTasaAutomatica({http.Client? client}) async {
    if (disableAutoSyncOnLoad && client == null) {
      return false;
    }
    return super.actualizarTasaAutomatica(client: client);
  }
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

    test('Escenario 11: Purga fallida (-1) en SettingsProvider -> fail-closed, tasas en 0.0 y modo referencia (D-01, NEW-2, NEW-4)', () async {
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

      // NEW-4: No debe consumir 88.0 ni 95.0, ni asignar 850.0 como tasa efectiva; se asigna 0.0
      expect(provider.tasaCambioVesUsd, equals(0.0));
      expect(provider.tasaCambioVesEur, equals(0.0));
      expect(provider.tasaCambioVesUsdt, equals(0.0));
      expect(provider.ultimaActualizacionTasas, isNull);
      // NEW-2: Reseteo obligatorio a modo referencia
      expect(provider.tasasSonReferencia, isTrue);
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

      // Todos los valores inválidos deben ser descartados, adoptando 0.0 (NEW-4)
      expect(provider.tasaCambioVesUsd.isFinite, isTrue);
      expect(provider.tasaCambioVesUsd, equals(0.0));
      expect(provider.tasaCambioVesEur, equals(0.0));
      // USDT recurre al fallback de USD sin aceptar <= 1.0 (queda en 0.0)
      expect(provider.tasaCambioVesUsdt.isFinite, isTrue);
      expect(provider.tasaCambioVesUsdt, equals(0.0));
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
        AppConstants.prefTasaCambio: 0.5, // Inválida bajo D-08 -> defaults 0.0
      });

      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider.prefsInstance = store;
      await provider.loadSettings();

      // Intentar fijar NaN
      await provider.setTasaCambio(double.nan);
      expect(provider.tasaCambioVesUsd, equals(0.0));

      // Intentar fijar Infinity
      await provider.setTasaCambio(double.infinity);
      expect(provider.tasaCambioVesUsd, equals(0.0));

      // Intentar fijar 0.5 o 1.0
      await provider.setTasaCambio(0.5);
      expect(provider.tasaCambioVesUsd, equals(0.0));

      await provider.setTasaCambio(1.0);
      expect(provider.tasaCambioVesUsd, equals(0.0));

      // Fijar tasa válida > 1.0
      await provider.setTasaCambio(55.0);
      expect(provider.tasaCambioVesUsd, equals(55.0));
      expect(provider.tasasSonReferencia, isTrue);
    });

    test('NEW-3b / D-05: Tasa manual global persiste al reiniciar sobre cache anterior y se actualiza ante tasa viva', () async {
      final sharedStore = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_usd': 48.0, // Tasa automática anterior
      });

      // 1. Usuario establece tasa manual 55.0
      final provider1 = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider1.prefsInstance = sharedStore;
      await provider1.loadSettings();
      expect(provider1.tasaCambioVesUsd, equals(48.0));

      await provider1.setTasaCambio(55.0);
      expect(provider1.tasaCambioVesUsd, equals(55.0));

      // 2. Reinicio de aplicación (mismo store): la tasa manual prevalece sobre 48.0
      final provider2 = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider2.prefsInstance = sharedStore;
      await provider2.loadSettings();
      expect(provider2.tasaCambioVesUsd, equals(55.0));

      // 3. Vuelve Internet: llega cotización viva 62.0
      final liveMockClient = MockClient((request) async {
        return http.Response('{"usd": 62.0, "eur": 66.0, "usdt": 63.0}', 200);
      });
      final updated = await provider2.actualizarTasaAutomatica(client: liveMockClient);
      expect(updated, isTrue);
      // D-05: Tasa viva actualiza la tasa global activa y reemplaza la manual
      expect(provider2.tasaCambioVesUsd, equals(62.0));
      expect(provider2.tasasSonReferencia, isFalse);
    });

    test('actualizarTasaAutomatica asigna tasas validas obtenidas de red', () async {
      final provider = SettingsProvider(secureStorage: fakeSecureStorage, autoLoad: false);

      final mockClient = MockClient((request) async {
        return http.Response('{"usd": 60.0, "eur": 65.0, "usdt": 62.0}', 200);
      });

      final success = await provider.actualizarTasaAutomatica(client: mockClient);
      expect(success, isTrue);
      expect(provider.tasaCambioVesUsd, equals(60.0));
      expect(provider.tasaCambioVesEur, equals(65.0));
      expect(provider.tasaCambioVesUsdt, equals(62.0));
    });

    test('actualizarTasaAutomatica no asigna Infinity ni valores fuera de dominio ante respuesta anomala', () async {
      final provider = SettingsProvider(secureStorage: fakeSecureStorage, autoLoad: false);

      // Mock client con valores fuera de dominio
      final mockClient = MockClient((request) async {
        return http.Response('{"usd": 1e400, "eur": -10.0, "usdt": 0.5}', 200);
      });

      final success = await provider.actualizarTasaAutomatica(client: mockClient);
      expect(success, isFalse);
      expect(provider.tasaCambioVesUsd.isFinite, isTrue);
      expect(provider.tasaCambioVesUsd, equals(0.0));
      expect(provider.tasaCambioVesEur, equals(0.0));
      expect(provider.tasaCambioVesUsdt, equals(0.0));
    });

    test('M-05: setTasaCambio rescinde remove pendiente en ExchangeRateService al persistir tasa manual valida', () async {
      final store = TestSharedPreferences({
        AppConstants.prefTasaCambio: -10.0,
      });

      // 1. Purga falla en remove, dejando prefTasaCambio en pendingPurgeOperations
      store.returnFalseOnRemove = true;
      final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res1, equals(-1));
      expect(ExchangeRateService.pendingPurgeOperations.containsKey(AppConstants.prefTasaCambio), isTrue);

      // 2. Plataforma se recupera para escrituras
      store.returnFalseOnRemove = false;

      // 3. Usuario fija tasa manual 60.0 desde SettingsProvider
      final provider = SettingsProvider(secureStorage: fakeSecureStorage, autoLoad: false);
      provider.prefsInstance = store;
      await provider.setTasaCambio(60.0);

      // La escritura confirmada debe haber llamado a ExchangeRateService.onKeyWriteConfirmed
      expect(ExchangeRateService.pendingPurgeOperations.containsKey(AppConstants.prefTasaCambio), isFalse);
      expect(store.disk[AppConstants.prefTasaCambio], equals(60.0));

      // 4. Se ejecuta ensureCacheHistoricaPurgada: no debe borrar prefTasaCambio
      final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res2, equals(0));
      expect(store.disk[AppConstants.prefTasaCambio], equals(60.0));
      expect(store.getDouble(AppConstants.prefTasaCambio), equals(60.0));
    });

    test('N-09: loadSettings no lanza TypeError ante preferencias con tipos corruptos (safe getters)', () async {
      final storeWithCorruptTypes = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        AppConstants.prefGuardarFotos: 'true', // String en vez de bool
        'pref_es_tasa_manual_usd': 1, // int en vez de bool
        AppConstants.prefMonedaPrincipal: 100, // int en vez de String
        'tipo_tasa': false, // bool en vez de String
        'presupuesto_mensual': '500.0', // String en vez de double
        AppConstants.prefRecordatoriosActivos: 'yes',
        AppConstants.prefRecordatorioFinDeSemana: 0,
        AppConstants.prefAnunciosActivos: 1.0,
        AppConstants.prefCachedMensajesQuincenalesJson: 12345, // int en vez de String
      });

      final provider = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider.prefsInstance = storeWithCorruptTypes;

      // Debe completar limpiamente sin TypeError y adoptando los defaults
      await expectLater(provider.loadSettings(), completes);
      expect(provider.guardarFotos, equals(AppConstants.defaultGuardarFotos));
      expect(provider.monedaPrincipal, equals(AppConstants.defaultMoneda));
      expect(provider.tipoTasa, equals('oficial'));
      expect(provider.presupuestoMensual, equals(0.0));
    });

    test('D-05: Tasa manual global persiste ante reinicio offline, sincronizacion fallida y solo cede ante red viva (NEW-3b)', () async {
      final store = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'pref_es_tasa_manual_usd': true,
        AppConstants.prefTasaCambio: 55.0,
        'cached_rate_usd': 48.0,
      });

      // 1. Primer arranque en frío (offline): loadSettings debe priorizar la tasa manual (55.0)
      final provider1 = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider1.prefsInstance = store;
      await provider1.loadSettings();

      expect(provider1.tasaCambioVesUsd, equals(55.0));
      expect(provider1.esTasaManualUsd, isTrue);

      // 2. Sincronización de fondo sin conexión (failing client):
      // NO debe sobrescribir la tasa manual (55.0) con la caché antigua (48.0)
      final offlineClient = MockClient((_) async => http.Response('Error de conexión', 503));
      final syncResult = await provider1.actualizarTasaAutomatica(client: offlineClient);
      expect(syncResult, isFalse);
      expect(provider1.tasaCambioVesUsd, equals(55.0));
      expect(provider1.esTasaManualUsd, isTrue);
      expect(store.disk[AppConstants.prefTasaCambio], equals(55.0));
      expect(store.disk['pref_es_tasa_manual_usd'], isTrue);

      // 3. Segundo arranque offline simulado tras recarga física de disco
      store.reloadFromDisk();
      final provider2 = TestableSettingsProvider(secureStorage: fakeSecureStorage);
      provider2.prefsInstance = store;
      await provider2.loadSettings();

      expect(provider2.tasaCambioVesUsd, equals(55.0));
      expect(provider2.esTasaManualUsd, isTrue);

      // 4. Retorno de conexión a Internet con cotización en vivo válida (62.0):
      // Ahora sí sustituye la tasa manual y desactiva la bandera
      final liveClient = MockClient((request) async {
        return http.Response('{"usd": 62.0, "eur": 66.0, "usdt": 63.0}', 200);
      });
      final onlineResult = await provider2.actualizarTasaAutomatica(client: liveClient);
      expect(onlineResult, isTrue);
      expect(provider2.tasaCambioVesUsd, equals(62.0));
      expect(provider2.esTasaManualUsd, isFalse);
      expect(store.disk[AppConstants.prefTasaCambio], equals(62.0));
      expect(store.disk['pref_es_tasa_manual_usd'], isFalse);

      // 5. Si setTasaCambio falla al persistir en disco (returnFalseOnSetDouble),
      // no activa pref_es_tasa_manual_usd en disco ni en memoria
      store.returnFalseOnSetDouble = true;
      await provider2.setTasaCambio(70.0);
      expect(provider2.esTasaManualUsd, isFalse);
      expect(store.disk['pref_es_tasa_manual_usd'], isFalse);

      // 6. Si setDouble confirma pero setBool falla en disco (returnFalseOnSetBool),
      // la bandera en memoria no se activa para mantener consistencia con el disco
      store.returnFalseOnSetDouble = false;
      store.returnFalseOnSetBool = true;
      await provider2.setTasaCambio(75.0);
      expect(provider2.esTasaManualUsd, isFalse);
      expect(store.disk['pref_es_tasa_manual_usd'], isFalse);
    });
  });

  group('SettingsProvider - Resiliencia Offline y Auto-actualizacion de Tasas', () {
    late FakeSecureStorage fakeSecureStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ExchangeRateService.resetPendingPurgeOperationsForTesting();
      fakeSecureStorage = FakeSecureStorage();
    });

    tearDown(() {
      ExchangeRateService.resetPendingPurgeOperationsForTesting();
      ConnectivityService.reset();
    });

    test('fail-fast offline: actualizarTasaAutomatica no dispara HTTP sin conexion', () async {
      int httpCalls = 0;
      final client = MockClient((_) async {
        httpCalls++;
        return http.Response('{"usd": 60.0, "eur": 65.0, "usdt": 62.0}', 200);
      });

      final provider = SettingsProvider(
        secureStorage: fakeSecureStorage,
        autoLoad: false,
        connectivityService: ConnectivityService(testConnected: false),
      );
      addTearDown(provider.dispose);

      final result = await provider.actualizarTasaAutomatica(client: client);
      expect(result, isFalse);
      expect(httpCalls, 0);
      expect(provider.isSyncingRate, isFalse);
    });

    test('cerrojo de concurrencia: dos llamadas simultaneas comparten una sola peticion HTTP', () async {
      int httpCalls = 0;
      final gate = Completer<void>();
      final client = MockClient((_) async {
        httpCalls++;
        await gate.future;
        return http.Response('{"usd": 61.0, "eur": 66.0, "usdt": 63.0}', 200);
      });

      final provider = SettingsProvider(
        secureStorage: fakeSecureStorage,
        autoLoad: false,
        connectivityService: ConnectivityService(testConnected: true),
      );
      addTearDown(provider.dispose);

      final f1 = provider.actualizarTasaAutomatica(client: client);
      final f2 = provider.actualizarTasaAutomatica(client: client);

      await Future<void>.delayed(Duration.zero);
      gate.complete();

      final results = await Future.wait([f1, f2]);
      expect(results, equals([true, true]));
      expect(httpCalls, 1);
      expect(provider.tasaCambioVesUsd, equals(61.0));
    });

    test('si EUR o USDT llega nulo o 0.0 no se marca actualizada y necesitaActualizarTasas es true', () async {
      final partialClient = MockClient((request) async {
        if (request.url.path.contains('/tasas')) {
          return http.Response('{"usd": 60.0, "eur": null, "usdt": 0.0}', 200);
        }
        return http.Response('error', 503);
      });

      final provider = SettingsProvider(
        secureStorage: fakeSecureStorage,
        autoLoad: false,
        connectivityService: ConnectivityService(testConnected: true),
      );
      addTearDown(provider.dispose);

      final ok = await provider.actualizarTasaAutomatica(client: partialClient);
      expect(ok, isTrue);
      expect(provider.estadoTasaUsd, equals(EstadoTasaMoneda.actualizada));
      expect(provider.estadoTasaEur, equals(EstadoTasaMoneda.sinTasa));
      expect(provider.estadoTasaUsdt, equals(EstadoTasaMoneda.sinTasa));
      expect(provider.necesitaActualizarTasas, isTrue);
    });

    test('si EUR o USDT llega nulo o 0.0 con cache previa de ayer queda en referencia y necesitaActualizarTasas es true', () async {
      final partialClient = MockClient((request) async {
        if (request.url.path.contains('/tasas')) {
          return http.Response('{"usd": 60.0, "eur": null, "usdt": 0.0}', 200);
        }
        return http.Response('error', 503);
      });

      final fakeNow = DateTime(2026, 11, 20, 10, 0);
      final store = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_usd': 50.0,
        'cached_rate_eur': 54.0,
        'cached_rate_usdt': 52.0,
        'cached_exchange_rates_timestamp': DateTime(2026, 11, 19, 10, 0).toIso8601String(),
      });

      final provider = SettingsProvider(
        secureStorage: fakeSecureStorage,
        autoLoad: false,
        prefsInstance: store,
        connectivityService: ConnectivityService(testConnected: true),
        nowProvider: () => fakeNow,
      );
      addTearDown(provider.dispose);

      final ok = await provider.actualizarTasaAutomatica(client: partialClient);
      expect(ok, isTrue);
      expect(provider.tasaCambioVesUsd, equals(60.0));
      expect(provider.tasaCambioVesEur, equals(54.0));
      expect(provider.tasaCambioVesUsdt, equals(52.0));
      expect(provider.estadoTasaUsd, equals(EstadoTasaMoneda.actualizada));
      expect(provider.estadoTasaEur, equals(EstadoTasaMoneda.referencia));
      expect(provider.estadoTasaUsdt, equals(EstadoTasaMoneda.referencia));
      expect(provider.necesitaActualizarTasas, isTrue);
    });

    test('reconexion en stream de conectividad actualiza tasas tras debounce si estaban en referencia', () async {
      final connController = StreamController<bool>.broadcast();
      addTearDown(connController.close);

      int httpCalls = 0;
      final syncDone = Completer<void>();
      final liveClient = MockClient((_) async {
        httpCalls++;
        return http.Response('{"usd": 64.0, "eur": 69.0, "usdt": 66.0}', 200);
      });

      final fakeNow = DateTime(2026, 11, 20, 10, 0);
      final store = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_usd': 50.0,
        'cached_rate_eur': 54.0,
        'cached_rate_usdt': 52.0,
        'cached_exchange_rates_timestamp': DateTime(2026, 11, 19, 10, 0).toIso8601String(),
      });

      final provider = SettingsProvider(
        secureStorage: fakeSecureStorage,
        autoLoad: false,
        prefsInstance: store,
        connectivityService: ConnectivityService(
          testController: connController,
          testConnected: false,
        ),
        nowProvider: () => fakeNow,
        reconnectDebounce: const Duration(milliseconds: 20),
        httpClient: liveClient,
      );
      addTearDown(provider.dispose);

      provider.addListener(() {
        if (!provider.isSyncingRate &&
            provider.estadoTasaUsd == EstadoTasaMoneda.actualizada &&
            !syncDone.isCompleted) {
          syncDone.complete();
        }
      });

      // Arranque offline: queda en referencia sin tocar red
      await provider.loadSettings();
      await Future<void>.delayed(Duration.zero);
      expect(provider.estadoTasaUsd, equals(EstadoTasaMoneda.referencia));
      expect(httpCalls, 0);

      // Recupera conexion: tras debounce actualiza automaticamente
      connController.add(true);
      await syncDone.future.timeout(const Duration(seconds: 3));

      expect(httpCalls, 1);
      expect(provider.estadoTasaUsd, equals(EstadoTasaMoneda.actualizada));
      expect(provider.tasaCambioVesUsd, equals(64.0));
      expect(provider.tasaCambioVesEur, equals(69.0));
      expect(provider.tasaCambioVesUsdt, equals(66.0));
      expect(provider.necesitaActualizarTasas, isFalse);
    });

    test('no dispara red si las 3 tasas estan actualizadas hoy y si dispara al cambiar dia local', () async {
      DateTime fakeNow = DateTime(2026, 11, 20, 21, 30);
      int httpCalls = 0;
      final client = MockClient((_) async {
        httpCalls++;
        return http.Response('{"usd": 65.0, "eur": 70.0, "usdt": 67.0}', 200);
      });

      final provider = SettingsProvider(
        secureStorage: fakeSecureStorage,
        autoLoad: false,
        connectivityService: ConnectivityService(testConnected: true),
        nowProvider: () => fakeNow,
        autoRefreshCooldown: Duration.zero,
      );
      addTearDown(provider.dispose);

      // Primera sincronizacion el 20/11 a las 21:30 hora local
      await provider.actualizarTasaAutomatica(client: client);
      expect(httpCalls, 1);
      expect(provider.necesitaActualizarTasas, isFalse);

      // Mismo dia local 20/11 a las 23:45: no debe refrescar
      fakeNow = DateTime(2026, 11, 20, 23, 45);
      final skipped = await provider.refrescarTasasSiDesactualizadas(client: client);
      expect(skipped, isFalse);
      expect(httpCalls, 1);

      // Cruza medianoche local al 21/11 00:05: ahora si refresca
      fakeNow = DateTime(2026, 11, 21, 0, 5);
      expect(provider.necesitaActualizarTasas, isTrue);
      final refreshed = await provider.refrescarTasasSiDesactualizadas(client: client);
      expect(refreshed, isTrue);
      expect(httpCalls, 2);
    });
  });
}
