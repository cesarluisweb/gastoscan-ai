import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/gasto_model.dart';
import '../../models/item_gasto_model.dart';
import '../../models/shopping_item_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar columnas para sincronizacion con Firebase
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
        fecha TEXT NOT NULL,
        comercio TEXT NOT NULL,
        moneda TEXT NOT NULL,
        total_original REAL NOT NULL,
        total_usd REAL NOT NULL,
        categoria TEXT NOT NULL,
        ruta_foto_local TEXT,
        creado_en TEXT NOT NULL,
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
        precio_unitario REAL NOT NULL,
        total REAL NOT NULL,
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

  /// Obtiene todos los gastos ordenados de más reciente a más antiguo
  Future<List<GastoModel>> getAllGastos() async {
    final db = await instance.database;
    final result = await db.query('gastos', orderBy: 'fecha DESC, id DESC');
    
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
      where: 'fecha LIKE ?',
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
      'SELECT SUM(total_usd) as total FROM gastos WHERE fecha LIKE ?',
      [pattern],
    );

    final vesResult = await db.rawQuery(
      'SELECT SUM(total_original) as total FROM gastos WHERE fecha LIKE ? AND moneda = ?',
      [pattern, 'VES'],
    );

    final double totalUsd = (usdResult.first['total'] as num?)?.toDouble() ?? 0.0;
    final double totalVes = (vesResult.first['total'] as num?)?.toDouble() ?? 0.0;

    return {
      'USD': totalUsd,
      'VES': totalVes,
    };
  }

  /// Calcula el desglose de gastos en USD agrupado por categoría para el gráfico
  Future<Map<String, double>> getCategoryTotals(int year, int month) async {
    final db = await instance.database;
    final monthStr = month.toString().padLeft(2, '0');
    final pattern = '$year-$monthStr%';

    final result = await db.rawQuery('''
      SELECT categoria, SUM(total_usd) as total
      FROM gastos
      WHERE fecha LIKE ?
      GROUP BY categoria
      ORDER BY total DESC
    ''', [pattern]);

    final Map<String, double> categoryMap = {};
    for (final row in result) {
      final cat = row['categoria'] as String;
      final total = (row['total'] as num?)?.toDouble() ?? 0.0;
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
        'precio_usd': precioUsd,
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

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
