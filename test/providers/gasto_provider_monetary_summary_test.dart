import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/repositories/gasto_repository.dart';
import 'package:gastoscan_ai/providers/gasto_provider.dart';

class FakeMonetaryGastoRepository extends Fake implements GastoRepository {
  List<GastoModel> testGastos = [];

  @override
  Future<List<GastoModel>> obtenerGastosPorMes(int anio, int mes) async => testGastos;

  @override
  Future<Map<String, double>> obtenerTotalesMes(int anio, int mes) async => {
    'USD': 0.0,
    'VES': 0.0,
    'USDT': 0.0,
    'EUR': 0.0,
  };

  @override
  Future<Map<String, double>> obtenerTotalesPorCategoria(int anio, int mes, {String moneda = 'USD'}) async => {};

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

  @override
  Future<Map<String, int>?> obtenerUltimoMesConGastos() async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GastoProvider - Agregador Contable ResumenLenteMonetario (A-16)', () {
    late FakeMonetaryGastoRepository fakeRepo;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'pref_cache_historica_purgada_v18': true,
      });
      fakeRepo = FakeMonetaryGastoRepository();
    });

    test('calcula y expone ResumenLenteMonetario para las 4 lentes sin inventar equivalencias', () async {
      fakeRepo.testGastos = [
        // Gasto 1: en USD (10.00 USD, 1:1 en USDT)
        GastoModel(
          uuid: 'g1',
          fecha: '2026-10-10',
          comercio: 'Comercio 1',
          moneda: 'USD',
          totalOriginal: 1000,
          totalUsd: 1000,
          totalUsdt: 1000,
          tasaCambio: 800.0,
          categoria: 'Alimentación',
          creadoEn: '2026-10-10T12:00:00Z',
        ),
        // Gasto 2: en VES (Bs. 8.000 a tasa 800 -> 10.00 USD, sin USDT ni EUR registrados)
        GastoModel(
          uuid: 'g2',
          fecha: '2026-10-11',
          comercio: 'Comercio 2',
          moneda: 'VES',
          totalOriginal: 800000,
          totalUsd: 1000,
          tasaCambio: 800.0,
          categoria: 'Transporte',
          creadoEn: '2026-10-11T12:00:00Z',
        ),
      ];

      final provider = GastoProvider(repository: fakeRepo, autoLoad: false);
      await provider.cargarDatos();

      // Totales canónicos
      expect(provider.totalMesUsd, equals(20.0));
      expect(provider.totalMesVes, equals(16000.0));
      // USDT: solo gasto 1 tiene USDT (10.00). Gasto 2 queda pendiente (sin fallback a USD)
      expect(provider.totalMesUsdt, equals(10.0));
      // EUR: ninguno tiene EUR registrado
      expect(provider.totalMesEur, equals(0.0));

      // ResumenLenteMonetario expuesto
      final resumenUsdt = provider.getResumenLente('USDT');
      expect(resumenUsdt.totalMostradoDisplay, equals(10.0));
      expect(resumenUsdt.pendientesCount, equals(1));
      expect(resumenUsdt.tieneAdvertenciaCalidad, isTrue);

      final resumenEur = provider.getResumenLente('EUR');
      expect(resumenEur.totalMostradoDisplay, equals(0.0));
      expect(resumenEur.pendientesCount, equals(2));
      expect(resumenEur.tieneAdvertenciaCalidad, isTrue);

      final resumenVes = provider.getResumenLente('VES');
      expect(resumenVes.totalVerificadoOrigenDisplay, equals(8000.0));
      expect(resumenVes.totalNoVerificadoDisplay, equals(8000.0));
      expect(resumenVes.totalMostradoDisplay, equals(16000.0));
    });
  });
}
