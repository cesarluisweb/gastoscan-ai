import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:gastoscan_ai/data/datasources/local/database_helper.dart';
import '../helpers/test_database_harness.dart';

void main() {
  group('Migracion SQLite v18 -> v19 (descripcion_norm e indice)', () {
    setUp(() {
      SqliteTestHarness.ensureFfiInitialized();
      DatabaseHelper.resetTestDatabase();
    });

    tearDown(() {
      DatabaseHelper.resetTestDatabase();
    });

    test('Migra base v18 con datos existentes, ejecuta backfill por lotes y crea idx_items_gasto_desc_norm', () async {
      final dbPath = 'file:migration_v18_to_v19_${DateTime.now().microsecondsSinceEpoch}?mode=memory&cache=shared';

      // 1. Crear base en v18 sin descripcion_norm ni indice nuevo
      final dbV18 = await databaseFactoryFfi.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: 18,
          singleInstance: false,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE gastos (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                uuid TEXT NOT NULL,
                fecha TEXT NOT NULL,
                comercio TEXT NOT NULL,
                moneda TEXT NOT NULL,
                total_original INTEGER NOT NULL,
                total_usd INTEGER NOT NULL,
                total_usdt INTEGER,
                total_eur INTEGER,
                tasa_cambio REAL DEFAULT 1.0,
                tasa_usdt REAL,
                tasa_eur REAL,
                fuente_tasa_cambio TEXT,
                fecha_tasa_cambio TEXT,
                categoria TEXT NOT NULL,
                ruta_foto_local TEXT,
                creado_en TEXT NOT NULL,
                actualizado_en TEXT,
                eliminado_en TEXT,
                items TEXT,
                firestore_id TEXT,
                synced INTEGER DEFAULT 0,
                ocr_text TEXT
              )
            ''');
            await db.execute('''
              CREATE TABLE items_gasto (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                gasto_id INTEGER NOT NULL,
                descripcion TEXT NOT NULL,
                cantidad REAL NOT NULL,
                precio_unitario INTEGER NOT NULL,
                total INTEGER NOT NULL,
                categoria TEXT DEFAULT 'Otros',
                FOREIGN KEY (gasto_id) REFERENCES gastos (id) ON DELETE CASCADE
              )
            ''');
          },
        ),
      );

      final gastoId = await dbV18.insert('gastos', {
        'uuid': 'uuid-v18-1',
        'fecha': '2026-11-01',
        'comercio': 'Farmatodo, C.A.',
        'moneda': 'USD',
        'total_original': 1000,
        'total_usd': 1000,
        'tasa_cambio': 45.0,
        'categoria': 'Alimentación',
        'creado_en': '2026-11-01T10:00:00',
      });

      await dbV18.insert('items_gasto', {
        'gasto_id': gastoId,
        'descripcion': 'Café Molido Gourmet (E)',
        'cantidad': 1.0,
        'precio_unitario': 500,
        'total': 500,
        'categoria': 'Alimentación',
      });
      await dbV18.insert('items_gasto', {
        'gasto_id': gastoId,
        'descripcion': 'Pañales Etapa 3!',
        'cantidad': 1.0,
        'precio_unitario': 400,
        'total': 400,
        'categoria': 'Higiene',
      });
      await dbV18.insert('items_gasto', {
        'gasto_id': gastoId,
        'descripcion': '---',
        'cantidad': 1.0,
        'precio_unitario': 100,
        'total': 100,
        'categoria': 'Otros',
      });

      // Abrir en v19 invocando openTestDatabase (que dispara _upgradeDB de 18 a 19)
      final dbV19 = await DatabaseHelper.openTestDatabase(
        factory: databaseFactoryFfi,
        path: dbPath,
      );

      final versionRes = await dbV19.rawQuery('PRAGMA user_version;');
      expect((versionRes.first['user_version'] as num?)?.toInt(), equals(19));

      // Verificar backfill de descripcion_norm
      final rows = await dbV19.query('items_gasto', orderBy: 'id ASC');
      expect(rows.length, equals(3));
      expect(rows[0]['descripcion_norm'], equals('cafe molido gourmet'));
      expect(rows[1]['descripcion_norm'], equals('panales etapa 3'));
      expect(rows[2]['descripcion_norm'], equals(''));

      // Verificar creacion del indice idx_items_gasto_desc_norm
      final idxRows = await dbV19.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_items_gasto_desc_norm';",
      );
      expect(idxRows, isNotEmpty);

      await dbV19.close();
      await dbV18.close();
    });
  });
}
