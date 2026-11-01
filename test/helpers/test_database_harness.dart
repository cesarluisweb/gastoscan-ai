import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import 'package:gastoscan_ai/data/models/gasto_model.dart';
import 'package:gastoscan_ai/data/models/item_gasto_model.dart';

/// Arnés de pruebas reutilizable basado en SQLite real en memoria (sqflite_common_ffi)
/// para operaciones de persistencia, aislamiento y consultas de Rinde Más.
class SqliteTestHarness {
  Database? _db;
  static bool _ffiInitialized = false;

  /// Retorna la instancia activa de Database en memoria.
  Database get db {
    if (_db == null || !_db!.isOpen) {
      throw StateError(
        'La base de datos SQLite en memoria no esta inicializada o ya fue cerrada. '
        'Asegurate de invocar await harness.setUp() en el test.',
      );
    }
    return _db!;
  }

  /// Retorna la instancia de DatabaseHelper configurada con la base en memoria.
  DatabaseHelper get dbHelper => DatabaseHelper.instance;

  /// Indica si la base de datos en memoria esta abierta y lista para operar.
  bool get isOpen => _db != null && _db!.isOpen;

  /// Inicializa FFI una unica vez para todo el proceso de pruebas.
  static void ensureFfiInitialized() {
    if (!_ffiInitialized) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _ffiInitialized = true;
    }
  }

  /// Inicializa una conexion SQLite aislada en memoria con el esquema oficial v18.
  Future<Database> setUp() async {
    ensureFfiInitialized();

    // Cierre defensivo de conexiones previas en DatabaseHelper
    await dbHelper.close();
    DatabaseHelper.resetTestDatabase();

    // Apertura de base de datos fresca en memoria
    _db = await DatabaseHelper.openTestDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    return _db!;
  }

  /// Cierra la conexion SQLite en memoria y restablece el estado de DatabaseHelper.
  Future<void> tearDown() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
    DatabaseHelper.resetTestDatabase();
  }

  /// Limpia todas las filas de las tablas sin alterar la definicion del esquema.
  Future<void> cleanAllTables() async {
    final d = db;
    await d.transaction((txn) async {
      await txn.delete('items_gasto');
      await txn.delete('shopping_items');
      await txn.delete('scan_queue');
      await txn.delete('presupuestos_categorias_mensuales');
      await txn.delete('presupuestos_mensuales');
      await txn.delete('categorias');
      await txn.delete('gastos');
      try {
        await txn.delete('gastos_fts');
      } catch (_) {
        // Fallback si la tabla virtual FTS5 no fue instanciada
      }
    });
  }

  /// Fixture: Inserta un gasto valido con items opcionales directamente en SQLite real.
  Future<int> insertGastoFixture({
    String? uuid,
    String fecha = '2026-10-31',
    String comercio = 'Automercado Plaza',
    String moneda = 'USD',
    int totalOriginal = 2500,
    int totalUsd = 2500,
    int? totalUsdt = 2500,
    int? totalEur,
    double tasaCambio = 40.0,
    double? tasaUsdt = 40.0,
    double? tasaEur,
    String? fuenteTasaCambio = 'Gateway',
    String? fechaTasaCambio = '2026-10-31',
    String categoria = 'Alimentos',
    String? rutaFotoLocal,
    String? creadoEn,
    String? actualizadoEn,
    String? eliminadoEn,
    int synced = 0,
    String? ocrText,
    List<ItemGastoModel> items = const [],
  }) async {
    final nowIso = DateTime.now().toIso8601String();
    final gasto = GastoModel(
      uuid: uuid ?? 'uuid-${DateTime.now().microsecondsSinceEpoch}',
      fecha: fecha,
      comercio: comercio,
      moneda: moneda,
      totalOriginal: totalOriginal,
      totalUsd: totalUsd,
      totalUsdt: totalUsdt,
      totalEur: totalEur,
      tasaCambio: tasaCambio,
      tasaUsdt: tasaUsdt,
      tasaEur: tasaEur,
      fuenteTasaCambio: fuenteTasaCambio,
      fechaTasaCambio: fechaTasaCambio,
      categoria: categoria,
      rutaFotoLocal: rutaFotoLocal,
      creadoEn: creadoEn ?? nowIso,
      actualizadoEn: actualizadoEn,
      eliminadoEn: eliminadoEn,
      synced: synced,
      ocrText: ocrText,
      items: items,
    );
    return await dbHelper.insertGasto(gasto, items);
  }

  /// Fixture: Inserta una categoria en la tabla categorias.
  Future<int> insertCategoriaFixture({
    required String nombre,
    double presupuestoMensual = 0.0,
  }) async {
    return await db.insert('categorias', {
      'nombre': nombre,
      'presupuesto_mensual': presupuestoMensual,
    });
  }

  /// Fixture: Inserta un presupuesto mensual general.
  Future<int> insertPresupuestoMensualFixture({
    required int anio,
    required int mes,
    double presupuestoGeneral = 0.0,
    double metaAhorro = 0.0,
    String moneda = 'USD',
    String? actualizadoEn,
  }) async {
    return await db.insert('presupuestos_mensuales', {
      'anio': anio,
      'mes': mes,
      'presupuesto_general': presupuestoGeneral,
      'meta_ahorro': metaAhorro,
      'moneda': moneda,
      'actualizado_en': actualizadoEn,
    });
  }

  /// Cuenta las filas existentes en una tabla mediante SELECT COUNT(*).
  Future<int> countRows(String tableName) async {
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  /// Retorna todas las filas de una tabla como mapas crudos.
  Future<List<Map<String, Object?>>> getTableRows(String tableName) async {
    return await db.query(tableName);
  }
}

/// Ejecuta un cuerpo de prueba determinista garantizando aislamiento SQLite completo.
Future<T> withIsolatedSqlite<T>(Future<T> Function(SqliteTestHarness harness) testBody) async {
  final harness = SqliteTestHarness();
  await harness.setUp();
  try {
    return await testBody(harness);
  } finally {
    await harness.tearDown();
  }
}
