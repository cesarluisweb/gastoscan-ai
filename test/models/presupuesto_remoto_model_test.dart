import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/models/presupuesto_remoto_model.dart';

void main() {
  group('PresupuestoRemotoModel Tests', () {
    test('fromFirestore correctly parses and normalizes categories with positive values', () {
      final docData = {
        'anio': 2026,
        'mes': 10,
        'presupuesto_general': 350.0,
        'meta_ahorro': 50.0,
        'moneda': 'USD',
        'actualizado_en': '2026-10-26T12:00:00.000Z',
        'categorias': {
          'comida': 150.0, // Should normalize to 'Comida'
          'Transporte': 60,
          'Servicios': 0.0, // Zero should be excluded
          'Salud': -10.0, // Negative should be excluded
          'Invalido': 'not-a-number', // Non-number should be excluded
        },
      };

      final model = PresupuestoRemotoModel.fromFirestore(docData, '2026_10');

      expect(model.anio, equals(2026));
      expect(model.mes, equals(10));
      expect(model.general, equals(350.0));
      expect(model.metaAhorro, equals(50.0));
      expect(model.moneda, equals('USD'));
      expect(model.actualizadoEn, equals('2026-10-26T12:00:00.000Z'));

      expect(model.categorias.containsKey('Alimentación'), isTrue);
      expect(model.categorias['Alimentación'], equals(150.0));
      expect(model.categorias['Transporte'], equals(60.0));
      expect(model.categorias.containsKey('Servicios'), isFalse);
      expect(model.categorias.containsKey('Salud'), isFalse);
    });

    test('fromFirestore uses fallback timestamp when actualizado_en is missing', () {
      final docDataWithCreado = {
        'anio': 2026,
        'mes': 9,
        'presupuesto_general': 200.0,
        'creado_en': '2026-09-01T08:00:00.000Z',
      };

      final model1 = PresupuestoRemotoModel.fromFirestore(docDataWithCreado, '2026_9');
      expect(model1.actualizadoEn, equals('2026-09-01T08:00:00.000Z'));

      final docDataEmpty = {
        'anio': 2026,
        'mes': 8,
      };

      final model2 = PresupuestoRemotoModel.fromFirestore(docDataEmpty, '2026_8');
      expect(model2.actualizadoEn, equals(DateTime.fromMillisecondsSinceEpoch(0).toIso8601String()));
    });
  });
}
