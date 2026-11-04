import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/services/exchange_rate_service.dart';

/// Fake configurable de SharedPreferences que implementa un modelo de dos estados (O2):
/// - memory: estado de la caché síncrona en memoria.
/// - disk: estado persistido en el almacenamiento de la plataforma.
/// Permite simular mutaciones en memoria que fallan al persistir en disco,
/// fallos de E/S, excepciones en escrituras, retornos booleanos falsos y reintentos.
class TestSharedPreferences extends Fake implements SharedPreferences {
  final Map<String, Object> memory = {};
  final Map<String, Object> disk = {};
  final List<String> removedKeys = [];
  final Map<String, String> setStringValues = {};
  final Map<String, bool> setBoolValues = {};
  final Map<String, double> setDoubleValues = {};

  bool throwOnSetString = false;
  bool returnFalseOnSetString = false;
  bool throwOnRemove = false;
  bool returnFalseOnRemove = false;
  bool throwOnSetBool = false;
  bool returnFalseOnSetBool = false;
  bool throwOnSetDouble = false;
  bool returnFalseOnSetDouble = false;

  Map<String, Object> get data => memory;

  TestSharedPreferences([Map<String, Object>? initialValues]) {
    if (initialValues != null) {
      memory.addAll(initialValues);
      disk.addAll(initialValues);
    }
  }

  /// Simula el reinicio de proceso o recarga desde el almacenamiento persistente
  void reloadFromDisk() {
    memory.clear();
    memory.addAll(disk);
  }

  @override
  Set<String> getKeys() => memory.keys.toSet();

  @override
  Object? get(String key) => memory[key];

  @override
  String? getString(String key) {
    // Reproduce el comportamiento real del plugin (cast tipado a String? que lanza TypeError ante tipo incompatible)
    return memory[key] as String?;
  }

  @override
  double? getDouble(String key) {
    // Reproduce el comportamiento real del plugin (cast tipado a double? que lanza TypeError ante tipo incompatible)
    return memory[key] as double?;
  }

  @override
  bool? getBool(String key) {
    // Reproduce el comportamiento real del plugin (cast tipado a bool? que lanza TypeError ante tipo incompatible)
    return memory[key] as bool?;
  }

  @override
  Future<bool> setString(String key, String value) async {
    // La mutación en memoria ocurre antes de la llamada de plataforma
    memory[key] = value;
    setStringValues[key] = value;
    if (throwOnSetString) {
      throw Exception('Simulated disk/IO error on setString');
    }
    if (returnFalseOnSetString) {
      return false;
    }
    disk[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    // La mutación en memoria ocurre antes de la llamada de plataforma
    memory[key] = value;
    setDoubleValues[key] = value;
    if (throwOnSetDouble) {
      throw Exception('Simulated disk/IO error on setDouble');
    }
    if (returnFalseOnSetDouble) {
      return false;
    }
    disk[key] = value;
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    memory[key] = value;
    setBoolValues[key] = value;
    if (throwOnSetBool) {
      throw Exception('Simulated disk/IO error on setBool');
    }
    if (returnFalseOnSetBool) {
      return false;
    }
    disk[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    removedKeys.add(key);
    // En el plugin real, la caché en memoria se muta antes de la llamada de plataforma
    memory.remove(key);
    if (throwOnRemove) {
      throw Exception('Simulated disk/IO error on remove');
    }
    if (returnFalseOnRemove) {
      return false;
    }
    disk.remove(key);
    return true;
  }
}

/// Mantiene compatibilidad con la referencia en pruebas previas
typedef FailingRemoveSharedPreferences = TestSharedPreferences;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ExchangeRateService.clearHistoricosCache();
    ExchangeRateService.resetPendingPurgeOperationsForTesting();
  });

  tearDown(() {
    ExchangeRateService.resetPendingPurgeOperationsForTesting();
  });

  group('ExchangeRateService - Limpieza Selectiva de Caché Histórica (A-07 & B1 & N1)', () {
    test('Purga selectivamente entradas <= 1.0 e inválidas preservando válidas y antiguas legítimas', () async {
      final store = TestSharedPreferences({
        // Válidas (deben conservarse intactas)
        'cached_rate_usd': 100.0,
        'cached_rate_eur': 110.0,
        'cached_rate_USD_2026-10-31': 40.0,
        'cached_rate_EUR_2026-10-31': 44.0,

        // Entradas antiguas legítimas (anteriores a 2023-01-03, DEBEN CONSERVARSE según A-07)
        'cached_rate_USD_2022-10-15': 8.30,
        'cached_rate_EUR_2021-06-20': 5.25,

        // Inválidas en tasas del día (deben removerse)
        'cached_rate_usdt': 0.0,
        'cached_exchange_rate': -5.0,

        // Inválidas en históricos individuales (deben removerse)
        'cached_rate_USD_2026-10-30': 1.0, // <= 1.0
        'cached_rate_EUR_fecha_invalida': 20.0, // Formato no ISO YYYY-MM-DD

        // 'tasas_historico_v1' con mezcla de entradas
        'tasas_historico_v1': jsonEncode({
          '2026-10-31': {'valor': 40.0, 'source': 'dolarapi'},
          '2026-10-30': {'valor': 0.5, 'source': 'dolarapi'}, // Inválida (<= 1.0)
          '2022-05-01': {'valor': 25.0, 'source': 'dolarapi'}, // Antigua legítima (> 1.0 con fuente) -> CONSERVAR
          '2026-10-29': {'valor': 41.0, 'source': ''}, // Fuente vacía -> REMOVER
          'not-a-date': {'valor': 40.0, 'source': 'dolarapi'}, // Fecha malformada -> REMOVER
        }),
      });

      final cleanedCount = await ExchangeRateService.purgarCacheHistoricaInvalida(
        prefsInstance: store,
      );

      // Claves individuales inválidas:
      // cached_rate_usdt (0.0), cached_exchange_rate (-5.0), cached_rate_USD_2026-10-30 (1.0),
      // cached_rate_EUR_fecha_invalida, más 3 entradas dentro de tasas_historico_v1 = 7
      expect(cleanedCount, equals(7));

      // Verificar que las válidas persisten
      expect(store.getDouble('cached_rate_usd'), equals(100.0));
      expect(store.getDouble('cached_rate_eur'), equals(110.0));
      expect(store.getDouble('cached_rate_USD_2026-10-31'), equals(40.0));
      expect(store.getDouble('cached_rate_EUR_2026-10-31'), equals(44.0));

      // Verificar que las antiguas legítimas persisten intactas
      expect(store.getDouble('cached_rate_USD_2022-10-15'), equals(8.30));
      expect(store.getDouble('cached_rate_EUR_2021-06-20'), equals(5.25));

      // Verificar que las inválidas fueron removidas (incluyendo cached_exchange_rate)
      expect(store.getDouble('cached_rate_usdt'), isNull);
      expect(store.getDouble('cached_exchange_rate'), isNull);
      expect(store.getDouble('cached_rate_USD_2026-10-30'), isNull);
      expect(store.getDouble('cached_rate_EUR_fecha_invalida'), isNull);

      // Verificar contenido depurado de tasas_historico_v1
      final histRaw = store.getString('tasas_historico_v1');
      expect(histRaw, isNotNull);
      final hist = jsonDecode(histRaw!) as Map<String, dynamic>;
      expect(hist.containsKey('2026-10-31'), isTrue);
      expect(hist.containsKey('2022-05-01'), isTrue); // Antigua legítima conservada
      expect(hist.containsKey('2026-10-30'), isFalse); // <= 1.0 removida
      expect(hist.containsKey('2026-10-29'), isFalse); // Fuente vacía removida
      expect(hist.containsKey('not-a-date'), isFalse); // Fecha malformada removida
    });

    test('tasas_historico_v1: entrada mal tipada (String como valor) se descarta sin borrar el resto del mapa historico', () async {
      final store = TestSharedPreferences({
        'tasas_historico_v1': jsonEncode({
          '2026-10-31': {'valor': 40.0, 'source': 'dolarapi'},
          '2026-10-30': {'valor': 'no_es_un_numero', 'source': 'dolarapi'}, // Valor String inválido
          '2022-05-01': {'valor': 25.0, 'source': 'dolarapi'}, // Antigua legítima válida
        }),
      });

      final cleanedCount = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);

      expect(cleanedCount, equals(1));

      final hist = jsonDecode(store.getString('tasas_historico_v1')!) as Map<String, dynamic>;
      expect(hist.containsKey('2026-10-31'), isTrue);
      expect(hist.containsKey('2022-05-01'), isTrue);
      expect(hist.containsKey('2026-10-30'), isFalse);
    });

    test('tasas_historico_v1: source con tipo incorrecto (num en lugar de String) se descarta selectivamente', () async {
      final store = TestSharedPreferences({
        'tasas_historico_v1': jsonEncode({
          '2026-10-31': {'valor': 40.0, 'source': 'dolarapi'},
          '2026-10-29': {'valor': 42.0, 'source': 99999}, // Source numérico inválido
        }),
      });

      final cleanedCount = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);

      expect(cleanedCount, equals(1));

      final hist = jsonDecode(store.getString('tasas_historico_v1')!) as Map<String, dynamic>;
      expect(hist.containsKey('2026-10-31'), isTrue);
      expect(hist.containsKey('2026-10-29'), isFalse);
    });

    test('Purga fechas imposibles del calendario tanto en tasas_historico_v1 como en claves cached_rate_*', () async {
      final store = TestSharedPreferences({
        // Fechas de calendario imposibles
        'cached_rate_USD_2026-02-30': 40.0, // Febrero nunca tiene 30 días
        'cached_rate_EUR_2026-13-40': 45.0, // Mes 13, día 40
        'cached_rate_USD_2026-04-31': 41.0, // Abril solo tiene 30 días

        // Fechas válidas
        'cached_rate_USD_2024-02-29': 36.0, // 2024 bisiesto -> VÁLIDA, conservar
        'cached_rate_USD_2026-10-31': 40.0, // Octubre tiene 31 días -> VÁLIDA, conservar

        // tasas_historico_v1 con fechas imposibles
        'tasas_historico_v1': jsonEncode({
          '2026-02-30': {'valor': 40.0, 'source': 'dolarapi'}, // Imposible
          '2026-13-40': {'valor': 42.0, 'source': 'dolarapi'}, // Imposible
          '2026-10-31': {'valor': 40.0, 'source': 'dolarapi'}, // Válida
        }),
      });

      final cleanedCount = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);

      expect(cleanedCount, equals(5));

      // Claves individuales
      expect(store.getDouble('cached_rate_USD_2026-02-30'), isNull);
      expect(store.getDouble('cached_rate_EUR_2026-13-40'), isNull);
      expect(store.getDouble('cached_rate_USD_2026-04-31'), isNull);
      expect(store.getDouble('cached_rate_USD_2024-02-29'), equals(36.0));
      expect(store.getDouble('cached_rate_USD_2026-10-31'), equals(40.0));

      // Mapa histórico
      final hist = jsonDecode(store.getString('tasas_historico_v1')!) as Map<String, dynamic>;
      expect(hist.containsKey('2026-02-30'), isFalse);
      expect(hist.containsKey('2026-13-40'), isFalse);
      expect(hist.containsKey('2026-10-31'), isTrue);
      expect(hist['2026-10-31']['valor'], equals(40.0));
    });

    test('cached_exchange_rate: se purga si es <= 1.0 pero se conserva si es una tasa valida', () async {
      // Caso 1: Inválida (<= 1.0)
      final store1 = TestSharedPreferences({
        'cached_exchange_rate': -5.0,
      });
      var count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store1);
      expect(count, equals(1));
      expect(store1.getDouble('cached_exchange_rate'), isNull);

      // Caso 2: Válida (> 1.0)
      final store2 = TestSharedPreferences({
        'cached_exchange_rate': 42.0,
      });
      count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store2);
      expect(count, equals(0));
      expect(store2.getDouble('cached_exchange_rate'), equals(42.0));
    });

    test('Fallo en remove: la marca de purga no debe quedar establecida y se reporta fallo', () async {
      final failingStore = TestSharedPreferences({
        'cached_rate_usdt': 0.0, // Entrada inválida a remover
      });
      failingStore.returnFalseOnRemove = true;

      // Al fallar la persistencia física (remove retorna false), debe lanzar StateError en llamada directa
      expect(
        () => ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: failingStore),
        throwsA(isA<StateError>()),
      );

      // Y ensureCacheHistoricaPurgada NO debe fijar la marca persistente
      final result = await ExchangeRateService.ensureCacheHistoricaPurgada(
        prefsInstance: failingStore,
      );
      expect(result, equals(-1));
      expect(failingStore.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isNot(true));
    });

    test('Concurrencia: dos llamadas simultaneas a ensureCacheHistoricaPurgada ejecutan una sola purga', () async {
      final store = TestSharedPreferences({
        'cached_rate_usdt': 0.0,
        'cached_rate_usd': 55.0,
      });

      final results = await Future.wait([
        ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store),
        ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store),
      ]);

      expect(results[0], equals(1));
      expect(results[1], equals(1));
      expect(store.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isTrue);
      expect(store.getDouble('cached_rate_usdt'), isNull);
      expect(store.getDouble('cached_rate_usd'), equals(55.0));
    });

    test('Idempotencia directa: segunda llamada a purgarCacheHistoricaInvalida sobre datos limpios retorna 0 y no muta', () async {
      final store = TestSharedPreferences({
        'cached_rate_usd': 55.0,
        'cached_rate_usdt': 0.0, // Será purgada
      });

      final firstCount = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);
      expect(firstCount, equals(1));
      expect(store.getDouble('cached_rate_usdt'), isNull);

      final secondCount = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);
      expect(secondCount, equals(0));
      expect(store.getDouble('cached_rate_usd'), equals(55.0));
    });

    test('ensureCacheHistoricaPurgada ejecuta una sola vez y es estrictamente idempotente', () async {
      final store = TestSharedPreferences({
        'cached_rate_usdt': 0.0, // Inválida
        'cached_rate_usd': 55.0,  // Válida
      });

      // Primera ejecución: purga la entrada inválida y fija la marca persistente
      final cleanedFirst = await ExchangeRateService.ensureCacheHistoricaPurgada(
        prefsInstance: store,
      );
      expect(cleanedFirst, equals(1));
      expect(store.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isTrue);
      expect(store.getDouble('cached_rate_usdt'), isNull);
      expect(store.getDouble('cached_rate_usd'), equals(55.0));

      // Simulamos que por alguna razón se agrega una nueva clave inválida después de la purga
      await store.setDouble('cached_rate_usdt', 0.0);

      // Segunda ejecución: al estar la marca activa, retorna 0 inmediatamente sin re-iterar
      final cleanedSecond = await ExchangeRateService.ensureCacheHistoricaPurgada(
        prefsInstance: store,
      );
      expect(cleanedSecond, equals(0));
    });

    // =========================================================================
    // CASOS OBLIGATORIOS CORRECCIÓN B1 (PERSISTENCIA Y AISLAMIENTO)
    // =========================================================================

    test('B1: setString lanza excepcion: historial conserva entradas validas, clave no se elimina, no se fija marca', () async {
      final initialJson = jsonEncode({
        '2026-10-31': {'valor': 40.0, 'source': 'dolarapi'}, // Válida
        '2026-10-30': {'valor': 0.5, 'source': 'dolarapi'}, // Inválida
      });
      final store = TestSharedPreferences({
        'tasas_historico_v1': initialJson,
      });
      store.throwOnSetString = true;

      // 1. purgarCacheHistoricaInvalida debe lanzar StateError al fallar la persistencia
      expect(
        () => ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store),
        throwsA(isA<StateError>()),
      );

      // 2. Clave tasas_historico_v1 NUNCA debe haber sido añadida a keysToRemove ni eliminada
      expect(store.removedKeys.contains('tasas_historico_v1'), isFalse);
      // El contenido original en disco debe preservarse intacto tras reload
      expect(store.disk['tasas_historico_v1'], equals(initialJson));
      store.reloadFromDisk();
      expect(store.getString('tasas_historico_v1'), equals(initialJson));

      // 3. ensureCacheHistoricaPurgada debe retornar -1 y NO fijar la marca persistente
      final res = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res, equals(-1));
      expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
      expect(store.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isNot(true));
      expect(store.removedKeys.contains('tasas_historico_v1'), isFalse);
      expect(store.disk['tasas_historico_v1'], equals(initialJson));
    });

    test('B1: setString retorna false: conserva historial original, no fija marca y reporta fallo', () async {
      final initialJson = jsonEncode({
        '2026-10-31': {'valor': 40.0, 'source': 'dolarapi'},
        '2026-10-30': {'valor': 0.5, 'source': 'dolarapi'},
      });
      final store = TestSharedPreferences({
        'tasas_historico_v1': initialJson,
      });
      store.returnFalseOnSetString = true;

      expect(
        () => ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store),
        throwsA(isA<StateError>()),
      );

      // Clave preservada en disco sin eliminación
      expect(store.removedKeys.contains('tasas_historico_v1'), isFalse);
      expect(store.disk['tasas_historico_v1'], equals(initialJson));
      store.reloadFromDisk();
      expect(store.getString('tasas_historico_v1'), equals(initialJson));

      // ensureCacheHistoricaPurgada retorna -1 y no fija marca
      final res = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res, equals(-1));
      expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
      expect(store.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isNot(true));
    });

    test('B1 & B4: setString falla transitoriamente y luego se recupera en una segunda ejecucion', () async {
      final initialJson = jsonEncode({
        '2026-10-31': {'valor': 40.0, 'source': 'dolarapi'}, // Válida
        '2026-10-30': {'valor': 0.5, 'source': 'dolarapi'}, // Inválida
      });
      final store = TestSharedPreferences({
        'tasas_historico_v1': initialJson,
      });

      // Ejecución 1: Fallo transitorio en setString
      store.throwOnSetString = true;
      final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res1, equals(-1));
      expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
      expect(store.disk['tasas_historico_v1'], equals(initialJson));

      // Simular recuperación de la persistencia sin reloadFromDisk (mismo proceso)
      store.throwOnSetString = false;

      // Ejecución 2: Reintento exitoso
      final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res2, equals(1)); // 1 entrada depurada (2026-10-30)
      expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
      expect(store.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isTrue);

      final hist = jsonDecode(store.disk['tasas_historico_v1']! as String) as Map<String, dynamic>;
      expect(hist.containsKey('2026-10-31'), isTrue);
      expect(hist.containsKey('2026-10-30'), isFalse);
    });

    // =========================================================================
    // CASOS OBLIGATORIOS CORRECCIÓN N1 (VALIDACIÓN DE TASAS AL CONSUMO)
    // =========================================================================

    test('N1: getRateForDate rechaza tasa 0.5, NaN, Infinity y -Infinity en cache local', () async {
      final failingClient = MockClient((_) async => http.Response('error', 500));

      // Caso 1: tasa 0.5 en cache (<= 1.0)
      final store05 = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_USD_2026-10-01': 0.5,
      });
      final rate05 = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: failingClient,
        prefsInstance: store05,
      );
      expect(rate05, equals(0.0)); // No devuelve 0.5

      // Caso 2: NaN en cache
      final storeNan = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_USD_2026-10-01': double.nan,
      });
      final rateNan = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: failingClient,
        prefsInstance: storeNan,
      );
      expect(rateNan, equals(0.0));

      // Caso 3: Infinity en cache
      final storeInf = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_USD_2026-10-01': double.infinity,
      });
      final rateInf = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: failingClient,
        prefsInstance: storeInf,
      );
      expect(rateInf, equals(0.0));

      // Caso 4: -Infinity en cache
      final storeNegInf = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_USD_2026-10-01': double.negativeInfinity,
      });
      final rateNegInf = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: failingClient,
        prefsInstance: storeNegInf,
      );
      expect(rateNegInf, equals(0.0));
    });

    test('N1: getRateForDate rechaza tasas no finitas o <= 1.0 provenientes de respuesta remota y no las persiste', () async {
      final mock = MockClient((request) async {
        if (request.url.toString().contains('/historicos/dolares/oficial')) {
          // Devuelve un promedio inválido de 0.5
          return http.Response(
            '[{"fecha":"2026-10-01","promedio":0.5}]',
            200,
          );
        }
        return http.Response('error', 500);
      });

      final store = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
      });

      final rate = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: mock,
        prefsInstance: store,
      );
      expect(rate, equals(0.0));
      // No debe haberse guardado en cache
      expect(store.data.containsKey('cached_rate_USD_2026-10-01'), isFalse);
    });

    // =========================================================================
    // CASOS COMPORTAMIENTO FAIL-CLOSED ANTE PURGA FALLIDA
    // =========================================================================

    test('Fail-Closed: si la purga falla (-1), no se consume cache ni semillas no verificadas', () async {
      // Simula store donde purge falla (remove retorna false)
      final store = TestSharedPreferences({
        'cached_rate_usdt': 0.0, // Forzará remove -> falla
        'cached_rate_usd': 55.0, // Semilla potencialmente contaminada
        'cached_rate_USD_2026-10-01': 45.0, // Cache historico no verificado
      });
      store.returnFalseOnRemove = true;

      final failingClient = MockClient((_) async => http.Response('error', 500));

      // 1. getAllTodayRates omite semillas ante purga fallida (fail-closed)
      final todayData = await ExchangeRateService.getAllTodayRates(
        client: failingClient,
        prefsInstance: store,
      );
      expect(todayData.usd, equals(0.0)); // No consumió 55.0

      // 2. getRateForDate omite cache local ante purga fallida (fail-closed)
      final histRate = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: failingClient,
        prefsInstance: store,
      );
      expect(histRate, equals(0.0)); // No consumió 45.0

      // 3. Consulta remota independiente y valida si puede ser consumida
      final successClient = MockClient((request) async {
        if (request.url.toString().contains('/historicos/dolares/oficial')) {
          return http.Response('[{"fecha":"2026-10-01","promedio":42.0}]', 200);
        }
        return http.Response('error', 500);
      });
      final remoteRate = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: successClient,
        prefsInstance: store,
      );
      expect(remoteRate, equals(42.0));
    });

    // =========================================================================
    // PROTECCIÓN DE getAllTodayRates CONTRA VALORES NO FINITOS
    // =========================================================================

    test('getAllTodayRates: semillas NaN o Infinity no llegan a ExchangeRatesData', () async {
      final store = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_usd': double.nan,
        'cached_rate_eur': double.infinity,
        'cached_rate_usdt': double.negativeInfinity,
      });

      final failingClient = MockClient((_) async => http.Response('error', 500));

      final data = await ExchangeRateService.getAllTodayRates(
        client: failingClient,
        prefsInstance: store,
      );

      expect(data.usd, equals(0.0));
      expect(data.eur, equals(0.0));
      expect(data.usdt, equals(0.0));
      expect(data.usd.isFinite, isTrue);
      expect(data.eur.isFinite, isTrue);
      expect(data.usdt.isFinite, isTrue);
    });

    test('ExchangeRatesData.fromJson descarta valores no finitos convirtiendolos a 0.0', () {
      final data = ExchangeRatesData.fromJson({
        'usd': double.nan,
        'eur': double.infinity,
        'usdt': double.negativeInfinity,
        'fecha': '2026-10-31T12:00:00Z',
        'esReferencia': false,
      });
      expect(data.usd, equals(0.0));
      expect(data.eur, equals(0.0));
      expect(data.usdt, equals(0.0));
      expect(data.usd.isFinite, isTrue);
    });

    test('B3: ExchangeRatesData.fromJson rechaza 0.5, 1.0, -5.0 y no finitos en cada moneda', () {
      // Caso 1: 0.5
      final d05 = ExchangeRatesData.fromJson({'usd': 0.5, 'eur': 0.5, 'usdt': 0.5});
      expect(d05.usd, equals(0.0));
      expect(d05.eur, equals(0.0));
      expect(d05.usdt, equals(0.0));

      // Caso 2: 1.0
      final d10 = ExchangeRatesData.fromJson({'usd': 1.0, 'eur': 1.0, 'usdt': 1.0});
      expect(d10.usd, equals(0.0));
      expect(d10.eur, equals(0.0));
      expect(d10.usdt, equals(0.0));

      // Caso 3: -5.0
      final dNeg = ExchangeRatesData.fromJson({'usd': -5.0, 'eur': -5.0, 'usdt': -5.0});
      expect(dNeg.usd, equals(0.0));
      expect(dNeg.eur, equals(0.0));
      expect(dNeg.usdt, equals(0.0));

      // Caso 4: No finitos (NaN, Infinity, -Infinity)
      final dNonFinite = ExchangeRatesData.fromJson({
        'usd': double.nan,
        'eur': double.infinity,
        'usdt': double.negativeInfinity,
      });
      expect(dNonFinite.usd, equals(0.0));
      expect(dNonFinite.eur, equals(0.0));
      expect(dNonFinite.usdt, equals(0.0));
      expect(dNonFinite.usd.isFinite, isTrue);

      // Caso 5: Tasa válida mayor a 1.0 se conserva y monedas se validan independientemente
      final dValid = ExchangeRatesData.fromJson({
        'usd': 42.5,
        'eur': 0.5, // inválida
        'usdt': double.infinity, // no finita
      });
      expect(dValid.usd, equals(42.5));
      expect(dValid.eur, equals(0.0));
      expect(dValid.usdt, equals(0.0));
    });

    test('B3-OBS: ExchangeRatesData.fromJson no lanza TypeError ante tipos no numericos y degrada fail-closed', () {
      final data = ExchangeRatesData.fromJson({
        'usd': '45.0', // String en lugar de num
        'eur': true, // bool en lugar de num
        'usdt': {'valor': 42.0}, // Map en lugar de num
        'fecha': 12345, // int en lugar de String
        'esReferencia': 'false', // String en lugar de bool
      });

      expect(data.usd, equals(0.0));
      expect(data.eur, equals(0.0));
      expect(data.usdt, equals(0.0));
      expect(data.esReferencia, isTrue);
      expect(data.fecha, equals(DateTime.fromMillisecondsSinceEpoch(0)));
    });

    // =========================================================================
    // PROTECCIÓN CONTRA LECTURAS CORRUPTAS DE SHAREDPREFERENCES
    // =========================================================================

    test('Marca persistente corrupta (tipo no booleano): no se toma como valida y reintenta purga', () async {
      final store = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: 'true_corrupto', // String en vez de bool
        'cached_rate_usdt': 0.0, // Debe purgarse
      });

      final result = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(result, equals(1));
      expect(store.data[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
      expect(store.data.containsKey('cached_rate_usdt'), isFalse);
    });

    test('B5: Historial tasas_historico_v1 con tipo no String se purga como dato corrupto', () async {
      final store = TestSharedPreferences({
        'tasas_historico_v1': 12345, // int no esperado (dato corrupto)
      });

      // purgarCacheHistoricaInvalida marca la clave corrupta para eliminación
      final count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);
      expect(count, equals(1));
      expect(store.removedKeys.contains('tasas_historico_v1'), isTrue);
      expect(store.disk.containsKey('tasas_historico_v1'), isFalse);
      expect(store.getString('tasas_historico_v1'), isNull);

      // ensureCacheHistoricaPurgada completa con éxito y fija la marca
      final store2 = TestSharedPreferences({
        'tasas_historico_v1': 12345,
      });
      final res = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store2);
      expect(res, equals(1));
      expect(store2.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
      expect(store2.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isTrue);
      expect(store2.disk.containsKey('tasas_historico_v1'), isFalse);

      // Una ejecución posterior es idempotente
      final resPost = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store2);
      expect(resPost, equals(0));
    });

    test('B5: Recuperación obligatoria en dos ejecuciones consecutivas ante fallo transitorio con tipo incorrecto', () async {
      final store = TestSharedPreferences({
        'tasas_historico_v1': 12345, // int corrupto
      });

      // Primera ejecución: fallo transitorio de E/S en remove
      store.returnFalseOnRemove = true;
      final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res1, equals(-1));
      expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
      expect(store.disk.containsKey('tasas_historico_v1'), isTrue); // Permanece en disco

      // Segunda ejecución: operación de remove recuperada en el mismo proceso (sin reloadFromDisk)
      store.returnFalseOnRemove = false;
      final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res2, equals(1)); // Corrupción purgada exitosamente
      expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
      expect(store.disk.containsKey('tasas_historico_v1'), isFalse);
      expect(store.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isTrue);
    });

    // =========================================================================
    // O5: PROTECCIÓN DE LA SEMILLA PRINCIPAL tasa_cambio_ves_usd
    // =========================================================================

    test('O5: tasa_cambio_ves_usd valida (> 1.0 y finita) se conserva intacta', () async {
      final store = TestSharedPreferences({
        AppConstants.prefTasaCambio: 42.5,
      });
      final count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);
      expect(count, equals(0));
      expect(store.getDouble(AppConstants.prefTasaCambio), equals(42.5));
      expect(store.disk[AppConstants.prefTasaCambio], equals(42.5));
    });

    test('O5: tasa_cambio_ves_usd invalida (0.0, negativa, no finita o tipo corrupto) se elimina', () async {
      // Caso 1: 0.0
      final storeZero = TestSharedPreferences({AppConstants.prefTasaCambio: 0.0});
      var count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: storeZero);
      expect(count, equals(1));
      expect(storeZero.disk.containsKey(AppConstants.prefTasaCambio), isFalse);

      // Caso 2: negativa (-5.0)
      final storeNeg = TestSharedPreferences({AppConstants.prefTasaCambio: -5.0});
      count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: storeNeg);
      expect(count, equals(1));
      expect(storeNeg.disk.containsKey(AppConstants.prefTasaCambio), isFalse);

      // Caso 3: no finita (NaN)
      final storeNan = TestSharedPreferences({AppConstants.prefTasaCambio: double.nan});
      count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: storeNan);
      expect(count, equals(1));
      expect(storeNan.disk.containsKey(AppConstants.prefTasaCambio), isFalse);

      // Caso 4: no finita (Infinity)
      final storeInf = TestSharedPreferences({AppConstants.prefTasaCambio: double.infinity});
      count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: storeInf);
      expect(count, equals(1));
      expect(storeInf.disk.containsKey(AppConstants.prefTasaCambio), isFalse);

      // Caso 5: tipo incorrecto (String)
      final storeStr = TestSharedPreferences({AppConstants.prefTasaCambio: 'cuarenta_y_dos'});
      count = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: storeStr);
      expect(count, equals(1));
      expect(storeStr.disk.containsKey(AppConstants.prefTasaCambio), isFalse);
    });

    test('O5: fallo al eliminar tasa_cambio_ves_usd impide fijar marca y reintento exitoso completa la purga', () async {
      final store = TestSharedPreferences({
        AppConstants.prefTasaCambio: -5.0, // Inválida
      });

      // Intento 1: fallo en remove
      store.returnFalseOnRemove = true;
      final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res1, equals(-1));
      expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);

      // Intento 2: reintento exitoso en el mismo proceso (sin reloadFromDisk)
      store.returnFalseOnRemove = false;
      final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
      expect(res2, equals(1));
      expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
      expect(store.disk.containsKey(AppConstants.prefTasaCambio), isFalse);
    });

    // =========================================================================
    // CASOS REMOTOS NO FINITOS (B4)
    // =========================================================================

    test('B4: getRateForDate descarta respuestas remotas con valores nulos o no finitos sin persistirlas', () async {
      // Caso 1: respuesta con null
      final clientNull = MockClient((request) async {
        return http.Response('[{"fecha":"2026-10-01","promedio":null}]', 200);
      });
      final store1 = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
      });

      final rateNull = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: clientNull,
        prefsInstance: store1,
      );
      expect(rateNull, equals(0.0));
      expect(store1.disk.containsKey('cached_rate_USD_2026-10-01'), isFalse);

      // Caso 2: respuesta con overflow 1e400 / no finito
      final clientInf = MockClient((request) async {
        return http.Response('[{"fecha":"2026-10-01","promedio":1e400}]', 200);
      });
      final store2 = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
      });

      final rateInf = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: clientInf,
        prefsInstance: store2,
      );
      expect(rateInf, equals(0.0));
      expect(store2.disk.containsKey('cached_rate_USD_2026-10-01'), isFalse);

      // Caso 3: respuesta con tipo String corrupto
      final clientStr = MockClient((request) async {
        return http.Response('[{"fecha":"2026-10-01","promedio":"cuarenta"}]', 200);
      });
      final store3 = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
      });

      final rateStr = await ExchangeRateService.getRateForDate(
        '2026-10-01',
        client: clientStr,
        prefsInstance: store3,
      );
      expect(rateStr, equals(0.0));
      expect(store3.disk.containsKey('cached_rate_USD_2026-10-01'), isFalse);
    });

    // =========================================================================
    // INTEGRACIÓN DE PUNTOS DE ENTRADA
    // =========================================================================

    test('Integracion: getAllTodayRates y getRateForDate ejecutan la purga antes de operar', () async {
      final store = TestSharedPreferences({
        'cached_rate_usdt': 0.0, // Inválida
        'cached_rate_usd': 55.0,
      });

      final failingClient = MockClient((_) async => http.Response('error', 500));

      final data = await ExchangeRateService.getAllTodayRates(
        client: failingClient,
        prefsInstance: store,
      );

      // La purga debió ejecutarse y fijar la marca
      expect(store.getBool(ExchangeRateService.prefKeyCacheHistoricaPurgada), isTrue);
      expect(store.data.containsKey('cached_rate_usdt'), isFalse);
      expect(data.usd, equals(55.0));
    });

    // =========================================================================
    // SEMÁNTICA DE SOURCE Y CAMPOS ALTERNATIVOS EN tasas_historico_v1
    // =========================================================================

    test('tasas_historico_v1: campos alternativos rate y fuente se seleccionan correctamente', () async {
      final store = TestSharedPreferences({
        'tasas_historico_v1': jsonEncode({
          // Caso 1: valor es 0 pero rate es 40.0 (válido)
          '2026-10-31': {'valor': 0, 'rate': 40.0, 'source': 'dolarapi'},
          // Caso 2: source es vacio pero fuente es 'oficial' (válido)
          '2026-10-30': {'valor': 41.0, 'source': '', 'fuente': 'oficial'},
          // Caso 3: promedio y fuente presentes
          '2026-10-29': {'promedio': 42.0, 'fuente': 'yadio'},
          // Caso 4: tasa valida pero sin ningun source o fuente -> purgado segun v1.2 §6.1
          '2026-10-28': {'valor': 43.0},
          // Caso 5: formato numerico plano (legacy) -> conservado
          '2026-10-27': 39.5,
        }),
      });

      final cleanedCount = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);
      expect(cleanedCount, equals(1)); // Solo se purga 2026-10-28

      final hist = jsonDecode(store.getString('tasas_historico_v1')!) as Map<String, dynamic>;
      expect(hist.containsKey('2026-10-31'), isTrue);
      expect(hist.containsKey('2026-10-30'), isTrue);
      expect(hist.containsKey('2026-10-29'), isTrue);
      expect(hist.containsKey('2026-10-27'), isTrue);
      expect(hist.containsKey('2026-10-28'), isFalse); // Sin procedencia -> purgado
    });

    // =========================================================================
    // PRUEBAS OBLIGATORIAS DE NEW-1 (RESILIENCIA DE PURGA Y REINTENTOS)
    // =========================================================================

    group('NEW-1: Resiliencia de purga, persistencia física y reintentos en el mismo proceso', () {
      test('Escenario A: setString falla en disk, memoria queda mutada, reintento sin reloadFromDisk persiste en disk y fija marca', () async {
        final initialJson = jsonEncode({
          '2026-10-31': {'valor': 40.0, 'source': 'dolarapi'}, // Válida
          '2026-10-30': {'valor': 0.5, 'source': 'dolarapi'},  // Inválida
        });
        final store = TestSharedPreferences({
          'tasas_historico_v1': initialJson,
        });

        // 1. Inicializar historial original en memory y disk
        expect(store.memory['tasas_historico_v1'], equals(initialJson));
        expect(store.disk['tasas_historico_v1'], equals(initialJson));

        // 2 & 3. Simular que setString muta memory y falla en plataforma/disk
        store.throwOnSetString = true;
        final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);

        // 4. Fallo: ensureCacheHistoricaPurgada retorna -1
        expect(res1, equals(-1));
        // Memoria contiene el JSON depurado
        expect(store.memory['tasas_historico_v1'], isNot(equals(initialJson)));
        // Disco aún conserva el JSON corrupto original
        expect(store.disk['tasas_historico_v1'], equals(initialJson));
        // La marca no está confirmada en disk
        expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
        // Operación registrada como pendiente
        expect(ExchangeRateService.pendingPurgeOperations.containsKey('tasas_historico_v1'), isTrue);

        // 5 & 6. Segundo intento en el MISMO PROCESO (sin reloadFromDisk) con fallo activo
        final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
        expect(res2, equals(-1));
        expect(store.disk['tasas_historico_v1'], equals(initialJson));
        expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
        expect(ExchangeRateService.pendingPurgeOperations.containsKey('tasas_historico_v1'), isTrue);

        // 7. Desactivar el fallo de persistencia
        store.throwOnSetString = false;

        // 8. Tercer intento en el mismo proceso (sin reloadFromDisk)
        final res3 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);

        // 9. Comprobar que el JSON depurado se persiste en disk
        expect(res3, greaterThanOrEqualTo(0));
        expect(store.disk['tasas_historico_v1'], isNot(equals(initialJson)));
        final cleanedDiskMap = jsonDecode(store.disk['tasas_historico_v1']! as String) as Map<String, dynamic>;
        expect(cleanedDiskMap.containsKey('2026-10-31'), isTrue);
        expect(cleanedDiskMap.containsKey('2026-10-30'), isFalse);

        // 10. Comprobar que la marca sí se persiste correctamente en disk
        expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
        expect(ExchangeRateService.pendingPurgeOperations.isEmpty, isTrue);
        expect(ExchangeRateService.isPurgeMarkPendingConfirmation, isFalse);
      });

      test('Escenario B: remove falla en disk, memoria muta, reintento sin reloadFromDisk repite eliminación física y marca no se fija antes', () async {
        final store = TestSharedPreferences({
          'cached_rate_USD_2026-02-30': 42.0, // Fecha inválida (febrero 30) -> clave corrupta
        });

        // 1. Clave en memory y disk
        expect(store.memory.containsKey('cached_rate_USD_2026-02-30'), isTrue);
        expect(store.disk.containsKey('cached_rate_USD_2026-02-30'), isTrue);

        // 2 & 3. Simular que remove muta memory pero falla en disk
        store.returnFalseOnRemove = true;
        final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);

        // Comprobaciones tras fallo:
        expect(res1, equals(-1));
        // En memoria ya no está
        expect(store.memory.containsKey('cached_rate_USD_2026-02-30'), isFalse);
        // 4. En disco aún permanece
        expect(store.disk.containsKey('cached_rate_USD_2026-02-30'), isTrue);
        // Marca no fijada en disco
        expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
        // Operación de remove pendiente
        expect(ExchangeRateService.pendingPurgeOperations.containsKey('cached_rate_USD_2026-02-30'), isTrue);

        // 5. Segundo intento en el mismo proceso (sin reloadFromDisk)
        store.returnFalseOnRemove = false; // Se recupera el almacenamiento
        final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);

        // 6 & 7. Eliminación física confirmada en disco y marca fijada
        expect(res2, greaterThanOrEqualTo(0));
        expect(store.disk.containsKey('cached_rate_USD_2026-02-30'), isFalse);
        expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
        expect(ExchangeRateService.pendingPurgeOperations.isEmpty, isTrue);
      });

      test('Escenario C: setBool falla en disk, memoria contiene true, reintento no sale anticipadamente y confirma en disk', () async {
        // 1. Datos limpios en disk (sin corrupción previa)
        final store = TestSharedPreferences({
          'cached_rate_usd': 90.0,
          'cached_rate_eur': 95.0,
        });

        // 2 & 3. Simular que setBool modifica memory pero falla en disk
        store.returnFalseOnSetBool = true;
        final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);

        // Comprobación de fallo
        expect(res1, equals(-1));
        // Memoria tiene true (por la mutación previa de SharedPreferences)
        expect(store.memory[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
        // 4. Disco NO tiene la marca confirmada
        expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
        // Estado pendiente de confirmación de marca
        expect(ExchangeRateService.isPurgeMarkPendingConfirmation, isTrue);

        // 5. Siguiente intento en el mismo proceso (sin reloadFromDisk)
        // 6. No debe retornar 0 por encontrar true en memoria; debe reintentar la persistencia física
        store.returnFalseOnSetBool = false; // Recuperación de plataforma
        final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);

        // 7 & 8. Persistencia de la marca confirmada en disco y limpieza de pendientes
        expect(res2, equals(0)); // 0 entradas corruptas que limpiar
        expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
        expect(ExchangeRateService.isPurgeMarkPendingConfirmation, isFalse);
        expect(ExchangeRateService.pendingPurgeOperations.isEmpty, isTrue);
      });

      test('Escenario D: Recuperación e idempotencia confirmadas: llamadas posteriores no repiten operaciones innecesarias', () async {
        final store = TestSharedPreferences({
          'cached_rate_usd': 100.0,
          'cached_rate_eur': 110.0,
          'cached_rate_usdt': 0.5, // 1 entrada corrupta
        });

        // Primera ejecución limpia y marca
        final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
        expect(res1, equals(1));
        expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
        expect(store.disk.containsKey('cached_rate_usdt'), isFalse);
        expect(store.disk['cached_rate_usd'], equals(100.0));
        expect(store.disk['cached_rate_eur'], equals(110.0));

        // Registro de operaciones ejecutadas
        final setStringCountBefore = store.setStringValues.length;
        final removedCountBefore = store.removedKeys.length;

        // Llamadas posteriores deben ser estrictamente idempotentes (retornan 0 de inmediato)
        final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
        expect(res2, equals(0));

        final res3 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
        expect(res3, equals(0));

        // No se repiten escrituras ni eliminaciones físicas en disco
        expect(store.setStringValues.length, equals(setStringCountBefore));
        expect(store.removedKeys.length, equals(removedCountBefore));
        expect(store.disk['cached_rate_usd'], equals(100.0));
        expect(store.disk['cached_rate_eur'], equals(110.0));
      });
    });

    // =========================================================================
    // B3-OBS: ROBUSTEZ DE TIPOS EN ExchangeRatesData.fromJson
    // =========================================================================

    group('B3-OBS: Deserialización defensiva y tipado seguro en ExchangeRatesData.fromJson', () {
      test('USD con tipos incorrectos y valores fuera de dominio degrada a 0.0 sin TypeError', () {
        // String
        expect(ExchangeRatesData.fromJson({'usd': '45.0'}).usd, equals(0.0));
        // Bool
        expect(ExchangeRatesData.fromJson({'usd': true}).usd, equals(0.0));
        // Map
        expect(ExchangeRatesData.fromJson({'usd': {'valor': 45.0}}).usd, equals(0.0));
        // List
        expect(ExchangeRatesData.fromJson({'usd': [45.0]}).usd, equals(0.0));
        // Fuera de dominio
        expect(ExchangeRatesData.fromJson({'usd': 0.5}).usd, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usd': 1.0}).usd, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usd': -5.0}).usd, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usd': double.nan}).usd, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usd': double.infinity}).usd, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usd': double.negativeInfinity}).usd, equals(0.0));
        // Válidos
        expect(ExchangeRatesData.fromJson({'usd': 45.0}).usd, equals(45.0));
        expect(ExchangeRatesData.fromJson({'usd': 380.0}).usd, equals(380.0));
      });

      test('EUR con tipos incorrectos y valores fuera de dominio degrada a 0.0 sin TypeError', () {
        // String
        expect(ExchangeRatesData.fromJson({'eur': '50.0'}).eur, equals(0.0));
        // Bool
        expect(ExchangeRatesData.fromJson({'eur': false}).eur, equals(0.0));
        // Map
        expect(ExchangeRatesData.fromJson({'eur': {'tasa': 50.0}}).eur, equals(0.0));
        // List
        expect(ExchangeRatesData.fromJson({'eur': [50.0]}).eur, equals(0.0));
        // Fuera de dominio
        expect(ExchangeRatesData.fromJson({'eur': 0.5}).eur, equals(0.0));
        expect(ExchangeRatesData.fromJson({'eur': 1.0}).eur, equals(0.0));
        expect(ExchangeRatesData.fromJson({'eur': -5.0}).eur, equals(0.0));
        expect(ExchangeRatesData.fromJson({'eur': double.nan}).eur, equals(0.0));
        expect(ExchangeRatesData.fromJson({'eur': double.infinity}).eur, equals(0.0));
        expect(ExchangeRatesData.fromJson({'eur': double.negativeInfinity}).eur, equals(0.0));
        // Válidos
        expect(ExchangeRatesData.fromJson({'eur': 49.0}).eur, equals(49.0));
        expect(ExchangeRatesData.fromJson({'eur': 410.0}).eur, equals(410.0));
      });

      test('USDT con tipos incorrectos y valores fuera de dominio degrada a 0.0 sin TypeError', () {
        // String
        expect(ExchangeRatesData.fromJson({'usdt': '46.0'}).usdt, equals(0.0));
        // Bool
        expect(ExchangeRatesData.fromJson({'usdt': true}).usdt, equals(0.0));
        // Map
        expect(ExchangeRatesData.fromJson({'usdt': {'rate': 46.0}}).usdt, equals(0.0));
        // List
        expect(ExchangeRatesData.fromJson({'usdt': [46.0]}).usdt, equals(0.0));
        // Fuera de dominio
        expect(ExchangeRatesData.fromJson({'usdt': 0.5}).usdt, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usdt': 1.0}).usdt, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usdt': -5.0}).usdt, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usdt': double.nan}).usdt, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usdt': double.infinity}).usdt, equals(0.0));
        expect(ExchangeRatesData.fromJson({'usdt': double.negativeInfinity}).usdt, equals(0.0));
        // Válidos
        expect(ExchangeRatesData.fromJson({'usdt': 46.5}).usdt, equals(46.5));
        expect(ExchangeRatesData.fromJson({'usdt': 395.0}).usdt, equals(395.0));
      });

      test('fecha y esReferencia con tipos incorrectos degradan a estados seguros sin TypeError', () {
        // fecha con tipo int, bool, Map, null
        final dIntFecha = ExchangeRatesData.fromJson({'fecha': 12345});
        expect(dIntFecha.fecha, isA<DateTime>());

        final dBoolFecha = ExchangeRatesData.fromJson({'fecha': true});
        expect(dBoolFecha.fecha, isA<DateTime>());

        final dMapFecha = ExchangeRatesData.fromJson({'fecha': {'d': '2026-10-31'}});
        expect(dMapFecha.fecha, isA<DateTime>());

        final dNullFecha = ExchangeRatesData.fromJson({});
        expect(dNullFecha.fecha, isA<DateTime>());

        // fecha válida en String
        final dStrFecha = ExchangeRatesData.fromJson({'fecha': '2026-10-31T12:00:00.000Z'});
        expect(dStrFecha.fecha.year, equals(2026));
        expect(dStrFecha.fecha.month, equals(10));
        expect(dStrFecha.fecha.day, equals(31));

        // esReferencia con tipo String, int, null, Map -> degrada a true
        expect(ExchangeRatesData.fromJson({'esReferencia': 'false'}).esReferencia, isTrue);
        expect(ExchangeRatesData.fromJson({'esReferencia': 0}).esReferencia, isTrue);
        expect(ExchangeRatesData.fromJson({'esReferencia': null}).esReferencia, isTrue);
        expect(ExchangeRatesData.fromJson({'esReferencia': {}}).esReferencia, isTrue);

        // M-02: fecha no interpretable o ausente degrada a epoch 0 y fuerza esReferencia: true
        final dNoFecha = ExchangeRatesData.fromJson({'esReferencia': false});
        expect(dNoFecha.fecha, equals(DateTime.fromMillisecondsSinceEpoch(0)));
        expect(dNoFecha.esReferencia, isTrue);

        final dFechaInvalida = ExchangeRatesData.fromJson({'fecha': 12345, 'esReferencia': false});
        expect(dFechaInvalida.fecha, equals(DateTime.fromMillisecondsSinceEpoch(0)));
        expect(dFechaInvalida.esReferencia, isTrue);

        // esReferencia legítimo bool se preserva si la fecha es válida
        final dValida = ExchangeRatesData.fromJson({'fecha': '2026-10-31T12:00:00.000Z', 'esReferencia': false});
        expect(dValida.esReferencia, isFalse);
        expect(ExchangeRatesData.fromJson({'fecha': '2026-10-31T12:00:00.000Z', 'esReferencia': true}).esReferencia, isTrue);
      });
    });

    // =========================================================================
    // NEW-6: METADATO cached_exchange_rates_timestamp
    // =========================================================================

    group('NEW-6: Manejo seguro y tipado de cached_exchange_rates_timestamp', () {
      test('getAllTodayRates no lanza TypeError cuando cached_exchange_rates_timestamp tiene tipo int o bool', () async {
        final store = TestSharedPreferences({
          ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
          'cached_rate_usd': 45.0,
          'cached_exchange_rates_timestamp': 123456789, // int corrupto
        });

        final failingClient = MockClient((_) async => http.Response('error', 500));
        final data = await ExchangeRateService.getAllTodayRates(client: failingClient, prefsInstance: store);

        expect(data.usd, equals(45.0));
        expect(data.esReferencia, isTrue);
      });

      test('purgarCacheHistoricaInvalida purga cached_exchange_rates_timestamp si no es String o fecha parseable', () async {
        final store = TestSharedPreferences({
          'cached_exchange_rates_timestamp': 99999, // int corrupto
          'cached_rate_usd': 50.0,
        });

        final cleanedCount = await ExchangeRateService.purgarCacheHistoricaInvalida(prefsInstance: store);
        expect(cleanedCount, greaterThanOrEqualTo(1));
        expect(store.disk.containsKey('cached_exchange_rates_timestamp'), isFalse);
      });
    });

    // =========================================================================
    // O2: COMPORTAMIENTO TIPADO Y FALLOS DEL FAKE TestSharedPreferences
    // =========================================================================

    group('O2: Fidelidad del Fake TestSharedPreferences', () {
      test('getString, getDouble y getBool lanzan TypeError ante tipos incompatibles', () {
        final store = TestSharedPreferences({
          'str_as_int': 123,
          'double_as_str': '45.0',
          'bool_as_int': 1,
        });

        expect(() => store.getString('str_as_int'), throwsA(isA<TypeError>()));
        expect(() => store.getDouble('double_as_str'), throwsA(isA<TypeError>()));
        expect(() => store.getBool('bool_as_int'), throwsA(isA<TypeError>()));
      });

      test('setDouble soporta inyeccion de fallos (throw y returnFalse)', () async {
        final store = TestSharedPreferences();
        store.throwOnSetDouble = true;
        expect(() => store.setDouble('rate', 45.0), throwsException);

        store.throwOnSetDouble = false;
        store.returnFalseOnSetDouble = true;
        final ok = await store.setDouble('rate', 45.0);
        expect(ok, isFalse);
      });

      test('remove muta memory antes del resultado de plataforma', () async {
        final store = TestSharedPreferences({'key': 'val'});
        store.returnFalseOnRemove = true;

        final res = await store.remove('key');
        expect(res, isFalse);
        // Memoria quedó mutada (eliminada)
        expect(store.memory.containsKey('key'), isFalse);
        // Disco aún conserva la clave
        expect(store.disk.containsKey('key'), isTrue);
      });
    });

    // =========================================================================
    // B-02: COMPROBACIÓN FÍSICA DE DISK TRAS REINTENTO DE OPERACIONES PENDIENTES
    // =========================================================================

    group('B-02: Comprobación estricta del estado físico de disk tras reintento de operaciones pendientes', () {
      test('Reintento con múltiples operaciones pendientes (setString y remove) confirma estado físico en disk y cleanedCount', () async {
        final initialHist = jsonEncode({
          '2026-10-31': {'valor': 45.0, 'source': 'dolarapi'},
          '2026-10-30': {'valor': 0.5, 'source': 'dolarapi'}, // Inválida -> setString
        });
        final store = TestSharedPreferences({
          'tasas_historico_v1': initialHist,
          'cached_rate_usdt': 0.5, // Inválida -> remove
          'cached_rate_usd': 45.0, // Válida -> conservar
        });

        // Simular fallo simultáneo en setString y remove
        store.throwOnSetString = true;
        store.returnFalseOnRemove = true;

        final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
        expect(res1, equals(-1));
        expect(store.disk.containsKey(ExchangeRateService.prefKeyCacheHistoricaPurgada), isFalse);
        expect(store.disk['tasas_historico_v1'], equals(initialHist));
        expect(store.disk['cached_rate_usdt'], equals(0.5));
        expect(ExchangeRateService.pendingPurgeOperations.length, equals(2));

        // Recuperación de plataforma
        store.throwOnSetString = false;
        store.returnFalseOnRemove = false;

        final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
        // Opción A: 1 entrada depurada en tasas_historico_v1 + 1 clave eliminada en cached_rate_usdt = 2
        expect(res2, equals(2));

        // Estado físico confirmado en disk:
        expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);
        expect(store.disk.containsKey('cached_rate_usdt'), isFalse);
        expect(store.disk['cached_rate_usd'], equals(45.0));
        final diskHist = jsonDecode(store.disk['tasas_historico_v1']! as String) as Map<String, dynamic>;
        expect(diskHist.containsKey('2026-10-31'), isTrue);
        expect(diskHist.containsKey('2026-10-30'), isFalse);

        // Operaciones pendientes y marcas completamente resueltas
        expect(ExchangeRateService.pendingPurgeOperations.isEmpty, isTrue);
        expect(ExchangeRateService.isPurgeMarkPendingConfirmation, isFalse);
      });
    });

    // =========================================================================
    // M-05: RESCISIÓN DE REMOVE PENDIENTE TRAS CONFIRMACIÓN DE ESCRITURA FRESCA
    // =========================================================================

    group('M-05: Rescisión de operación remove pendiente ante confirmación de tasa fresca', () {
      test('Tasa fresca obtenida y escrita en disco rescinde remove pendiente sobre la misma clave sin borrarla después', () async {
        final store = TestSharedPreferences({
          'cached_rate_usd': -5.0, // Tasa corrupta inicial
          'cached_rate_eur': 49.0, // Tasa válida
        });

        // 1. Purga intenta remover cached_rate_usd pero falla en plataforma
        store.returnFalseOnRemove = true;
        final res1 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
        expect(res1, equals(-1));
        expect(ExchangeRateService.pendingPurgeOperations.containsKey('cached_rate_usd'), isTrue);

        // 2. Plataforma se recupera para escrituras
        store.returnFalseOnRemove = false;

        // 3. Se obtiene cotización en vivo válida y se persiste exitosamente
        final liveClient = MockClient((request) async {
          return http.Response('{"usd": 60.0, "eur": 65.0, "usdt": 62.0}', 200);
        });
        final liveRates = await ExchangeRateService.getAllTodayRates(client: liveClient, prefsInstance: store);
        expect(liveRates.esReferencia, isFalse);
        expect(liveRates.usd, equals(60.0));

        // Comprobar que en disco y memoria cached_rate_usd tiene el nuevo valor 60.0
        expect(store.disk['cached_rate_usd'], equals(60.0));
        expect(store.getDouble('cached_rate_usd'), equals(60.0));

        // La operación remove pendiente para cached_rate_usd DEBE haber sido rescindida
        expect(ExchangeRateService.pendingPurgeOperations.containsKey('cached_rate_usd'), isFalse);

        // 4. Siguiente ejecución de purga: NO debe borrar cached_rate_usd
        final res2 = await ExchangeRateService.ensureCacheHistoricaPurgada(prefsInstance: store);
        expect(res2, equals(0)); // 0 operaciones pendientes restantes
        expect(store.disk[ExchangeRateService.prefKeyCacheHistoricaPurgada], isTrue);

        // La tasa fresca 60.0 se conserva intacta físicamente en disco y memoria
        expect(store.disk['cached_rate_usd'], equals(60.0));
        expect(store.getDouble('cached_rate_usd'), equals(60.0));

        // 5. Ante un fallo posterior de red, el fallback lee la tasa fresca 60.0 en vez de degradar a 0.0
        final failingClient = MockClient((_) async => http.Response('error', 500));
        final fallbackRates = await ExchangeRateService.getAllTodayRates(client: failingClient, prefsInstance: store);
        expect(fallbackRates.usd, equals(60.0));
        expect(fallbackRates.esReferencia, isTrue);
      });
    });
  });
}
