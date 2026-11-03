import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/domain/monetary/monetary_resolution.dart';

void main() {
  group('resolvePersistedExpense (T-67 e Invariantes v1.2)', () {
    GastoModel buildGasto({
      String moneda = 'USD',
      int totalOriginal = 2000, // 20.00
      int totalUsd = 2000,
      int? totalUsdt,
      int? totalEur,
      double tasaCambio = 40.0,
      double? tasaUsdt = 50.0,
      double? tasaEur = 44.0,
      String? fuenteTasaCambio = 'Gateway',
    }) {
      return GastoModel(
        uuid: 'test-uuid-1',
        fecha: '2026-10-31',
        comercio: 'Comercio Test',
        moneda: moneda,
        totalOriginal: totalOriginal,
        totalUsd: totalUsd,
        totalUsdt: totalUsdt,
        totalEur: totalEur,
        tasaCambio: tasaCambio,
        tasaUsdt: tasaUsdt,
        tasaEur: tasaEur,
        fuenteTasaCambio: fuenteTasaCambio,
        categoria: 'Alimentación',
        creadoEn: '2026-10-31T10:00:00Z',
      );
    }

    group('T-67: No derivación en lectura USD/EUR/USDT y cálculo no verificado en VES', () {
      test('a) Fila USD con total_eur: null leída en lente EUR -> pendiente (no deriva)', () {
        final gasto = buildGasto(
          moneda: 'USD',
          totalOriginal: 2000,
          totalUsd: 2000,
          totalEur: null,
          tasaCambio: 40.0,
          tasaEur: 44.0,
        );

        final res = resolvePersistedExpense(gasto: gasto, lente: 'EUR');
        expect(res.estado, equals(EstadoValorMonetario.pendiente));
        expect(res.centavos, isNull);
      });

      test('b) Misma fila USD leída en lente VES -> calculadoNoVerificado (2000 * 40.0 = 80000)', () {
        final gasto = buildGasto(
          moneda: 'USD',
          totalOriginal: 2000,
          totalUsd: 2000,
          totalEur: null,
          tasaCambio: 40.0,
          tasaEur: 44.0,
        );

        final res = resolvePersistedExpense(gasto: gasto, lente: 'VES');
        expect(res.estado, equals(EstadoValorMonetario.calculadoNoVerificado));
        expect(res.centavos, equals(80000));
        expect(res.esContabilizableNoVerificado, isTrue);
        expect(res.esVerificado, isFalse);
      });

      test('c) Fila EUR con tasa_eur == tasa_cambio (ambigua) leída en lente VES -> pendiente', () {
        final gasto = buildGasto(
          moneda: 'EUR',
          totalOriginal: 2000,
          totalUsd: 2200,
          totalEur: 2000,
          tasaCambio: 40.0,
          tasaEur: 40.0, // Colisión idéntica a tasaCambio
        );

        final res = resolvePersistedExpense(gasto: gasto, lente: 'VES');
        expect(res.estado, equals(EstadoValorMonetario.pendiente));
        expect(res.centavos, isNull);
      });
    });

    test('Identidad de origen cuando la lente coincide con la moneda original', () {
      final gastoUsd = buildGasto(moneda: 'USD', totalOriginal: 1500);
      final resUsd = resolvePersistedExpense(gasto: gastoUsd, lente: 'USD');
      expect(resUsd.estado, equals(EstadoValorMonetario.identidadOrigen));
      expect(resUsd.centavos, equals(1500));
      expect(resUsd.esVerificado, isTrue);

      final gastoVes = buildGasto(moneda: 'VES', totalOriginal: 60000, totalUsd: 1500);
      final resVes = resolvePersistedExpense(gasto: gastoVes, lente: 'VES');
      expect(resVes.estado, equals(EstadoValorMonetario.identidadOrigen));
      expect(resVes.centavos, equals(60000));
      expect(resVes.esVerificado, isTrue);
    });

    test('Invariante I6: Detecta colapso en VES cuando total_secundario == total_original', () {
      // Si total_usd == total_original en gasto con moneda VES, es colapso I6
      final gastoColapsadoUsd = buildGasto(
        moneda: 'VES',
        totalOriginal: 5000,
        totalUsd: 5000,
      );
      final resUsd = resolvePersistedExpense(gasto: gastoColapsadoUsd, lente: 'USD');
      expect(resUsd.estado, equals(EstadoValorMonetario.incoherente));
      expect(resUsd.centavos, isNull);

      final gastoColapsadoEur = buildGasto(
        moneda: 'VES',
        totalOriginal: 5000,
        totalUsd: 125,
        totalEur: 5000,
      );
      final resEur = resolvePersistedExpense(gasto: gastoColapsadoEur, lente: 'EUR');
      expect(resEur.estado, equals(EstadoValorMonetario.incoherente));
      expect(resEur.centavos, isNull);

      final gastoColapsadoUsdt = buildGasto(
        moneda: 'VES',
        totalOriginal: 5000,
        totalUsd: 125,
        totalUsdt: 5000,
      );
      final resUsdt = resolvePersistedExpense(gasto: gastoColapsadoUsdt, lente: 'USDT');
      expect(resUsdt.estado, equals(EstadoValorMonetario.incoherente));
      expect(resUsdt.centavos, isNull);
    });

    test('Invariante I5: Detecta copia ilegítima EUR == USD cuando tasas difieren', () {
      final gastoI5 = buildGasto(
        moneda: 'VES',
        totalOriginal: 40000,
        totalUsd: 1000,
        totalEur: 1000, // Copiado de total_usd
        tasaCambio: 40.0,
        tasaEur: 44.0,  // Tasas distintas
      );
      final resEur = resolvePersistedExpense(gasto: gastoI5, lente: 'EUR');
      expect(resEur.estado, equals(EstadoValorMonetario.incoherente));
      expect(resEur.centavos, isNull);
    });

    test('Manejo seguro de monto 0 y montos negativos', () {
      final gastoCero = buildGasto(totalOriginal: 0, totalUsd: 0);
      final resCero = resolvePersistedExpense(gasto: gastoCero, lente: 'USD');
      expect(resCero.estado, equals(EstadoValorMonetario.identidadOrigen));
      expect(resCero.centavos, equals(0));

      final gastoNegativo = buildGasto(totalOriginal: -500);
      final resNegativo = resolvePersistedExpense(gasto: gastoNegativo, lente: 'USD');
      expect(resNegativo.estado, equals(EstadoValorMonetario.incoherente));
      expect(resNegativo.centavos, isNull);
    });

    group('H-1: Eliminación de fallback de tasa USDT en lente VES', () {
      test('Gasto USDT con tasa_usdt nula y tasa_cambio presente devuelve pendiente en lente VES', () {
        final gastoUsdtSinTasa = buildGasto(
          moneda: 'USDT',
          totalOriginal: 2000,
          totalUsd: 2000,
          totalUsdt: 2000,
          tasaCambio: 40.0,
          tasaUsdt: null, // Ausente
        );

        final res = resolvePersistedExpense(gasto: gastoUsdtSinTasa, lente: 'VES');
        expect(res.estado, equals(EstadoValorMonetario.pendiente));
        expect(res.centavos, isNull);
        expect(res.motivoNoDisponible, contains('Tasa origen ausente'));
      });
    });

    group('H-2: Preservación real de null a través de GastoModel.fromMap y toMap', () {
      test('1. Gasto USD con total_usd presente y total_usdt nulo devuelve pendiente en lente USDT', () {
        final rawMap = <String, dynamic>{
          'uuid': 'gasto-usd-sin-usdt',
          'fecha': '2026-10-31',
          'comercio': 'Automercado',
          'moneda': 'USD',
          'total_original': 1500,
          'total_usd': 1500,
          'total_usdt': null, // ausente en SQLite
          'tasa_cambio': 40.0,
          'categoria': 'Alimentos',
        };

        final gasto = GastoModel.fromMap(rawMap);
        expect(gasto.totalUsdt, isNull, reason: 'fromMap no debe fabricar totalUsdt a partir de totalUsd');

        final res = resolvePersistedExpense(gasto: gasto, lente: 'USDT');
        expect(res.estado, equals(EstadoValorMonetario.pendiente));
        expect(res.centavos, isNull);
      });

      test('2. Gasto USDT con tasa_usdt nula y tasa_cambio presente devuelve pendiente en lente VES', () {
        final rawMap = <String, dynamic>{
          'uuid': 'gasto-usdt-sin-tasa',
          'fecha': '2026-10-31',
          'comercio': 'P2P Trade',
          'moneda': 'USDT',
          'total_original': 2500,
          'total_usd': 2500,
          'total_usdt': 2500,
          'tasa_cambio': 40.0,
          'tasa_usdt': null, // ausente en SQLite
          'categoria': 'Otros',
        };

        final gasto = GastoModel.fromMap(rawMap);
        expect(gasto.tasaUsdt, isNull, reason: 'fromMap no debe fabricar tasaUsdt a partir de tasaCambio');

        final res = resolvePersistedExpense(gasto: gasto, lente: 'VES');
        expect(res.estado, equals(EstadoValorMonetario.pendiente));
        expect(res.centavos, isNull);
      });

      test('3. toMap y fromMap en ciclo completo preservan fielmente null sin fabricar valores', () {
        final rawMap = <String, dynamic>{
          'uuid': 'gasto-ciclo-nulls',
          'fecha': '2026-10-31',
          'comercio': 'Tienda',
          'moneda': 'USD',
          'total_original': 3000,
          'total_usd': 3000,
          'total_usdt': null,
          'total_eur': null,
          'tasa_cambio': 40.0,
          'tasa_usdt': null,
          'tasa_eur': null,
          'categoria': 'Hogar',
        };

        final gasto = GastoModel.fromMap(rawMap);
        expect(gasto.totalUsdt, isNull);
        expect(gasto.tasaUsdt, isNull);
        expect(gasto.totalEur, isNull);
        expect(gasto.tasaEur, isNull);

        final serializado = gasto.toMap();
        expect(serializado['total_usdt'], isNull);
        expect(serializado['tasa_usdt'], isNull);
        expect(serializado['total_eur'], isNull);
        expect(serializado['tasa_eur'], isNull);

        final reconstruido = GastoModel.fromMap(serializado);
        expect(reconstruido.totalUsdt, isNull);
        expect(reconstruido.tasaUsdt, isNull);
        expect(reconstruido.totalEur, isNull);
        expect(reconstruido.tasaEur, isNull);
      });
    });
  });
}
