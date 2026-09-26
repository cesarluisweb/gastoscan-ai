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
      version: 10,
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
        synced INTEGER DEFAULT 0
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
        UNIQUE(anio, mes, categoria)
      )
    ''');

    // Índices para búsquedas y filtros rápidos por fecha y categoría
    await db.execute('CREATE INDEX idx_gastos_fecha ON gastos (fecha);');
    await db.execute('CREATE INDEX idx_gastos_categoria ON gastos (categoria);');
  }

  /// Inserta un gasto con sus ítems asociados de forma atómica en una transacción
  Future<int> insertGasto(GastoModel gasto, List<ItemGastoModel> items) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      final gastoId = await txn.insert('gastos', gasto.toMap());
      for (final item in items) {
        final itemMap = item.toMap();
        itemMap['gasto_id'] = gastoId;
        await txn.insert('items_gasto', itemMap);
      }
      return gastoId;
    });
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
  }

  /// Elimina un gasto. Los ítems se eliminan automáticamente gracias a ON DELETE CASCADE
  Future<int> deleteGasto(int id) async {
    final db = await instance.database;
    return await db.delete('gastos', where: 'id = ?', whereArgs: [id]);
  }

  /// Obtiene todos los gastos ordenados de más reciente a más antiguo (sin borrados lógicos)
  Future<List<GastoModel>> getAllGastos() async {
    final db = await instance.database;
    final result = await db.query(
      'gastos', 
      where: 'eliminado_en IS NULL',
      orderBy: 'fecha DESC, id DESC'
    );
    
    final List<GastoModel> gastosList = [];
    for (final map in result) {
      final gastoId = map['id'] as int;
      final itemsResult = await db.query(
        'items_gasto',
        where: 'gasto_id = ?',
        whereArgs: [gastoId],
      );
      final items = itemsResult.map((i) => ItemGastoModel.fromMap(i)).toList();
      gastosList.add(GastoModel.fromMap(map, items: items));
    }
    return gastosList;
  }

  /// Obtiene TODOS los gastos, incluyendo los borrados lógicos, para resolver conflictos de sincronización
  Future<List<GastoModel>> getAllGastosConBorrados() async {
    final db = await instance.database;
    final result = await db.query('gastos');
    
    final List<GastoModel> gastosList = [];
    for (final map in result) {
      final gastoId = map['id'] as int;
      final itemsResult = await db.query(
        'items_gasto',
        where: 'gasto_id = ?',
        whereArgs: [gastoId],
      );
      final items = itemsResult.map((i) => ItemGastoModel.fromMap(i)).toList();
      gastosList.add(GastoModel.fromMap(map, items: items));
    }
    return gastosList;
  }

  Future<List<GastoModel>> getUnsyncedGastos() async {
    final db = await instance.database;
    final result = await db.query(
      'gastos',
      where: 'synced = 0 OR synced IS NULL',
    );
    final List<GastoModel> gastosList = [];
    for (final map in result) {
      final gastoId = map['id'] as int;
      final itemsResult = await db.query(
        'items_gasto',
        where: 'gasto_id = ?',
        whereArgs: [gastoId],
      );
      final items = itemsResult.map((i) => ItemGastoModel.fromMap(i)).toList();
      gastosList.add(GastoModel.fromMap(map, items: items));
    }
    return gastosList;
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

    final List<GastoModel> gastosList = [];
    for (final map in result) {
      final gastoId = map['id'] as int;
      final itemsResult = await db.query(
        'items_gasto',
        where: 'gasto_id = ?',
        whereArgs: [gastoId],
      );
      final items = itemsResult.map((i) => ItemGastoModel.fromMap(i)).toList();
      gastosList.add(GastoModel.fromMap(map, items: items));
    }
    return gastosList;
  }

  /// Calcula los totales del mes (suma en USD y suma en VES)
  Future<Map<String, double>> getMonthlyTotals(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final usdResult = await db.rawQuery(
      'SELECT SUM(total_usd) as total FROM gastos WHERE fecha LIKE ? AND eliminado_en IS NULL',
      [pattern],
    );

    final vesResult = await db.rawQuery(
      'SELECT SUM(total_original) as total FROM gastos WHERE fecha LIKE ? AND moneda = ? AND eliminado_en IS NULL',
      [pattern, 'VES'],
    );

    // Dividimos entre 100 porque los montos ahora están en enteros
    final double totalUsd = ((usdResult.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;
    final double totalVes = ((vesResult.first['total'] as num?)?.toDouble() ?? 0.0) / 100.0;

    return {
      'USD': totalUsd,
      'VES': totalVes,
    };
  }

  /// Calcula el desglose de gastos en USD agrupado por categoría de cada ítem para el gráfico
  Future<Map<String, double>> getCategoryTotals(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final result = await db.rawQuery('''
      SELECT 
        i.categoria, 
        SUM(
          CASE 
            WHEN g.total_original > 0 
            THEN (i.total * 1.0 / g.total_original) * g.total_usd 
            ELSE 0 
          END
        ) as total
      FROM items_gasto i
      JOIN gastos g ON i.gasto_id = g.id
      WHERE g.fecha LIKE ? AND g.eliminado_en IS NULL
      GROUP BY i.categoria
      ORDER BY total DESC
    ''', [pattern]);

    final Map<String, double> categoryMap = {};
    for (final row in result) {
      final cat = row['categoria'] as String;
      // Convertimos los centavos a decimales para mostrar en la UI
      final total = ((row['total'] as num?)?.toDouble() ?? 0.0) / 100.0;
      categoryMap[cat] = total;
    }
    return categoryMap;
  }

  /// Busca la última vez que se compró un producto similar para comparar precio.
  /// Siempre devuelve el precio equivalente en USD para evitar falsos aumentos por inflación.
  Future<Map<String, dynamic>?> findPreviousPrice(String descripcion) async {
    final db = await instance.database;
    
    // Búsqueda simple, podríamos mejorar la precisión después
    final searchTerm = '%${descripcion.trim()}%';
    
    final result = await db.rawQuery('''
      SELECT i.precio_unitario, g.fecha, g.moneda, g.total_original, g.total_usd, g.comercio
      FROM items_gasto i
      JOIN gastos g ON i.gasto_id = g.id
      WHERE i.descripcion LIKE ?
      ORDER BY g.fecha DESC, g.id DESC
      LIMIT 1
    ''', [searchTerm]);

    if (result.isNotEmpty) {
      final row = result.first;
      final moneda = row['moneda'] as String;
      double precioUnitario = (row['precio_unitario'] as num?)?.toDouble() ?? 0.0;
      
      double precioUsd = precioUnitario;
      if (moneda != 'USD') {
        final totalOrig = (row['total_original'] as num?)?.toDouble() ?? 0.0;
        final totalUsd = (row['total_usd'] as num?)?.toDouble() ?? 0.0;
        if (totalUsd > 0 && totalOrig > 0) {
          final tasa = totalOrig / totalUsd;
          precioUsd = precioUnitario / tasa;
        }
      }

      return {
        'precio_usd': precioUsd / 100.0, // UI maneja double
        'fecha': row['fecha'] as String,
        'comercio': row['comercio'] as String,
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

  Future<int> insertScanQueueItem(String imagePath) async {
    final db = await instance.database;
    return await db.insert('scan_queue', {
      'image_path': imagePath,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingScanQueueItems() async {
    final db = await instance.database;
    return await db.query(
      'scan_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
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

  Future<int> updateScanQueueItem(int id, String status, {String? extractedData}) async {
    final db = await instance.database;
    final data = <String, dynamic>{'status': status};
    if (extractedData != null) {
      data['extracted_data'] = extractedData;
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

  Future<int> insertReadyScanQueueItem(String imagePath, String extractedData) async {
    final db = await instance.database;
    return await db.insert('scan_queue', {
      'image_path': imagePath,
      'status': 'ready',
      'extracted_data': extractedData,
      'created_at': DateTime.now().toIso8601String(),
    });
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
      where: 'status = ?',
      whereArgs: ['pending'],
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

  /// Define o actualiza el presupuesto general para un mes y año específico
  Future<void> setPresupuestoGeneral(int anio, int mes, double monto) async {
    final db = await instance.database;
    await db.insert(
      'presupuestos_mensuales',
      {
        'anio': anio,
        'mes': mes,
        'presupuesto_general': monto >= 0 ? monto : 0.0,
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
  Future<void> setPresupuestoCategoriaMensual(int anio, int mes, String categoriaNombre, double presupuesto) async {
    final db = await instance.database;
    final trimmed = categoriaNombre.trim();
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
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  /// Guarda todos los presupuestos de categoría de un mes reemplazando los existentes
  Future<void> setPresupuestosCategorias(int anio, int mes, Map<String, double> presupuestos) async {
    final db = await instance.database;
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
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }

  /// Copia el presupuesto general y por categorías del mes anterior si el mes actual no tiene registros
  Future<bool> copiarPresupuestosMesAnteriorSiVacio(int anio, int mes) async {
    final db = await instance.database;
    final generalCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM presupuestos_mensuales WHERE anio = ? AND mes = ?',
      [anio, mes],
    )) ?? 0;
    final catCount = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM presupuestos_categorias_mensuales WHERE anio = ? AND mes = ?',
      [anio, mes],
    )) ?? 0;

    if (generalCount > 0 || catCount > 0) {
      return false;
    }

    final int prevMes = mes == 1 ? 12 : mes - 1;
    final int prevAnio = mes == 1 ? anio - 1 : anio;

    final prevGeneral = await getPresupuestoGeneral(prevAnio, prevMes);
    final prevCats = await getPresupuestosCategorias(prevAnio, prevMes);

    if (prevGeneral > 0 || prevCats.isNotEmpty) {
      if (prevGeneral > 0) {
        await setPresupuestoGeneral(anio, mes, prevGeneral);
      }
      if (prevCats.isNotEmpty) {
        await setPresupuestosCategorias(anio, mes, prevCats);
      }
      return true;
    }
    return false;
  }

  /// Elimina una categoría por su ID
  Future<int> deleteCategoria(int id) async {
    final db = await instance.database;
    return await db.delete('categorias', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
