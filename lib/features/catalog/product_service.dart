import '../../core/db/app_db.dart';
import 'models.dart';

class ProductService {
  Future<List<Product>> listByCategory({
    required int userId,
    required int categoryId,
  }) async {
    final db = await AppDb.get();
    final rows = await db.query(
      'products',
      where: 'userId = ? AND categoryId = ? AND active = 1',
      whereArgs: [userId, categoryId],
      orderBy: 'id DESC',
    );
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<Product?> getById(int productId) async {
    final db = await AppDb.get();
    final rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<List<Product>> search({
    required int userId,
    required String q,
    int limit = 50,
  }) async {
    final db = await AppDb.get();
    final query = q.trim();
    if (query.isEmpty) return [];

    final rows = await db.query(
      'products',
      where: 'userId = ? AND active = 1 AND name LIKE ?',
      whereArgs: [userId, '%$query%'],
      orderBy: 'name ASC',
      limit: limit,
    );
    return rows.map((e) => Product.fromMap(e)).toList();
  }

  Future<int> create({
    required int userId,
    required int categoryId,
    required String name,
    required double stockQty,
    required double salePrice,
    required double costPrice,
    String? imagePath,
  }) async {
    final db = await AppDb.get();
    return db.insert('products', {
      'userId': userId,
      'categoryId': categoryId,
      'name': name.trim(),
      'stockQty': stockQty,
      'salePrice': salePrice,
      'costPrice': costPrice,
      'productImagePath': imagePath,
      'active': 1,
    });
  }

  Future<void> addStock({required int productId, required double delta}) async {
    final db = await AppDb.get();
    final rows = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final current = (rows.first['stockQty'] as num?)?.toDouble() ?? 0;
    await db.update(
      'products',
      {'stockQty': current + delta},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> countAll(int userId) async {
    final db = await AppDb.get();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM products WHERE userId = ? AND active = 1',
      [userId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
