import '../../core/db/app_db.dart';
import 'models.dart';

class TableClientService {
  Future<List<TableClient>> list({
    required int userId,
    required String type,
  }) async {
    final db = await AppDb.get();
    final rows = await db.query(
      'tables_or_clients',
      where: 'userId = ? AND type = ?',
      whereArgs: [userId, type],
      orderBy: 'sortOrder ASC, id ASC',
    );
    return rows.map((e) => TableClient.fromMap(e)).toList();
  }

  Future<int> create({
    required int userId,
    required String type,
    required String name,
  }) async {
    final db = await AppDb.get();
    final existing = await db.rawQuery(
      'SELECT COUNT(*) as c FROM tables_or_clients WHERE userId = ? AND type = ?',
      [userId, type],
    );
    final sortOrder = (existing.first['c'] as int?) ?? 0;

    return db.insert('tables_or_clients', {
      'userId': userId,
      'type': type,
      'name': name.trim(),
      'sortOrder': sortOrder,
    });
  }

  Future<void> delete(int id) async {
    final db = await AppDb.get();
    await db.delete('tables_or_clients', where: 'id = ?', whereArgs: [id]);
  }

  Future<TableClient?> getById(int id) async {
    final db = await AppDb.get();
    final rows = await db.query(
      'tables_or_clients',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return TableClient.fromMap(rows.first);
  }
}
