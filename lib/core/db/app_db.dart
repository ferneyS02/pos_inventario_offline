import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDb {
  static Database? _db;

  static Future<String> dbFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'pos_local.db');
  }

  static Future<Database> get() async {
    if (_db != null) return _db!;
    final path = await dbFilePath();

    _db = await openDatabase(
      path,
      version: 4, // ✅ SUBIMOS A 4
      onCreate: (db, version) async {
        await _createV1(db);
        await _createV2(db);
        await _createV3(db);
        await _createV4(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createV2(db);
        if (oldVersion < 3) await _createV3(db);
        if (oldVersion < 4) await _createV4(db);
      },
    );

    return _db!;
  }

  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  static Future<void> _createV1(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        phone TEXT NOT NULL UNIQUE,
        passHash TEXT NOT NULL,
        storeName TEXT,
        storeImagePath TEXT,
        createdAt TEXT NOT NULL
      );
    ''');
  }

  static Future<void> _createV2(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        name TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        categoryId INTEGER NOT NULL,
        name TEXT NOT NULL,
        stockQty REAL NOT NULL DEFAULT 0,
        salePrice REAL NOT NULL DEFAULT 0,
        costPrice REAL NOT NULL DEFAULT 0,
        productImagePath TEXT,
        active INTEGER NOT NULL DEFAULT 1
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(userId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_user ON products(userId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_cat ON products(categoryId);',
    );
  }

  static Future<void> _createV3(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS tables_or_clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        sortOrder INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        tableClientId INTEGER,
        status TEXT NOT NULL,
        openedAt TEXT NOT NULL,
        closedAt TEXT,
        total REAL NOT NULL DEFAULT 0,
        profit REAL NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        orderId INTEGER NOT NULL,
        productId INTEGER NOT NULL,
        qty REAL NOT NULL,
        unitPrice REAL NOT NULL,
        unitCost REAL NOT NULL,
        lineTotal REAL NOT NULL,
        lineProfit REAL NOT NULL
      );
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tc_user_type ON tables_or_clients(userId, type);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_user_status ON orders(userId, status);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_items_order ON order_items(orderId);',
    );
  }

  static Future<void> _createV4(Database db) async {
    // ✅ Códigos de recuperación
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recovery_codes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId INTEGER NOT NULL,
        codeHash TEXT NOT NULL,
        usedAt TEXT
      );
    ''');

    // ✅ Método de pago en orders (ALTER si ya existe tabla)
    // SQLite no tiene "ADD COLUMN IF NOT EXISTS", lo controlamos con try/catch
    try {
      await db.execute("ALTER TABLE orders ADD COLUMN paymentMethod TEXT;");
    } catch (_) {}

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_recovery_user_used ON recovery_codes(userId, usedAt);',
    );

    // Si hay órdenes pagadas viejas sin método, las marcamos como 'cash'
    try {
      await db.execute(
        "UPDATE orders SET paymentMethod='cash' WHERE status='paid' AND (paymentMethod IS NULL OR paymentMethod='');",
      );
    } catch (_) {}
  }
}
