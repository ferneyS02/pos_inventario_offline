import '../../core/db/app_db.dart';
import 'models.dart';

class CategoryService {
  Future<List<Category>> list(int userId) async {
    final db = await AppDb.get();
    final rows = await db.query(
      'categories',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return rows.map((e) => Category.fromMap(e)).toList();
  }

  Future<int> create({
    required int userId,
    required String name,
    int sortOrder = 0,
  }) async {
    final db = await AppDb.get();
    return db.insert('categories', {
      'userId': userId,
      'name': name.trim(),
      'sortOrder': sortOrder,
    });
  }

  Future<void> delete(int id) async {
    final db = await AppDb.get();
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
    // Nota: en Parte 2 no borramos productos en cascada (lo manejamos luego).
  }

  Future<int> count(int userId) async {
    final db = await AppDb.get();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as c FROM categories WHERE userId = ?',
      [userId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }
}
