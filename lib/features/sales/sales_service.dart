import 'package:sqflite/sqflite.dart';
import '../../core/db/app_db.dart';
import 'models.dart';

class SalesService {
  Future<int> getOrCreateOpenOrder({
    required int userId,
    int? tableClientId,
  }) async {
    final db = await AppDb.get();

    final rows = tableClientId == null
        ? await db.query(
            'orders',
            where: 'userId = ? AND status = ? AND tableClientId IS NULL',
            whereArgs: [userId, 'open'],
            limit: 1,
          )
        : await db.query(
            'orders',
            where: 'userId = ? AND status = ? AND tableClientId = ?',
            whereArgs: [userId, 'open', tableClientId],
            limit: 1,
          );

    if (rows.isNotEmpty) return rows.first['id'] as int;

    return db.insert('orders', {
      'userId': userId,
      'tableClientId': tableClientId,
      'status': 'open',
      'openedAt': DateTime.now().toIso8601String(),
      'closedAt': null,
      'total': 0.0,
      'profit': 0.0,
      // ✅ PARTE 5: se define cuando se cierre la venta
      'paymentMethod': null, // 'cash' | 'card' | 'virtual'
    });
  }

  Future<List<OrderItemView>> listItems(int orderId) async {
    final db = await AppDb.get();
    final rows = await db.rawQuery(
      '''
      SELECT 
        oi.id as id,
        oi.productId as productId,
        p.name as productName,
        p.productImagePath as productImagePath,
        oi.qty as qty,
        oi.unitPrice as unitPrice,
        oi.unitCost as unitCost,
        oi.lineTotal as lineTotal,
        oi.lineProfit as lineProfit
      FROM order_items oi
      JOIN products p ON p.id = oi.productId
      WHERE oi.orderId = ?
      ORDER BY oi.id DESC
    ''',
      [orderId],
    );

    return rows.map((m) {
      return OrderItemView(
        id: m['id'] as int,
        productId: m['productId'] as int,
        productName: (m['productName'] as String?) ?? '',
        productImagePath: m['productImagePath'] as String?,
        qty: (m['qty'] as num).toDouble(),
        unitPrice: (m['unitPrice'] as num).toDouble(),
        unitCost: (m['unitCost'] as num).toDouble(),
        lineTotal: (m['lineTotal'] as num).toDouble(),
        lineProfit: (m['lineProfit'] as num).toDouble(),
      );
    }).toList();
  }

  Future<Map<String, double>> getTotals(int orderId) async {
    final db = await AppDb.get();
    final rows = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [orderId],
      limit: 1,
    );
    if (rows.isEmpty) return {'total': 0, 'profit': 0};
    return {
      'total': (rows.first['total'] as num?)?.toDouble() ?? 0,
      'profit': (rows.first['profit'] as num?)?.toDouble() ?? 0,
    };
  }

  Future<void> addProduct({
    required int orderId,
    required int productId,
  }) async {
    final db = await AppDb.get();

    await db.transaction((txn) async {
      // 1) leer producto
      final prodRows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (prodRows.isEmpty) return;
      final p = prodRows.first;
      final unitPrice = (p['salePrice'] as num?)?.toDouble() ?? 0;
      final unitCost = (p['costPrice'] as num?)?.toDouble() ?? 0;

      // 2) ver si ya existe el item
      final itemRows = await txn.query(
        'order_items',
        where: 'orderId = ? AND productId = ?',
        whereArgs: [orderId, productId],
        limit: 1,
      );

      if (itemRows.isEmpty) {
        final qty = 1.0;
        await txn.insert('order_items', {
          'orderId': orderId,
          'productId': productId,
          'qty': qty,
          'unitPrice': unitPrice,
          'unitCost': unitCost,
          'lineTotal': unitPrice * qty,
          'lineProfit': (unitPrice - unitCost) * qty,
        });
      } else {
        final id = itemRows.first['id'] as int;
        final qty = ((itemRows.first['qty'] as num).toDouble()) + 1.0;
        await txn.update(
          'order_items',
          {
            'qty': qty,
            'lineTotal': unitPrice * qty,
            'lineProfit': (unitPrice - unitCost) * qty,
          },
          where: 'id = ?',
          whereArgs: [id],
        );
      }

      await _recalcOrder(txn, orderId);
    });
  }

  Future<void> setItemQty({
    required int orderId,
    required int itemId,
    required double qty,
  }) async {
    final db = await AppDb.get();
    await db.transaction((txn) async {
      if (qty <= 0) {
        await txn.delete('order_items', where: 'id = ?', whereArgs: [itemId]);
        await _recalcOrder(txn, orderId);
        return;
      }

      final rows = await txn.query(
        'order_items',
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final unitPrice = (rows.first['unitPrice'] as num).toDouble();
      final unitCost = (rows.first['unitCost'] as num).toDouble();

      await txn.update(
        'order_items',
        {
          'qty': qty,
          'lineTotal': unitPrice * qty,
          'lineProfit': (unitPrice - unitCost) * qty,
        },
        where: 'id = ?',
        whereArgs: [itemId],
      );

      await _recalcOrder(txn, orderId);
    });
  }

  /// ✅ PARTE 5: se recibe el método de pago y se guarda en orders.paymentMethod
  /// paymentMethod: 'cash' | 'card' | 'virtual'
  Future<void> closeOrder({
    required int userId,
    required int orderId,
    required String paymentMethod,
  }) async {
    final db = await AppDb.get();

    await db.transaction((txn) async {
      // Validar orden abierta
      final oRows = await txn.query(
        'orders',
        where: 'id = ? AND userId = ? AND status = ?',
        whereArgs: [orderId, userId, 'open'],
        limit: 1,
      );
      if (oRows.isEmpty) return;

      // Validar método
      final pm = paymentMethod.trim();
      if (pm != 'cash' && pm != 'card' && pm != 'virtual') {
        throw Exception('Método de pago inválido');
      }

      final items = await txn.query(
        'order_items',
        where: 'orderId = ?',
        whereArgs: [orderId],
      );
      if (items.isEmpty) {
        throw Exception('No puedes cerrar una venta sin productos');
      }

      // Descontar inventario
      for (final it in items) {
        final productId = it['productId'] as int;
        final qty = (it['qty'] as num).toDouble();

        final pRows = await txn.query(
          'products',
          where: 'id = ?',
          whereArgs: [productId],
          limit: 1,
        );
        if (pRows.isEmpty) continue;

        final currentStock = (pRows.first['stockQty'] as num?)?.toDouble() ?? 0;
        final newStock = currentStock - qty;

        await txn.update(
          'products',
          {'stockQty': newStock},
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      await _recalcOrder(txn, orderId);

      await txn.update(
        'orders',
        {
          'status': 'paid',
          'closedAt': DateTime.now().toIso8601String(),
          // ✅ NUEVO
          'paymentMethod': pm,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
    });
  }

  static Future<void> _recalcOrder(Transaction txn, int orderId) async {
    final sums = await txn.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(lineTotal), 0) as total,
        COALESCE(SUM(lineProfit), 0) as profit
      FROM order_items
      WHERE orderId = ?
    ''',
      [orderId],
    );

    final total = (sums.first['total'] as num).toDouble();
    final profit = (sums.first['profit'] as num).toDouble();

    await txn.update(
      'orders',
      {'total': total, 'profit': profit},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
