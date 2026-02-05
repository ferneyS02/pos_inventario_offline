import '../../core/db/app_db.dart';

class StoreService {
  Future<Map<String, dynamic>?> getUser(int userId) async {
    final db = await AppDb.get();
    final rows = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<void> updateStore({
    required int userId,
    required String storeName,
    String? storeImagePath,
  }) async {
    final db = await AppDb.get();
    await db.update(
      'users',
      {'storeName': storeName.trim(), 'storeImagePath': storeImagePath},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}
