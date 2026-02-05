import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/db/app_db.dart';
import '../../core/security/hash.dart';

class AuthService {
  final _secure = const FlutterSecureStorage();

  Future<String> _getOrCreateSalt() async {
    final existing = await _secure.read(key: 'auth_salt');
    if (existing != null) return existing;

    final salt = List.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _secure.write(key: 'auth_salt', value: salt);
    return salt;
  }

  List<String> _generateRecoveryCodes() {
    final rnd = Random.secure();
    return List.generate(10, (_) {
      final n = rnd.nextInt(90000000) + 10000000; // 8 dígitos
      return n.toString();
    });
  }

  Future<int> register({required String phone, required String pin}) async {
    final db = await AppDb.get();
    final salt = await _getOrCreateSalt();
    final passHash = hashPassword(pin, salt);

    final id = await db.insert('users', {
      'phone': phone.trim(),
      'passHash': passHash,
      'createdAt': DateTime.now().toIso8601String(),
    });

    return id;
  }

  Future<int?> login({required String phone, required String pin}) async {
    final db = await AppDb.get();
    final salt = await _getOrCreateSalt();
    final passHash = hashPassword(pin, salt);

    final rows = await db.query(
      'users',
      where: 'phone = ? AND passHash = ?',
      whereArgs: [phone.trim(), passHash],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  /// ✅ Genera (o regenera) 10 códigos de recuperación y retorna los códigos EN CLARO para mostrarlos.
  /// (Los guardados quedan hashed).
  Future<List<String>> regenerateRecoveryCodes(int userId) async {
    final db = await AppDb.get();
    final salt = await _getOrCreateSalt();
    final codes = _generateRecoveryCodes();

    await db.transaction((txn) async {
      // Borramos códigos anteriores (usados o no) para crear un set nuevo
      await txn.delete(
        'recovery_codes',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      for (final code in codes) {
        await txn.insert('recovery_codes', {
          'userId': userId,
          'codeHash': hashPassword(code, salt),
          'usedAt': null,
        });
      }
    });

    return codes;
  }

  /// ✅ Recuperación OFFLINE con un código (solo 1 uso)
  Future<bool> recoverWithCode({
    required String phone,
    required String recoveryCode,
    required String newPin,
  }) async {
    final db = await AppDb.get();
    final salt = await _getOrCreateSalt();

    return await db.transaction((txn) async {
      final userRows = await txn.query(
        'users',
        where: 'phone = ?',
        whereArgs: [phone.trim()],
        limit: 1,
      );
      if (userRows.isEmpty) return false;

      final userId = userRows.first['id'] as int;
      final codeHash = hashPassword(recoveryCode.trim(), salt);

      final codeRows = await txn.query(
        'recovery_codes',
        where: 'userId = ? AND codeHash = ? AND usedAt IS NULL',
        whereArgs: [userId, codeHash],
        limit: 1,
      );
      if (codeRows.isEmpty) return false;

      // Marcar como usado
      await txn.update(
        'recovery_codes',
        {'usedAt': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [codeRows.first['id']],
      );

      // Cambiar PIN
      final newHash = hashPassword(newPin, salt);
      await txn.update(
        'users',
        {'passHash': newHash},
        where: 'id = ?',
        whereArgs: [userId],
      );

      return true;
    });
  }

  /// ✅ Cambiar PIN (con PIN actual)
  Future<bool> changePin({
    required int userId,
    required String currentPin,
    required String newPin,
  }) async {
    final db = await AppDb.get();
    final salt = await _getOrCreateSalt();
    final currentHash = hashPassword(currentPin, salt);

    final rows = await db.query(
      'users',
      where: 'id = ? AND passHash = ?',
      whereArgs: [userId, currentHash],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final newHash = hashPassword(newPin, salt);
    await db.update(
      'users',
      {'passHash': newHash},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return true;
  }
}
