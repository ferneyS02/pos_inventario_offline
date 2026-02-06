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
      'subtotal': 0.0,
      'discount': 0.0,
      'tip': 0.0,
      'taxRate': 0.0,
      'taxAmount': 0.0,
      'paymentMethod': 'cash',
      'invoiceNo': null,
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

  Future<void> closeOrder({
    required int userId,
    required int orderId,
    required String paymentMethod, // cash|card|virtual
    required double discount,
    required double tip,
    required double taxRate, // %
  }) async {
    final db = await AppDb.get();

    await db.transaction((txn) async {
      final oRows = await txn.query(
        'orders',
        where: 'id = ? AND userId = ? AND status = ?',
        whereArgs: [orderId, userId, 'open'],
        limit: 1,
      );
      if (oRows.isEmpty) return;

      final items = await txn.query(
        'order_items',
        where: 'orderId = ?',
        whereArgs: [orderId],
      );
      if (items.isEmpty) {
        throw Exception('No puedes cerrar una venta sin productos');
      }

      // 1) Descontar inventario
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
        await txn.update(
          'products',
          {'stockQty': currentStock - qty},
          where: 'id = ?',
          whereArgs: [productId],
        );
      }

      // 2) Recalcular subtotal y ganancia base (items)
      final sums = await txn.rawQuery(
        '''
        SELECT 
          COALESCE(SUM(lineTotal), 0) as subtotal,
          COALESCE(SUM(lineProfit), 0) as baseProfit
        FROM order_items
        WHERE orderId = ?
      ''',
        [orderId],
      );

      final subtotal = (sums.first['subtotal'] as num).toDouble();
      final baseProfit = (sums.first['baseProfit'] as num).toDouble();

      final d = discount < 0 ? 0 : discount;
      final t = tip < 0 ? 0 : tip;
      final tr = taxRate < 0 ? 0 : taxRate;

      final taxAmount = subtotal * (tr / 100.0);
      final totalFinal = subtotal - d + t + taxAmount;

      // Ajuste de ganancia: descuento baja ganancia; propina la sube
      final profitFinal = baseProfit - d + t;

      // 3) Consecutivo de factura
      await txn.insert('store_settings', {
        'userId': userId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      final sRows = await txn.query(
        'store_settings',
        where: 'userId = ?',
        whereArgs: [userId],
        limit: 1,
      );
      final s = sRows.first;

      final prefix = (s['invoicePrefix'] as String?) ?? 'F-';
      final nextNo = (s['nextInvoiceNumber'] as int?) ?? 1;
      final pad = (s['invoicePadding'] as int?) ?? 5;

      final invoiceNo = '$prefix${nextNo.toString().padLeft(pad, '0')}';

      await txn.update(
        'store_settings',
        {'nextInvoiceNumber': nextNo + 1},
        where: 'userId = ?',
        whereArgs: [userId],
      );

      // 4) Guardar orden cerrada
      await txn.update(
        'orders',
        {
          'status': 'paid',
          'closedAt': DateTime.now().toIso8601String(),
          'paymentMethod': paymentMethod,
          'invoiceNo': invoiceNo,
          'subtotal': subtotal,
          'discount': d,
          'tip': t,
          'taxRate': tr,
          'taxAmount': taxAmount,
          'total': totalFinal,
          'profit': profitFinal,
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
        COALESCE(SUM(lineTotal), 0) as subtotal,
        COALESCE(SUM(lineProfit), 0) as profit
      FROM order_items
      WHERE orderId = ?
    ''',
      [orderId],
    );

    final subtotal = (sums.first['subtotal'] as num).toDouble();
    final profit = (sums.first['profit'] as num).toDouble();

    // Mientras está abierta: total=SUBTOTAL y profit=profit base
    await txn.update(
      'orders',
      {'subtotal': subtotal, 'total': subtotal, 'profit': profit},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }
}
