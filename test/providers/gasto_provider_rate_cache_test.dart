import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/core/constants/app_constants.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';
import 'package:gastoscan_ai/services/exchange_rate_service.dart';
import '../services/exchange_rate_service_cache_purge_test.dart';

class FakeGastoRepositoryForProvider extends Fake implements GastoRepository {
  bool obtenerGastosCalled = false;

  @override
  Future<List<GastoModel>> obtenerGastosPorMes(int anio, int mes) async {
    obtenerGastosCalled = true;
    return [];
  }

  @override
  Future<Map<String, double>> obtenerTotalesMes(int anio, int mes) async => {
    'USD': 100.0,
    'VES': 4000.0,
    'USDT': 100.0,
    'EUR': 0.0,
  };

  @override
  Future<Map<String, double>> obtenerTotalesPorCategoria(int anio, int mes, {String moneda = 'USD'}) async {
    if (moneda == 'VES') return {'Alimentos': 4000.0};
    return {'Alimentos': 100.0};
  }

  @override
  Future<double> obtenerPresupuestoGeneralMes(int anio, int mes) async => 0.0;

  @override
  Future<double> obtenerMetaAhorroMes(int anio, int mes) async => 0.0;

  @override
  Future<String> obtenerMonedaPresupuestoGeneralMes(int anio, int mes) async => 'USD';

  @override
  Future<Map<String, double>> obtenerPresupuestosCategoriasMes(int anio, int mes) async => {};

  @override
  Future<Map<String, dynamic>?> obtenerUltimoPresupuestoConfigurado({
    int? antesDeAnio,
    int? antesDeMes,
    bool estrictamenteAnterior = false,
  }) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GastoProvider - Protecciones B2 de Caché de Tasas y Dominio Numérico', () {
    late FakeGastoRepositoryForProvider fakeRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ExchangeRateService.resetPendingPurgeOperationsForTesting();
      fakeRepo = FakeGastoRepositoryForProvider();
    });

    tearDown(() {
      ExchangeRateService.resetPendingPurgeOperationsForTesting();
    });

    test('Escenario 13: Purga fallida (-1) en GastoProvider -> no consume cache local no verificada', () async {
      // Store donde la purga falla (remove retorna false al purgar una clave corrupta)
      final failingStore = TestSharedPreferences({
        'cached_rate_usdt': 0.0, // Provoca purga y fallo
        'cached_rate_usd': 88.0, // Tasa local que no debe consumirse
        'cached_rate_eur': 95.0,
        AppConstants.prefTasaCambio: 88.0,
      });
      failingStore.returnFalseOnRemove = true;

      final provider = GastoProvider(repository: fakeRepo, autoLoad: false);
      provider.prefsInstance = failingStore;
      await provider.cargarDatos();

      // Los datos generales de gastos se cargan a pesar de la omisión de caché
      expect(fakeRepo.obtenerGastosCalled, isTrue);

      // Verificamos getSpentForCategory: al omitir la tasa EUR no verificada (95.0),
      // effEur permanece en 0.0 y el cálculo recurre a los totales en USD (100.0)
      // en vez de aplicar 4000.0 / 95.0 = 42.105...
      expect(provider.errorMessage, isNull);
      expect(provider.getSpentForCategory('Alimentos', moneda: 'EUR'), equals(100.0));
    });

    test('Escenario 14: GastoProvider no asigna Infinity proveniente de cache local', () async {
      final storeWithInfinity = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_usd': double.infinity,
        'cached_rate_eur': double.infinity,
        AppConstants.prefTasaCambio: double.infinity,
      });

      final provider = GastoProvider(repository: fakeRepo, autoLoad: false);
      provider.prefsInstance = storeWithInfinity;
      await provider.cargarDatos();

      // Intentar calcular gasto para categoría con EUR: al descartarse Infinity,
      // effEur permanece en 0.0 y devuelve el monto base USD (100.0), nunca 0.0 ni NaN
      final spent = provider.getSpentForCategory('Alimentos', moneda: 'EUR');
      expect(spent.isFinite, isTrue);
      expect(spent, equals(100.0));
    });

    test('setTasasReferencia rechaza Infinity, NaN, 0.5, 1.0 y valores negativos', () async {
      final provider = GastoProvider(repository: fakeRepo, autoLoad: false);

      // Intentar pasar Infinity
      provider.setTasasReferencia(tasaUsd: double.infinity, tasaEur: double.infinity);
      // Intentar pasar NaN
      provider.setTasasReferencia(tasaUsd: double.nan, tasaEur: double.nan);
      // Intentar pasar 0.5 o 1.0
      provider.setTasasReferencia(tasaUsd: 0.5, tasaEur: 1.0);
      // Intentar pasar negativo
      provider.setTasasReferencia(tasaUsd: -10.0, tasaEur: -5.0);

      // Fijar tasas de prueba en fakeRepo
      fakeRepo = FakeGastoRepositoryForProvider();

      // Pasar tasa válida > 1.0
      provider.setTasasReferencia(tasaUsd: 45.0, tasaEur: 50.0);

      // Con effEur = 50.0 y 4000.0 VES: 4000 / 50 = 80.0
      provider.prefsInstance = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
      });
      await provider.cargarDatos();
      provider.setTasasReferencia(tasaUsd: 45.0, tasaEur: 50.0);

      final spent = provider.getSpentForCategory('Alimentos', moneda: 'EUR');
      expect(spent.isFinite, isTrue);
      expect(spent, equals(80.0));
    });

    test('Purga exitosa en GastoProvider consume tasas locales validas (> 1.0 y finitas)', () async {
      final validStore = TestSharedPreferences({
        ExchangeRateService.prefKeyCacheHistoricaPurgada: true,
        'cached_rate_usd': 52.0,
        'cached_rate_eur': 50.0,
      });

      final provider = GastoProvider(repository: fakeRepo, autoLoad: false);
      provider.prefsInstance = validStore;
      await provider.cargarDatos();

      expect(fakeRepo.obtenerGastosCalled, isTrue);
      expect(provider.errorMessage, isNull);

      // 4000.0 VES / 50.0 EUR = 80.0 EUR
      final spent = provider.getSpentForCategory('Alimentos', moneda: 'EUR');
      expect(spent, equals(80.0));
    });
  });
}
