import 'package:flutter_test/flutter_test.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';
import '../helpers/test_database_harness.dart';

void main() {
  group('E0-01: Arnes de pruebas SQLite en memoria (sqflite_common_ffi)', () {
    final harness = SqliteTestHarness();

    setUp(() async {
      await harness.setUp();
    });

    tearDown(() async {
      await harness.tearDown();
    });

    test('1. Abre base SQLite en memoria con esquema v18 y la cierra limpiamente', () async {
      // 1.1 Estado inicial abierto
      expect(harness.isOpen, isTrue);
      expect(DatabaseHelper.testDatabase, isNotNull);

      // 1.2 Version de esquema en PRAGMA de SQLite real
      final versionResult = await harness.db.rawQuery('PRAGMA user_version;');
      final userVersion = (versionResult.first['user_version'] as num?)?.toInt();
      expect(userVersion, equals(18));

      // 1.3 Verificacion de integridad referencial activada
      final fkResult = await harness.db.rawQuery('PRAGMA foreign_keys;');
      final foreignKeysEnabled = (fkResult.first['foreign_keys'] as num?)?.toInt();
      expect(foreignKeysEnabled, equals(1));

      // 1.4 Verificacion de tablas creadas en sqlite_master
      final tablesResult = await harness.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%';",
      );
      final tableNames = tablesResult.map((r) => r['name'] as String).toSet();

      expect(tableNames, contains('gastos'));
      expect(tableNames, contains('items_gasto'));
      expect(tableNames, contains('shopping_items'));
      expect(tableNames, contains('scan_queue'));
      expect(tableNames, contains('categorias'));
      expect(tableNames, contains('presupuestos_mensuales'));
      expect(tableNames, contains('presupuestos_categorias_mensuales'));

      // 1.5 Verificacion de indices principales creados en sqlite_master
      final indicesResult = await harness.db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name NOT LIKE 'sqlite_%';",
      );
      final indexNames = indicesResult.map((r) => r['name'] as String).toSet();
      expect(indexNames, contains('idx_gastos_fecha'));
      expect(indexNames, contains('idx_gastos_categoria'));
      expect(indexNames, contains('idx_items_gasto_gasto_id'));
      expect(indexNames, contains('idx_scan_queue_status'));
      expect(indexNames, contains('idx_scan_queue_image_hash'));
      expect(indexNames, contains('idx_gastos_synced'));
    });

    test('2. Aislamiento estricto: la base arranca completamente vacia en cada prueba', () async {
      // Al iniciar este test, el setUp() anterior cerro la base previa y creo una nueva
      expect(await harness.countRows('gastos'), equals(0));
      expect(await harness.countRows('items_gasto'), equals(0));
      expect(await harness.countRows('categorias'), equals(0));

      // Mutamos insertando datos
      await harness.insertGastoFixture(
        uuid: 'isolation-uuid-1',
        comercio: 'Comercio Aislado',
      );
      await harness.insertCategoriaFixture(nombre: 'Categoria Aislada');

      expect(await harness.countRows('gastos'), equals(1));
      expect(await harness.countRows('categorias'), equals(1));
    });

    test('3. Aislamiento comprobado: no existen residuos de pruebas anteriores', () async {
      // Debe volver a estar en 0 sin rastro de 'isolation-uuid-1'
      expect(await harness.countRows('gastos'), equals(0));
      expect(await harness.countRows('categorias'), equals(0));

      final gastos = await harness.getTableRows('gastos');
      expect(gastos, isEmpty);
    });

    test('4. Operaciones reales: insercion atomica y borrado en cascada con FK reales', () async {
      final item1 = ItemGastoModel(
        descripcion: 'Leche Descremada',
        cantidad: 2.0,
        precioUnitario: 150,
        total: 300,
        categoria: 'Alimentos',
      );
      final item2 = ItemGastoModel(
        descripcion: 'Pan Canilla',
        cantidad: 1.0,
        precioUnitario: 100,
        total: 100,
        categoria: 'Alimentos',
      );

      final gasto = GastoModel(
        uuid: 'uuid-fk-cascade',
        fecha: '2026-10-31',
        comercio: 'Panaderia Real',
        moneda: 'USD',
        totalOriginal: 400,
        totalUsd: 400,
        tasaCambio: 40.0,
        categoria: 'Alimentos',
        creadoEn: DateTime.now().toIso8601String(),
        synced: 0,
      );

      // Insercion mediante DatabaseHelper.instance (utiliza la base SQLite real en memoria)
      final gastoId = await DatabaseHelper.instance.insertGasto(gasto, [item1, item2]);
      expect(gastoId, isPositive);

      // Comprobar que en SQLite existen el gasto y sus 2 items
      expect(await harness.countRows('gastos'), equals(1));
      expect(await harness.countRows('items_gasto'), equals(2));

      final itemsRows = await harness.db.query('items_gasto', where: 'gasto_id = ?', whereArgs: [gastoId]);
      expect(itemsRows.length, equals(2));

      // Borrado directo del gasto en SQLite: PRAGMA foreign_keys debe eliminar los items en cascada
      final deletedCount = await harness.db.delete('gastos', where: 'id = ?', whereArgs: [gastoId]);
      expect(deletedCount, equals(1));

      // Verificar que los items desaparecieron automaticamente por FK cascade
      final itemsHuerfanos = await harness.db.query('items_gasto', where: 'gasto_id = ?', whereArgs: [gastoId]);
      expect(itemsHuerfanos, isEmpty);
      expect(await harness.countRows('items_gasto'), equals(0));
    });

    test('5. Fixtures y cleanAllTables preserva estructura sin residuos', () async {
      await harness.insertGastoFixture(uuid: 'gasto-1');
      await harness.insertGastoFixture(uuid: 'gasto-2');
      await harness.insertCategoriaFixture(nombre: 'Salud', presupuestoMensual: 50.0);
      await harness.insertPresupuestoMensualFixture(anio: 2026, mes: 10, presupuestoGeneral: 200.0);

      expect(await harness.countRows('gastos'), equals(2));
      expect(await harness.countRows('categorias'), equals(1));
      expect(await harness.countRows('presupuestos_mensuales'), equals(1));

      // Limpieza de todas las tablas
      await harness.cleanAllTables();

      expect(await harness.countRows('gastos'), equals(0));
      expect(await harness.countRows('categorias'), equals(0));
      expect(await harness.countRows('presupuestos_mensuales'), equals(0));

      // Las tablas continuan operativas tras cleanAllTables
      await harness.insertCategoriaFixture(nombre: 'Hogar');
      expect(await harness.countRows('categorias'), equals(1));
    });

    test('6. Runner withIsolatedSqlite proporciona aislamiento autocontenido', () async {
      await withIsolatedSqlite((runnerHarness) async {
        expect(runnerHarness.isOpen, isTrue);
        await runnerHarness.insertGastoFixture(uuid: 'isolated-runner-uuid');
        expect(await runnerHarness.countRows('gastos'), equals(1));
      });

      // La base del runner fue destruida; la base de este test sigue intacta y aislada
      expect(await harness.countRows('gastos'), equals(0));
    });

    test('7. Compatibilidad E0-05a sobre SQLite real: dryRun = true previene escrituras', () async {
      // Insertar gasto en USD con tasa_cambio <= 1.0 (incompleta)
      final id = await harness.insertGastoFixture(
        uuid: 'gasto-tasa-incompleta',
        moneda: 'USD',
        tasaCambio: 1.0,
      );

      // Ejecutar reparacion en modo dryRun = true por defecto
      final identificados = await DatabaseHelper.instance.repararTasasHistoricasIncompletas(
        tasaFallback: 40.0,
        dryRun: true,
      );
      expect(identificados, equals(1));

      // Verificar en SQLite real que la tasa NO fue modificada
      final filasPostDryRun = await harness.db.query('gastos', where: 'id = ?', whereArgs: [id]);
      expect(filasPostDryRun.first['tasa_cambio'], equals(1.0));

      // Ejecutar reparacion con dryRun = false explicito
      final actualizados = await DatabaseHelper.instance.repararTasasHistoricasIncompletas(
        tasaFallback: 40.0,
        dryRun: false,
      );
      expect(actualizados, equals(1));

      // Verificar en SQLite real que ahora SI fue actualizada a 40.0
      final filasPostMutacion = await harness.db.query('gastos', where: 'id = ?', whereArgs: [id]);
      expect(filasPostMutacion.first['tasa_cambio'], equals(40.0));
    });
  });
}
