import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/domain/monetary/resumen_lente_monetario.dart';

void main() {
  group('ResumenLenteMonetario (T-68 y Agregación Contable v1.2)', () {
    GastoModel createGasto({
      required String uuid,
      required String moneda,
      required int totalOriginal,
      int totalUsd = 0,
      int? totalUsdt,
      int? totalEur,
      double tasaCambio = 40.0,
      double? tasaEur,
      double? tasaUsdt,
    }) {
      return GastoModel(
        uuid: uuid,
        fecha: '2026-10-31',
        comercio: 'Comercio $uuid',
        moneda: moneda,
        totalOriginal: totalOriginal,
        totalUsd: totalUsd,
        totalUsdt: totalUsdt,
        totalEur: totalEur,
        tasaCambio: tasaCambio,
        tasaEur: tasaEur,
        tasaUsdt: tasaUsdt,
        categoria: 'Alimentación',
        creadoEn: '2026-10-31T10:00:00Z',
      );
    }

    test('T-68: Separación contable estricta en lente USD', () {
      final gastos = [
        // Gasto 1: USD directo (identidadOrigen)
        createGasto(
          uuid: 'g1',
          moneda: 'USD',
          totalOriginal: 1000, // 10.00 USD
          totalUsd: 1000,
        ),
        // Gasto 2: VES con total_usd registrado (persistidoNoVerificado)
        createGasto(
          uuid: 'g2',
          moneda: 'VES',
          totalOriginal: 20000, // 200.00 Bs.
          totalUsd: 500,        // 5.00 USD
        ),
        // Gasto 3: VES sin total_usd (pendiente, totalUsd <= 0)
        createGasto(
          uuid: 'g3',
          moneda: 'VES',
          totalOriginal: 12000,
          totalUsd: 0,
        ),
      ];

      final resumen = ResumenLenteMonetario.calcular(
        monedaLente: 'USD',
        gastos: gastos,
      );

      expect(resumen.monedaLente, equals('USD'));
      expect(resumen.totalVerificadoOrigenCentavos, equals(1000));
      expect(resumen.totalNoVerificadoCentavos, equals(500));
      expect(resumen.totalMostradoCentavos, equals(1500));
      expect(resumen.totalVerificadoOrigenDisplay, equals(10.00));
      expect(resumen.totalNoVerificadoDisplay, equals(5.00));
      expect(resumen.totalMostradoDisplay, equals(15.00));
      expect(resumen.noVerificadosCount, equals(1));
      expect(resumen.pendientesCount, equals(1));
      expect(resumen.incoherentesCount, equals(0));
      expect(resumen.tieneAdvertenciaCalidad, isTrue);
    });

    test('Agregación limpia sin advertencias cuando todos los gastos están verificados', () {
      final gastos = [
        createGasto(uuid: 'g1', moneda: 'USD', totalOriginal: 1500, totalUsd: 1500),
        createGasto(uuid: 'g2', moneda: 'USD', totalOriginal: 2500, totalUsd: 2500),
      ];

      final resumen = ResumenLenteMonetario.calcular(
        monedaLente: 'USD',
        gastos: gastos,
      );

      expect(resumen.totalVerificadoOrigenCentavos, equals(4000));
      expect(resumen.totalNoVerificadoCentavos, equals(0));
      expect(resumen.totalMostradoCentavos, equals(4000));
      expect(resumen.noVerificadosCount, equals(0));
      expect(resumen.pendientesCount, equals(0));
      expect(resumen.incoherentesCount, equals(0));
      expect(resumen.tieneAdvertenciaCalidad, isFalse);
    });
  });
}
