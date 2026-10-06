import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/gasto_model.dart';
import '../../models/item_gasto_model.dart';
import '../../models/shopping_item_model.dart';
import '../../models/categoria_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();
  DatabaseHelper.test();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('gastoscan.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 15,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE gastos ADD COLUMN firestore_id TEXT');
      await db.execute('ALTER TABLE gastos ADD COLUMN synced INTEGER DEFAULT 0');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE shopping_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          is_purchased INTEGER DEFAULT 0,
          gasto_id INTEGER,
          created_at TEXT NOT NULL,
          FOREIGN KEY (gasto_id) REFERENCES gastos (id) ON DELETE SET NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE scan_queue (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          image_path TEXT NOT NULL,
          status TEXT NOT NULL,
          extracted_data TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      // El campo items faltaba en las migraciones previas
      try {
        await db.execute('ALTER TABLE gastos ADD COLUMN items TEXT');
      } catch (e) {
        // Puede que ya exista si el usuario instaló desde cero en v4
      }
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS categorias (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT NOT NULL UNIQUE,
          presupuesto_mensual REAL NOT NULL DEFAULT 0.0
        )
      ''');
      try {
        await db.execute('ALTER TABLE categorias ADD COLUMN presupuesto_mensual REAL NOT NULL DEFAULT 0.0');
      } catch (e) {
        // La columna ya existe si se creó recién
      }
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE gastos ADD COLUMN items TEXT');
      } catch (e) {
        // La columna ya existe si el usuario actualizó desde v4
      }
    }
    if (oldVersion < 8) {
      try {
        await db.execute("ALTER TABLE items_gasto ADD COLUMN categoria TEXT DEFAULT 'Otros'");
      } catch (e) {
        // La columna ya existe
      }
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE gastos ADD COLUMN uuid TEXT');
      await db.execute('ALTER TABLE gastos ADD COLUMN actualizado_en TEXT');
      await db.execute('ALTER TABLE gastos ADD COLUMN eliminado_en TEXT');
      await db.execute('ALTER TABLE gastos ADD COLUMN tasa_cambio REAL DEFAULT 1.0');
      await db.execute('ALTER TABLE gastos ADD COLUMN fuente_tasa_cambio TEXT');
      await db.execute('ALTER TABLE gastos ADD COLUMN fecha_tasa_cambio TEXT');

      await db.execute("UPDATE gastos SET uuid = lower(hex(randomblob(16))) WHERE uuid IS NULL OR uuid = ''");

      await db.execute('UPDATE gastos SET total_original = CAST(ROUND(total_original * 100) AS INTEGER)');
      await db.execute('UPDATE gastos SET total_usd = CAST(ROUND(total_usd * 100) AS INTEGER)');
      await db.execute('UPDATE items_gasto SET precio_unitario = CAST(ROUND(precio_unitario * 100) AS INTEGER)');
      await db.execute('UPDATE items_gasto SET total = CAST(ROUND(total * 100) AS INTEGER)');
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS presupuestos_mensuales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          anio INTEGER NOT NULL,
          mes INTEGER NOT NULL,
          presupuesto_general REAL NOT NULL DEFAULT 0.0,
          UNIQUE(anio, mes)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS presupuestos_categorias_mensuales (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          anio INTEGER NOT NULL,
          mes INTEGER NOT NULL,
          categoria TEXT NOT NULL,
          presupuesto REAL NOT NULL DEFAULT 0.0,
          UNIQUE(anio, mes, categoria)
        )
      ''');
      try {
        final now = DateTime.now();
        final anio = now.year;
        final mes = now.month;
        final cats = await db.query('categorias', where: 'presupuesto_mensual > 0');
        for (final row in cats) {
          final catName = row['nombre'] as String;
          final budget = (row['presupuesto_mensual'] as num?)?.toDouble() ?? 0.0;
          if (budget > 0) {
            await db.insert('presupuestos_categorias_mensuales', {
              'anio': anio,
              'mes': mes,
              'categoria': catName,
              'presupuesto': budget,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      } catch (e) {
        // Ignorar si falla migración inicial
      }
    }
    if (oldVersion < 11) {
      try {
        await db.execute("ALTER TABLE presupuestos_mensuales ADD COLUMN moneda TEXT DEFAULT 'USD'");
      } catch (e) {
        // Ignorar si ya existe
      }
      try {
        await db.execute("ALTER TABLE presupuestos_categorias_mensuales ADD COLUMN moneda TEXT DEFAULT 'USD'");
      } catch (e) {
        // Ignorar si ya existe
      }
    }
    if (oldVersion < 12) {
      try {
        await db.execute("ALTER TABLE presupuestos_mensuales ADD COLUMN actualizado_en TEXT");
      } catch (e) {
        // Ignorar si ya existe
      }
    }
    if (oldVersion < 13) {
      try {
        await db.execute("ALTER TABLE presupuestos_mensuales ADD COLUMN meta_ahorro REAL NOT NULL DEFAULT 0.0");
      } catch (e) {
        // Ignorar si ya existe
      }
    }
    if (oldVersion < 14) {
      try {
        await db.execute("ALTER TABLE scan_queue ADD COLUMN ocr_text TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE scan_queue ADD COLUMN attempt_count INTEGER DEFAULT 0");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE scan_queue ADD COLUMN last_error TEXT");
      } catch (_) {}
      try {
        await db.execute("ALTER TABLE gastos ADD COLUMN ocr_text TEXT");
      } catch (_) {}
      try {
        await db.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS gastos_fts USING fts5(
            gasto_id UNINDEXED,
            comercio,
            ocr_text,
            tokenize = 'unicode61 remove_diacritics 2'
          )
        ''');
      } catch (_) {
        // Invariante: FTS5 es optimización de búsqueda, nunca bloquea la ejecución en dispositivos sin FTS5
      }
    }
    if (oldVersion < 15) {
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_items_gasto_gasto_id ON items_gasto (gasto_id);');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_scan_queue_status ON scan_queue (status);');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_gastos_synced ON gastos (synced);');
      } catch (_) {}
    }
  }

  Future<void> _onConfigure(Database db) async {
    // Activa la integridad referencial para borrado en cascada
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _createDB(Database db, int version) async {
    // Tabla gastos
    await db.execute('''
      CREATE TABLE gastos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT NOT NULL,
        fecha TEXT NOT NULL,
        comercio TEXT NOT NULL,
        moneda TEXT NOT NULL,
        total_original INTEGER NOT NULL,
        total_usd INTEGER NOT NULL,
        tasa_cambio REAL DEFAULT 1.0,
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

    // Tabla items_gasto
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

    // Tabla shopping_items
    await db.execute('''
      CREATE TABLE shopping_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        is_purchased INTEGER DEFAULT 0,
        gasto_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (gasto_id) REFERENCES gastos (id) ON DELETE SET NULL
      )
    ''');

    // Tabla scan_queue
    await db.execute('''
      CREATE TABLE scan_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_path TEXT NOT NULL,
        status TEXT NOT NULL,
        extracted_data TEXT,
        ocr_text TEXT,
        attempt_count INTEGER DEFAULT 0,
        last_error TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Tabla categorias
    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL UNIQUE,
        presupuesto_mensual REAL NOT NULL DEFAULT 0.0
      )
    ''');

    // Tabla presupuestos_mensuales
    await db.execute('''
      CREATE TABLE presupuestos_mensuales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        anio INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        presupuesto_general REAL NOT NULL DEFAULT 0.0,
        meta_ahorro REAL NOT NULL DEFAULT 0.0,
        moneda TEXT DEFAULT 'USD',
        actualizado_en TEXT,
        UNIQUE(anio, mes)
      )
    ''');

    // Tabla presupuestos_categorias_mensuales
    await db.execute('''
      CREATE TABLE presupuestos_categorias_mensuales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        anio INTEGER NOT NULL,
        mes INTEGER NOT NULL,
        categoria TEXT NOT NULL,
        presupuesto REAL NOT NULL DEFAULT 0.0,
        moneda TEXT DEFAULT 'USD',
        UNIQUE(anio, mes, categoria)
      )
    ''');

    // Índices para búsquedas y filtros rápidos por fecha, categoría, ítems y sincronización
    await db.execute('CREATE INDEX idx_gastos_fecha ON gastos (fecha);');
    await db.execute('CREATE INDEX idx_gastos_categoria ON gastos (categoria);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_items_gasto_gasto_id ON items_gasto (gasto_id);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_scan_queue_status ON scan_queue (status);');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_gastos_synced ON gastos (synced);');

    // Tabla virtual FTS5 independiente para búsqueda profunda
    try {
      await db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS gastos_fts USING fts5(
          gasto_id UNINDEXED,
          comercio,
          ocr_text,
          tokenize = 'unicode61 remove_diacritics 2'
        )
      ''');
    } catch (_) {
      // Invariante: Fallback seguro si FTS5 no está disponible
    }
  }

  /// Inserta un gasto con sus ítems asociados de forma atómica en una transacción
  Future<int> insertGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    final db = await instance.database;
    final gastoId = await db.transaction((txn) async {
      final id = await txn.insert('gastos', gasto.toMap());
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['gasto_id'] = id;
        await txn.insert('items_gasto', itemMap);
      }
      return id;
    });

    if (gasto.ocrText != null && gasto.ocrText!.trim().isNotEmpty) {
      await syncGastoFts(gastoId, gasto.comercio, gasto.ocrText);
    }
    return gastoId;
  }

  /// Actualiza un gasto y reemplaza sus ítems en una transacción
  Future<void> updateGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    final db = await instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'gastos',
        gasto.toMap(),
        where: 'id = ?',
        whereArgs: [gasto.id],
      );

      // Elimina los ítems anteriores y reinserta los actualizados
      await txn.delete('items_gasto', where: 'gasto_id = ?', whereArgs: [gasto.id]);
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['gasto_id'] = gasto.id;
        await txn.insert('items_gasto', itemMap);
      }
    });

    if (gasto.id != null) {
      if (gasto.ocrText != null && gasto.ocrText!.trim().isNotEmpty) {
        await syncGastoFts(gasto.id!, gasto.comercio, gasto.ocrText);
      } else {
        await deleteGastoFts(gasto.id!);
      }
    }
  }

  /// Marca un gasto como eliminado lógicamente y no sincronizado sin recargar toda la base de datos
  Future<int> softDeleteGasto(int id) async {
    final db = await instance.database;
    final nowIso = DateTime.now().toIso8601String();
    final count = await db.update(
      'gastos',
      {
        'eliminado_en': nowIso,
        'synced': 0,
        'actualizado_en': nowIso,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await deleteGastoFts(id);
    return count;
  }

  /// Elimina un gasto. Los ítems se eliminan automáticamente gracias a ON DELETE CASCADE
  Future<int> deleteGasto(int id) async {
    final db = await instance.database;
    final count = await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
    await deleteGastoFts(id);
    return count;
  }

  /// Hidrata una lista de filas de gastos con sus ítems en lotes para evitar consultas N+1
  Future<List<GastoModel>> _hydrateGastosWithItems(Database db, List<Map<String, dynamic>> gastosRows) async {
    if (gastosRows.isEmpty) return [];

    final gastoIds = gastosRows.map((m) => m['id'] as int).toList();
    final Map<int, List<ItemGastoModel>> itemsMap = {};

    for (var i = 0; i < gastoIds.length; i += 500) {
      final chunk = gastoIds.sublist(i, (i + 500 > gastoIds.length) ? gastoIds.length : i + 500);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final itemsResult = await db.query(
        'items_gasto',
        where: 'gasto_id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final itemMap in itemsResult) {
        final gId = itemMap['gasto_id'] as int;
        final item = ItemGastoModel.fromMap(itemMap);
        itemsMap.putIfAbsent(gId, () => []).add(item);
      }
    }

    return gastosRows.map((map) {
      final gId = map['id'] as int;
      final items = itemsMap[gId] ?? [];
      return GastoModel.fromMap(map, items: items);
    }).toList();
  }

  /// Obtiene todos los gastos ordenados de más reciente a más antiguo (sin borrados lógicos)
  Future<List<GastoModel>> getAllGastos() async {
    final db = await instance.database;
    final result = await db.query(
      'gastos', 
      where: 'eliminado_en IS NULL',
      orderBy: 'fecha DESC, id DESC'
    );
    return _hydrateGastosWithItems(db, result);
  }

  /// Obtiene TODOS los gastos, incluyendo los borrados lógicos, para resolver conflictos de sincronización
  Future<List<GastoModel>> getAllGastosConBorrados() async {
    final db = await instance.database;
    final result = await db.query('gastos');
    return _hydrateGastosWithItems(db, result);
  }

  Future<List<GastoModel>> getUnsyncedGastos() async {
    final db = await instance.database;
    final result = await db.query(
      'gastos',
      where: 'synced = 0 OR synced IS NULL',
    );
    return _hydrateGastosWithItems(db, result);
  }

  Future<void> updateGastoSyncStatus(GastoModel gasto) async {
    final db = await instance.database;
    await db.update(
      'gastos',
      {'firestore_id': gasto.firestoreId, 'synced': gasto.synced},
      where: 'id = ?',
      whereArgs: [gasto.id],
    );
  }

  /// Obtiene los gastos de un mes y año específicos
  Future<List<GastoModel>> getGastosByMonth(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final result = await db.query(
      'gastos',
      where: 'fecha LIKE ? AND eliminado_en IS NULL',
      whereArgs: [pattern],
      orderBy: 'fecha DESC, id DESC',
    );
    return _hydrateGastosWithItems(db, result);
  }

  /// Calcula los totales del mes (suma en USD y suma en VES)
  /// Calcula los totales del mes (suma en USD y suma en VES) de forma determinista y consistente.
  Future<Map<String, double>> getMonthlyTotals(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final rows = await db.query(
      'gastos',
      columns: ['moneda', 'total_original', 'total_usd', 'tasa_cambio'],
      where: 'fecha LIKE ? AND eliminado_en IS NULL',
      whereArgs: [pattern],
    );

    double sumUsd = 0.0;
    double sumVes = 0.0;

    for (final r in rows) {
      final moneda = (r['moneda'] as String?) ?? 'VES';
      final totalOrigInt = (r['total_original'] as num?)?.toInt() ?? 0;
      final totalUsdInt = (r['total_usd'] as num?)?.toInt() ?? 0;
      final tasa = (r['tasa_cambio'] as num?)?.toDouble() ?? 1.0;

      final double totalOrig = totalOrigInt / 100.0;
      final double totalUsd = totalUsdInt / 100.0;

      sumUsd += totalUsd;

      if (moneda == 'VES') {
        sumVes += totalOrig;
      } else {
        sumVes += (totalUsd * (tasa > 0 ? tasa : 1.0));
      }
    }

    return {
      'USD': sumUsd,
      'VES': sumVes,
    };
  }

  /// Calcula el desglose de gastos agrupado por categoría para el mes.
  /// Si [moneda] es 'VES', devuelve los montos en Bolívares respetando el valor original o tasa fija del día de compra.
  /// Si es 'USD', devuelve los montos en Dólares.
  Future<Map<String, double>> getCategoryTotals(int year, int month, {String moneda = 'USD'}) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final gastosRows = await db.query(
      'gastos',
      columns: ['id', 'moneda', 'total_original', 'total_usd', 'tasa_cambio', 'categoria'],
      where: 'fecha LIKE ? AND eliminado_en IS NULL',
      whereArgs: [pattern],
    );

    if (gastosRows.isEmpty) {
      return {};
    }

    final gastoIds = gastosRows.map((g) => g['id'] as int).toList();
    final Map<int, List<Map<String, dynamic>>> itemsMap = {};
    for (var i = 0; i < gastoIds.length; i += 500) {
      final chunk = gastoIds.sublist(i, (i + 500 > gastoIds.length) ? gastoIds.length : i + 500);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final itemsResult = await db.query(
        'items_gasto',
        columns: ['gasto_id', 'categoria', 'total'],
        where: 'gasto_id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in itemsResult) {
        final gId = row['gasto_id'] as int;
        itemsMap.putIfAbsent(gId, () => []).add(row);
      }
    }

    final Map<String, double> categoryMap = {};

    for (final g in gastosRows) {
      final gastoId = g['id'] as int;
      final gastoMoneda = (g['moneda'] as String?) ?? 'VES';
      final totalOrig = ((g['total_original'] as num?)?.toInt() ?? 0) / 100.0;
      final totalUsd = ((g['total_usd'] as num?)?.toInt() ?? 0) / 100.0;
      final tasa = (g['tasa_cambio'] as num?)?.toDouble() ?? 1.0;
      final gastoCat = (g['categoria'] as String?) ?? 'Otros';

      final double targetTotal = (moneda == 'VES')
          ? (gastoMoneda == 'VES' ? totalOrig : totalUsd * (tasa > 0 ? tasa : 1.0))
          : totalUsd;

      final items = itemsMap[gastoId] ?? const [];

      if (items.isEmpty) {
        categoryMap[gastoCat] = (categoryMap[gastoCat] ?? 0.0) + targetTotal;
      } else {
        double sumItems = 0.0;
        for (final item in items) {
          sumItems += ((item['total'] as num?)?.toInt() ?? 0) / 100.0;
        }

        for (final item in items) {
          final cat = (item['categoria'] as String?) ?? gastoCat;
          final itemTotal = ((item['total'] as num?)?.toInt() ?? 0) / 100.0;
          final ratio = sumItems > 0 ? (itemTotal / sumItems) : (1.0 / items.length);
          final allocated = ratio * targetTotal;
          categoryMap[cat] = (categoryMap[cat] ?? 0.0) + allocated;
        }
      }
    }

    return categoryMap;
  }

  static String normalizeProductText(String text) {
    return text
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool isTaxItem(String descripcion) {
    final clean = normalizeProductText(descripcion);
    if (clean.isEmpty) return false;
    final taxKeywords = ['iva', 'iva 16', 'iva 8', 'iva g', 'iva r', 'impuesto', 'tax'];
    return taxKeywords.any((kw) => clean == kw || clean.startsWith('$kw ') || clean.contains('iva 16') || clean.contains('iva 8'));
  }

  /// Busca la última vez que se compró exactamente el mismo producto para comparar precio por unidad.
  /// Siempre devuelve el precio equivalente por unidad en USD para evitar comparaciones engañosas por cantidades o inflación.
  Future<Map<String, dynamic>?> findPreviousPrice(String descripcion, {int? excludeGastoId}) async {
    final cleanDesc = normalizeProductText(descripcion);
    if (cleanDesc.length <= 2) return null;
    if (isTaxItem(cleanDesc)) return null;

    final db = await instance.database;

    final result = await db.rawQuery('''
      SELECT i.precio_unitario, i.cantidad, i.total, i.descripcion,
             g.id as gasto_id, g.fecha, g.moneda, g.total_original, g.total_usd, g.comercio, g.tasa_cambio
      FROM items_gasto i
      JOIN gastos g ON i.gasto_id = g.id
      ${excludeGastoId != null ? 'WHERE g.id != $excludeGastoId' : ''}
      ORDER BY g.fecha DESC, g.id DESC
      LIMIT 250
    ''');

    for (final row in result) {
      final prevDesc = row['descripcion'] as String? ?? '';
      if (isTaxItem(prevDesc)) continue;

      final cleanPrevDesc = normalizeProductText(prevDesc);
      // Debe ser exactamente el mismo producto normalizado
      if (cleanPrevDesc != cleanDesc) continue;

      final moneda = row['moneda'] as String? ?? 'USD';
      final tasaRow = (row['tasa_cambio'] as num?)?.toDouble() ?? 1.0;
      final totalOrig = (row['total_original'] as num?)?.toDouble() ?? 0.0;
      final totalUsd = (row['total_usd'] as num?)?.toDouble() ?? 0.0;
      final cant = (row['cantidad'] as num?)?.toDouble() ?? 1.0;
      final totalItem = (row['total'] as num?)?.toDouble() ?? 0.0;
      final precioUnitItem = (row['precio_unitario'] as num?)?.toDouble() ?? 0.0;

      // Precio por unidad real en la moneda del gasto (en decimales)
      double unitPriceInCurrency;
      if (totalItem > 0 && cant > 0) {
        unitPriceInCurrency = (totalItem / 100.0) / cant;
      } else {
        unitPriceInCurrency = precioUnitItem / 100.0;
      }

      double tasa = tasaRow > 0 ? tasaRow : 1.0;
      if (tasa == 1.0 && totalOrig > 0 && totalUsd > 0 && (totalOrig / totalUsd) > 2.0) {
        tasa = totalOrig / totalUsd;
      }

      double prevUsd = unitPriceInCurrency;
      if (moneda == 'VES') {
        prevUsd = unitPriceInCurrency / tasa;
      } else {
        if (totalUsd > 0 && unitPriceInCurrency > (totalUsd / 100.0) * 2.0 && tasa > 1.0) {
          prevUsd = unitPriceInCurrency / tasa;
        }
      }

      return {
        'precio_usd': prevUsd,
        'fecha': row['fecha'] as String? ?? '',
        'comercio': row['comercio'] as String? ?? 'Otro comercio',
        'cantidad': cant,
      };
    }
    return null;
  }

  // --- SHOPPING LIST CRUD ---
  
  Future<List<ShoppingItemModel>> getPendingShoppingItems() async {
    final db = await instance.database;
    final result = await db.query(
      'shopping_items',
      where: 'is_purchased = 0',
      orderBy: 'id DESC',
    );
    return result.map((m) => ShoppingItemModel.fromMap(m)).toList();
  }

  Future<List<ShoppingItemModel>> getAllShoppingItems() async {
    final db = await instance.database;
    final result = await db.query(
      'shopping_items',
      orderBy: 'is_purchased ASC, id DESC',
    );
    return result.map((m) => ShoppingItemModel.fromMap(m)).toList();
  }

  Future<int> insertShoppingItem(ShoppingItemModel item) async {
    final db = await instance.database;
    return await db.insert('shopping_items', item.toMap());
  }

  Future<void> updateShoppingItemStatus(int id, bool isPurchased, {int? gastoId}) async {
    final db = await instance.database;
    await db.update(
      'shopping_items',
      {
        'is_purchased': isPurchased ? 1 : 0,
        'gasto_id': gastoId,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateShoppingItemName(int id, String newName) async {
    final db = await instance.database;
    await db.update(
      'shopping_items',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteShoppingItem(int id) async {
    final db = await instance.database;
    await db.delete('shopping_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markShoppingItemsAsPurchased(List<int> ids, int gastoId) async {
    if (ids.isEmpty) return;
    final db = await instance.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE shopping_items SET is_purchased = 1, gasto_id = ? WHERE id IN ($placeholders)',
      [gastoId, ...ids],
    );
  }

  // ==========================================
  // OPERACIONES PARA SCAN_QUEUE
  // ==========================================

  Future<int> insertScanQueueItem(String imagePath, {String? ocrText}) async {
    final db = await instance.database;
    final data = <String, dynamic>{
      'image_path': imagePath,
      'status': 'pending',
      'attempt_count': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    if (ocrText != null) {
      data['ocr_text'] = ocrText;
    }
    return await db.insert('scan_queue', data);
  }

  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async {
    final db = await instance.database;
    return await db.query(
      'scan_queue',
      where: 'status = ? OR status = ?',
      whereArgs: ['pending', 'error'],
      orderBy: 'id ASC',
    );
  }

  /// Resetea los ítems que quedaron atascados en 'processing' a 'pending' (recuperación al iniciar)
  Future<int> resetStaleProcessingScanQueueItems() async {
    final db = await database;
    return await db.update(
      'scan_queue',
      {'status': 'pending'},
      where: 'status = ?',
      whereArgs: ['processing'],
    );
  }

  /// Resetea los ítems en 'error' a 'pending' con attempt_count en 0 para reintento manual
  Future<int> resetFailedScanQueueItems() async {
    final db = await database;
    return await db.update(
      'scan_queue',
      {
        'status': 'pending',
        'attempt_count': 0,
        'last_error': null,
      },
      where: 'status = ?',
      whereArgs: ['error'],
    );
  }

  Future<List<Map<String, dynamic>>> getReadyScanQueueItems() async {
    final db = await instance.database;
    return await db.query(
      'scan_queue',
      where: 'status = ?',
      whereArgs: ['ready'],
    );
  }

  Future<List<Map<String, dynamic>>> getErrorScanQueueItems() async {
    final db = await instance.database;
    return await db.query(
      'scan_queue',
      where: 'status = ?',
      whereArgs: ['error'],
    );
  }

  Future<int> updateScanQueueItem(
    int id,
    String status, {
    String? extractedData,
    String? ocrText,
    int? attemptCount,
    String? lastError,
  }) async {
    final db = await instance.database;
    final data = <String, dynamic>{'status': status};
    if (extractedData != null) {
      data['extracted_data'] = extractedData;
    }
    if (ocrText != null) {
      data['ocr_text'] = ocrText;
    }
    if (attemptCount != null) {
      data['attempt_count'] = attemptCount;
    }
    if (lastError != null) {
      data['last_error'] = lastError;
    }
    return await db.update(
      'scan_queue',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteScanQueueItem(int id) async {
    final db = await instance.database;
    return await db.delete(
      'scan_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertReadyScanQueueItem(String imagePath, String extractedData, {String? ocrText}) async {
    final db = await instance.database;
    final data = <String, dynamic>{
      'image_path': imagePath,
      'status': 'ready',
      'extracted_data': extractedData,
      'created_at': DateTime.now().toIso8601String(),
    };
    if (ocrText != null) {
      data['ocr_text'] = ocrText;
    }
    return await db.insert('scan_queue', data);
  }

  // ==========================================
  // OPERACIONES FTS5 PARA BÚSQUEDA PROFUNDA
  // ==========================================

  /// Sincroniza o indexa el texto OCR y comercio en la tabla virtual FTS5.
  /// Invariante: Es una optimización de búsqueda, nunca bloquea la persistencia del gasto.
  Future<void> syncGastoFts(int gastoId, String comercio, String? ocrText) async {
    if (ocrText == null || ocrText.trim().isEmpty) return;
    try {
      final db = await instance.database;
      await db.delete('gastos_fts', where: 'gasto_id = ?', whereArgs: [gastoId]);
      await db.insert('gastos_fts', {
        'gasto_id': gastoId,
        'comercio': comercio,
        'ocr_text': ocrText,
      });
    } catch (_) {
      // Fallback silencioso si FTS5 no está disponible en este dispositivo
    }
  }

  /// Elimina un registro del índice FTS5
  Future<void> deleteGastoFts(int gastoId) async {
    try {
      final db = await instance.database;
      await db.delete('gastos_fts', where: 'gasto_id = ?', whereArgs: [gastoId]);
    } catch (_) {}
  }

  /// Busca IDs de gastos cuyos productos o texto de factura coincidan con [query].
  /// Invariante: Si FTS5 no está disponible o falla, realiza fallback transparente mediante LIKE.
  Future<List<int>> searchGastosFts(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final db = await instance.database;
    try {
      // 1. Intento primario con FTS5 (insensible a acentos y mayúsculas vía unicode61)
      final formattedQuery = cleanQuery
          .replaceAll('"', '""')
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .map((t) => '"$t"*')
          .join(' ');

      final results = await db.rawQuery(
        'SELECT DISTINCT gasto_id FROM gastos_fts WHERE gastos_fts MATCH ?',
        [formattedQuery],
      );
      final ids = results.map((row) => (row['gasto_id'] as num).toInt()).toList();
      if (ids.isNotEmpty) return ids;
    } catch (_) {
      // Fallback a consulta tradicional si FTS5 no existe o arroja error
    }

    // 2. Fallback resiliente con LIKE
    try {
      final likeQuery = '%$cleanQuery%';
      final results = await db.rawQuery('''
        SELECT DISTINCT g.id FROM gastos g
        LEFT JOIN items_gasto i ON g.id = i.gasto_id
        WHERE g.eliminado_en IS NULL AND (
          g.comercio LIKE ? OR 
          g.ocr_text LIKE ? OR 
          i.descripcion LIKE ?
        )
      ''', [likeQuery, likeQuery, likeQuery]);
      return results.map((row) => (row['id'] as num).toInt()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isImagePathUsedByOtherQueueItems(int currentId, String imagePath) async {
    final db = await instance.database;
    final result = await db.query(
      'scan_queue',
      where: 'image_path = ? AND id != ?',
      whereArgs: [imagePath, currentId],
    );
    return result.isNotEmpty;
  }

  Future<int> clearPendingScanQueueItems() async {
    final db = await instance.database;
    return await db.delete(
      'scan_queue',
      where: 'status = ? OR status = ?',
      whereArgs: ['pending', 'error'],
    );
  }

  // ==========================================
  // OPERACIONES PARA CATEGORIAS Y PRESUPUESTOS
  // ==========================================

  /// Inserta una nueva categoría o reemplaza en caso de conflicto
  Future<int> insertCategoria(CategoriaModel categoria) async {
    final db = await instance.database;
    return await db.insert(
      'categorias',
      categoria.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Actualiza una categoría existente
  Future<int> updateCategoria(CategoriaModel categoria) async {
    final db = await instance.database;
    return await db.update(
      'categorias',
      categoria.toMap(),
      where: 'id = ?',
      whereArgs: [categoria.id],
    );
  }

  /// Define o actualiza el presupuesto mensual de una categoría (búsqueda insensible a mayúsculas)
  Future<void> setPresupuestoCategoria(String categoriaNombre, double presupuesto) async {
    final db = await instance.database;
    final trimmedName = categoriaNombre.trim();
    final existing = await db.query(
      'categorias',
      where: 'LOWER(nombre) = ?',
      whereArgs: [trimmedName.toLowerCase()],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      await db.update(
        'categorias',
        {'presupuesto_mensual': presupuesto},
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
    } else {
      await db.insert('categorias', {
        'nombre': trimmedName,
        'presupuesto_mensual': presupuesto,
      });
    }
  }

  /// Obtiene todas las categorías registradas
  Future<List<CategoriaModel>> getAllCategorias() async {
    final db = await instance.database;
    final result = await db.query('categorias', orderBy: 'nombre ASC');
    return result.map((m) => CategoriaModel.fromMap(m)).toList();
  }

  /// Obtiene una categoría por su nombre
  Future<CategoriaModel?> getCategoriaPorNombre(String categoriaNombre) async {
    final db = await instance.database;
    final result = await db.query(
      'categorias',
      where: 'LOWER(nombre) = ?',
      whereArgs: [categoriaNombre.trim().toLowerCase()],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return CategoriaModel.fromMap(result.first);
    }
    return null;
  }

  /// Obtiene el presupuesto mensual de una categoría
  Future<double> getPresupuestoPorCategoria(String categoriaNombre) async {
    final cat = await getCategoriaPorNombre(categoriaNombre);
    return cat?.presupuestoMensual ?? 0.0;
  }

  /// Obtiene un mapa con todos los presupuestos asignados (> 0) {categoria: presupuesto}
  Future<Map<String, double>> getAllPresupuestosCategorias() async {
    final db = await instance.database;
    final result = await db.query(
      'categorias',
      where: 'presupuesto_mensual > 0',
    );
    final Map<String, double> presupuestos = {};
    for (final row in result) {
      final name = row['nombre'] as String;
      final budget = (row['presupuesto_mensual'] as num?)?.toDouble() ?? 0.0;
      if (budget > 0) {
        presupuestos[name] = budget;
      }
    }
    return presupuestos;
  }

  // ==========================================
  // OPERACIONES DE PRESUPUESTOS MENSUALES (V10)
  // ==========================================

  /// Obtiene el presupuesto general para un mes y año específico
  Future<double> getPresupuestoGeneral(int anio, int mes) async {
    final db = await instance.database;
    final result = await db.query(
      'presupuestos_mensuales',
      where: 'anio = ? AND mes = ?',
      whereArgs: [anio, mes],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return (result.first['presupuesto_general'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  /// Obtiene la meta de ahorro para un mes y año específico
  Future<double> getMetaAhorro(int anio, int mes) async {
    final db = await instance.database;
    final result = await db.query(
      'presupuestos_mensuales',
      where: 'anio = ? AND mes = ?',
      whereArgs: [anio, mes],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return (result.first['meta_ahorro'] as num?)?.toDouble() ?? 0.0;
    }
    return 0.0;
  }

  /// Obtiene la moneda del presupuesto general para un mes y año específico
  Future<String> getPresupuestoGeneralMoneda(int anio, int mes) async {
    final db = await instance.database;
    final result = await db.query(
      'presupuestos_mensuales',
      where: 'anio = ? AND mes = ?',
      whereArgs: [anio, mes],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return (result.first['moneda'] as String?) ?? 'USD';
    }
    return 'USD';
  }

  /// Define o actualiza el presupuesto general para un mes y año específico
  Future<void> setPresupuestoGeneral(
    int anio,
    int mes,
    double monto, {
    String moneda = 'USD',
    double metaAhorro = 0.0,
  }) async {
    final db = await instance.database;
    await db.insert(
      'presupuestos_mensuales',
      {
        'anio': anio,
        'mes': mes,
        'presupuesto_general': monto >= 0 ? monto : 0.0,
        'meta_ahorro': metaAhorro >= 0 ? metaAhorro : 0.0,
        'moneda': moneda,
        'actualizado_en': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Obtiene los presupuestos de categorías asignados para un mes y año (> 0)
  Future<Map<String, double>> getPresupuestosCategorias(int anio, int mes) async {
    final db = await instance.database;
    final result = await db.query(
      'presupuestos_categorias_mensuales',
      where: 'anio = ? AND mes = ? AND presupuesto > 0',
      whereArgs: [anio, mes],
    );
    final Map<String, double> presupuestos = {};
    for (final row in result) {
      final name = row['categoria'] as String;
      final budget = (row['presupuesto'] as num?)?.toDouble() ?? 0.0;
      if (budget > 0) {
        presupuestos[name] = budget;
      }
    }
    return presupuestos;
  }

  /// Define o elimina el presupuesto de una categoría para un mes específico
  Future<void> setPresupuestoCategoriaMensual(int anio, int mes, String categoriaNombre, double presupuesto, {String moneda = 'USD'}) async {
    final db = await instance.database;
    final trimmed = categoriaNombre.trim();
    final nowIso = DateTime.now().toIso8601String();
    if (presupuesto <= 0) {
      await db.delete(
        'presupuestos_categorias_mensuales',
        where: 'anio = ? AND mes = ? AND LOWER(categoria) = ?',
        whereArgs: [anio, mes, trimmed.toLowerCase()],
      );
    } else {
      await db.insert(
        'presupuestos_categorias_mensuales',
        {
          'anio': anio,
          'mes': mes,
          'categoria': trimmed,
          'presupuesto': presupuesto,
          'moneda': moneda,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final existing = await db.query(
      'presupuestos_mensuales',
      where: 'anio = ? AND mes = ?',
      whereArgs: [anio, mes],
    );
    if (existing.isNotEmpty) {
      await db.update(
        'presupuestos_mensuales',
        {'actualizado_en': nowIso},
        where: 'anio = ? AND mes = ?',
        whereArgs: [anio, mes],
      );
    } else {
      await db.insert(
        'presupuestos_mensuales',
        {
          'anio': anio,
          'mes': mes,
          'presupuesto_general': 0.0,
          'moneda': moneda,
          'actualizado_en': nowIso,
        },
      );
    }
  }

  /// Guarda todos los presupuestos de categoría de un mes reemplazando los existentes
  Future<void> setPresupuestosCategorias(int anio, int mes, Map<String, double> presupuestos, {String moneda = 'USD'}) async {
    final db = await instance.database;
    final nowIso = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'presupuestos_categorias_mensuales',
        where: 'anio = ? AND mes = ?',
        whereArgs: [anio, mes],
      );
      for (final entry in presupuestos.entries) {
        if (entry.value > 0) {
          await txn.insert(
            'presupuestos_categorias_mensuales',
            {
              'anio': anio,
              'mes': mes,
              'categoria': entry.key.trim(),
              'presupuesto': entry.value,
              'moneda': moneda,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      final existing = await txn.query(
        'presupuestos_mensuales',
        where: 'anio = ? AND mes = ?',
        whereArgs: [anio, mes],
      );
      if (existing.isNotEmpty) {
        await txn.update(
          'presupuestos_mensuales',
          {'actualizado_en': nowIso},
          where: 'anio = ? AND mes = ?',
          whereArgs: [anio, mes],
        );
      } else {
        await txn.insert(
          'presupuestos_mensuales',
          {
            'anio': anio,
            'mes': mes,
            'presupuesto_general': 0.0,
            'moneda': moneda,
            'actualizado_en': nowIso,
          },
        );
      }
    });
  }

  /// Obtiene todos los presupuestos mensuales con su presupuesto general y desglose por categorías
  Future<List<Map<String, dynamic>>> getAllPresupuestosMensualesCompletos() async {
    final db = await instance.database;
    final generalRows = await db.query('presupuestos_mensuales');
    final catRows = await db.query('presupuestos_categorias_mensuales');

    final Set<String> claves = {};
    for (final row in generalRows) {
      claves.add('${row['anio']}_${row['mes']}');
    }
    for (final row in catRows) {
      claves.add('${row['anio']}_${row['mes']}');
    }

    final List<Map<String, dynamic>> resultado = [];
    for (final clave in claves) {
      final partes = clave.split('_');
      final anio = int.parse(partes[0]);
      final mes = int.parse(partes[1]);

      Map<String, dynamic>? genRow;
      for (final r in generalRows) {
        if (r['anio'] == anio && r['mes'] == mes) {
          genRow = r;
          break;
        }
      }

      final Map<String, double> cats = {};
      for (final r in catRows) {
        if (r['anio'] == anio && r['mes'] == mes) {
          final catName = r['categoria'] as String;
          final budget = (r['presupuesto'] as num?)?.toDouble() ?? 0.0;
          if (budget > 0) {
            cats[catName] = budget;
          }
        }
      }

      final general = (genRow?['presupuesto_general'] as num?)?.toDouble() ?? 0.0;
      final metaAhorro = (genRow?['meta_ahorro'] as num?)?.toDouble() ?? 0.0;
      final moneda = (genRow?['moneda'] as String?) ?? 'USD';
      final actualizadoEn = genRow?['actualizado_en'] as String?;

      resultado.add({
        'anio': anio,
        'mes': mes,
        'presupuesto_general': general,
        'meta_ahorro': metaAhorro,
        'moneda': moneda,
        'categorias': cats,
        'actualizado_en': actualizadoEn,
      });
    }
    return resultado;
  }

  /// Guarda un presupuesto mensual completo con sus categorías (usado en sincronización)
  Future<void> guardarPresupuestoMensualCompleto({
    required int anio,
    required int mes,
    required double general,
    required String moneda,
    required Map<String, double> categorias,
    double metaAhorro = 0.0,
    String? actualizadoEn,
  }) async {
    final db = await instance.database;
    final timestamp = actualizadoEn ?? DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert(
        'presupuestos_mensuales',
        {
          'anio': anio,
          'mes': mes,
          'presupuesto_general': general >= 0 ? general : 0.0,
          'meta_ahorro': metaAhorro >= 0 ? metaAhorro : 0.0,
          'moneda': moneda,
          'actualizado_en': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'presupuestos_categorias_mensuales',
        where: 'anio = ? AND mes = ?',
        whereArgs: [anio, mes],
      );

      for (final entry in categorias.entries) {
        if (entry.value > 0) {
          await txn.insert(
            'presupuestos_categorias_mensuales',
            {
              'anio': anio,
              'mes': mes,
              'categoria': entry.key.trim(),
              'presupuesto': entry.value,
              'moneda': moneda,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  /// Elimina una categoría por su ID
  Future<int> deleteCategoria(int id) async {
    final db = await instance.database;
    return await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }

  /// Repara gastos históricos que tengan tasa_cambio <= 1.0 para que cuadren en Bolívares
  Future<int> repararTasasHistoricasIncompletas({double tasaFallback = 40.0}) async {
    final db = await instance.database;
    final rows = await db.query(
      'gastos',
      columns: ['id', 'moneda', 'total_original', 'total_usd', 'tasa_cambio', 'fecha'],
      where: 'tasa_cambio <= 1.0 AND eliminado_en IS NULL',
    );

    int actualizados = 0;
    for (final row in rows) {
      final id = row['id'] as int;
      final moneda = (row['moneda'] as String?) ?? 'USD';
      final totalOrig = ((row['total_original'] as num?)?.toInt() ?? 0) / 100.0;
      final totalUsd = ((row['total_usd'] as num?)?.toInt() ?? 0) / 100.0;

      double nuevaTasa = 0.0;
      // Caso 1: Tasa implícita existente en los montos (ej: gasto en Bs. con total original y total USD ya calculados)
      if (totalOrig > 0 && totalUsd > 0 && (totalOrig / totalUsd) > 2.0) {
        nuevaTasa = totalOrig / totalUsd;
      } else if (moneda == 'USD' && totalUsd > 0) {
        // Caso 2: Gasto registrado en USD pero sin tasa asignada (ej: desde chat)
        nuevaTasa = tasaFallback;
      }

      if (nuevaTasa > 1.0) {
        await db.update(
          'gastos',
          {'tasa_cambio': nuevaTasa},
          where: 'id = ?',
          whereArgs: [id],
        );
        actualizados++;
      }
    }
    return actualizados;
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
