import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import '../helpers/test_database_harness.dart';

void main() {
  group('DatabaseHelper.findPriceHistory y normalizacion v2', () {
    final harness = SqliteTestHarness();
    final refDate = DateTime(2026, 11, 13);

    setUp(() async {
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test('1. Normaliza nombres de comercio (minusculas, sin acentos, sin C.A., S.A., C.C. ni RIF)', () {
      expect(DatabaseHelper.normalizeCommerce('FARMATODO, C.A. J-00020200-1'), equals('farmatodo'));
      expect(DatabaseHelper.normalizeCommerce('Farmatodo C.C.'), equals('farmatodo'));
      expect(DatabaseHelper.normalizeCommerce("Automercados Plaza's, C.A."), equals('automercado plaza'));
      expect(DatabaseHelper.normalizeCommerce('Automercado Plaza'), equals('automercado plaza'));
      expect(DatabaseHelper.normalizeCommerce('Compra general'), equals(''));
      expect(DatabaseHelper.normalizeCommerce('Comercio no especificado'), equals(''));
    });

    test('2. Prioridad de comercio y mejor precio del mercado con multiples compras', () async {
      // Compra hace 20 dias en Gama: $2.20
      await harness.insertGastoFixture(
        uuid: 'g-1',
        fecha: '2026-10-24',
        comercio: 'Excelsior Gama, C.A.',
        moneda: 'USD',
        totalOriginal: 220,
        totalUsd: 220,
        items: [
          ItemGastoModel(
            descripcion: 'Harina PAN 1kg',
            cantidad: 1.0,
            precioUnitario: 220,
            total: 220,
            categoria: 'Alimentación',
          ),
        ],
      );

      // Compra hace 12 dias en Central Madeirense (mejor precio): $1.80
      await harness.insertGastoFixture(
        uuid: 'g-2',
        fecha: '2026-11-01',
        comercio: 'Central Madeirense C.C.',
        moneda: 'USD',
        totalOriginal: 180,
        totalUsd: 180,
        items: [
          ItemGastoModel(
            descripcion: 'Harina Pan 1kg (E)',
            cantidad: 1.0,
            precioUnitario: 180,
            total: 180,
            categoria: 'Alimentación',
          ),
        ],
      );

      // Compra hace 5 dias en Farmatodo (mismo comercio mas reciente): $2.50
      await harness.insertGastoFixture(
        uuid: 'g-3',
        fecha: '2026-11-08',
        comercio: 'FARMATODO, C.A.',
        moneda: 'USD',
        totalOriginal: 250,
        totalUsd: 250,
        items: [
          ItemGastoModel(
            descripcion: 'HARINA PAN 1KG',
            cantidad: 1.0,
            precioUnitario: 250,
            total: 250,
            categoria: 'Alimentación',
          ),
        ],
      );

      final result = await DatabaseHelper.instance.findPriceHistory(
        ['Harina PAN 1kg'],
        comercioActual: 'Farmatodo C.C.',
        referenceDate: refDate,
      );

      final history = result['harina pan 1kg'];
      expect(history, isNotNull);
      expect(history!.registros, equals(3));
      expect(history.mismoComercio, isNotNull);
      expect(history.mismoComercio!.precioUsd, closeTo(2.50, 0.001));
      expect(history.mismoComercio!.fecha, equals('2026-11-08'));
      expect(history.mejorPrecio, isNotNull);
      expect(history.mejorPrecio!.precioUsd, closeTo(1.80, 0.001));
      expect(history.mejorPrecio!.comercioNorm, equals('central madeirense'));
    });

    test('3. Ventana temporal 30, 31, 60 y 61 dias', () async {
      // 30 dias antes de 2026-11-13 -> 2026-10-14
      await harness.insertGastoFixture(
        uuid: 'w-30',
        fecha: '2026-10-14',
        comercio: 'Tienda A',
        items: [
          ItemGastoModel(descripcion: 'Producto 30d', cantidad: 1, precioUnitario: 100, total: 100),
        ],
      );
      // 31 dias antes -> 2026-10-13
      await harness.insertGastoFixture(
        uuid: 'w-31',
        fecha: '2026-10-13',
        comercio: 'Tienda B',
        items: [
          ItemGastoModel(descripcion: 'Producto 31d', cantidad: 1, precioUnitario: 110, total: 110),
        ],
      );
      // 60 dias antes -> 2026-09-14
      await harness.insertGastoFixture(
        uuid: 'w-60',
        fecha: '2026-09-14',
        comercio: 'Tienda C',
        items: [
          ItemGastoModel(descripcion: 'Producto 60d', cantidad: 1, precioUnitario: 120, total: 120),
        ],
      );
      // 61 dias antes -> 2026-09-13 (fuera de ventana de 60 dias)
      await harness.insertGastoFixture(
        uuid: 'w-61',
        fecha: '2026-09-13',
        comercio: 'Tienda D',
        items: [
          ItemGastoModel(descripcion: 'Producto 61d', cantidad: 1, precioUnitario: 130, total: 130),
        ],
      );

      final map = await DatabaseHelper.instance.findPriceHistory(
        ['Producto 30d', 'Producto 31d', 'Producto 60d', 'Producto 61d'],
        referenceDate: refDate,
      );

      expect(map.containsKey('producto 30d'), isTrue);
      expect(map.containsKey('producto 31d'), isTrue);
      expect(map.containsKey('producto 60d'), isTrue);
      expect(map.containsKey('producto 61d'), isFalse);
    });

    test('4. Exclusion del gasto actual (excludeGastoId)', () async {
      final idPrevio = await harness.insertGastoFixture(
        uuid: 'prev-1',
        fecha: '2026-11-05',
        comercio: 'Panaderia A',
        items: [
          ItemGastoModel(descripcion: 'Queso Blanco', cantidad: 1, precioUnitario: 400, total: 400),
        ],
      );
      final idActual = await harness.insertGastoFixture(
        uuid: 'curr-1',
        fecha: '2026-11-12',
        comercio: 'Panaderia B',
        items: [
          ItemGastoModel(descripcion: 'Queso Blanco', cantidad: 1, precioUnitario: 600, total: 600),
        ],
      );

      final res = await DatabaseHelper.instance.findPriceHistory(
        ['Queso Blanco'],
        excludeGastoId: idActual,
        referenceDate: refDate,
      );

      final hist = res['queso blanco'];
      expect(hist, isNotNull);
      expect(hist!.registros, equals(1));
      expect(hist.mejorPrecio!.gastoId, equals(idPrevio));
      expect(hist.mejorPrecio!.precioUsd, closeTo(4.00, 0.001));
    });

    test('5. Conversion VES -> USD y calculo por unidad ante cantidades distintas', () async {
      // Gasto en VES con tasa 50.0: 3 unidades por Bs. 300.00 (total = 30000 centavos)
      // Precio unitario en VES = Bs. 100.00 -> en USD = $2.00/ud
      await harness.insertGastoFixture(
        uuid: 'ves-qty',
        fecha: '2026-11-10',
        comercio: 'Abasto El Sol',
        moneda: 'VES',
        totalOriginal: 30000,
        totalUsd: 600,
        tasaCambio: 50.0,
        items: [
          ItemGastoModel(
            descripcion: 'Mantequilla 500g',
            cantidad: 3.0,
            precioUnitario: 10000,
            total: 30000,
          ),
        ],
      );

      final res = await DatabaseHelper.instance.findPriceHistory(
        ['Mantequilla 500g'],
        referenceDate: refDate,
      );

      final hist = res['mantequilla 500g'];
      expect(hist, isNotNull);
      expect(hist!.mejorPrecio!.precioUsd, closeTo(2.00, 0.001));
      expect(hist.mejorPrecio!.cantidad, equals(3.0));
    });

    test('6. Ignora items de impuestos y descripciones vacias o muy cortas', () async {
      await harness.insertGastoFixture(
        uuid: 'tax-short',
        fecha: '2026-11-10',
        comercio: 'Farmatodo',
        items: [
          ItemGastoModel(descripcion: 'Impuesto IVA', cantidad: 1, precioUnitario: 160, total: 160),
          ItemGastoModel(descripcion: 'IVA 16%', cantidad: 1, precioUnitario: 160, total: 160),
          ItemGastoModel(descripcion: 'AB', cantidad: 1, precioUnitario: 100, total: 100),
          ItemGastoModel(descripcion: '   ', cantidad: 1, precioUnitario: 100, total: 100),
        ],
      );

      final res = await DatabaseHelper.instance.findPriceHistory(
        ['Impuesto IVA', 'IVA 16%', 'AB', ''],
        referenceDate: refDate,
      );

      expect(res, isEmpty);
    });
  });
}
