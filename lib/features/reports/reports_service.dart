import '../../core/db/app_db.dart';
import 'reports_models.dart';

class ReportsService {
  // Normaliza: desde 00:00:00 y hasta 23:59:59.999 para incluir todo el día
  DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 0, 0, 0);
  DateTime endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  Future<Map<String, double>> totalsByRange({
    required int userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await AppDb.get();
    final f = startOfDay(from).toIso8601String();
    final t = endOfDay(to).toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT 
        COALESCE(SUM(total), 0) AS totalSales,
        COALESCE(SUM(profit), 0) AS totalProfit
      FROM orders
      WHERE userId = ?
        AND status = 'paid'
        AND closedAt IS NOT NULL
        AND closedAt >= ?
        AND closedAt <= ?
    ''',
      [userId, f, t],
    );

    final r = rows.first;
    return {
      'totalSales': (r['totalSales'] as num).toDouble(),
      'totalProfit': (r['totalProfit'] as num).toDouble(),
    };
  }

  Future<List<ProductReportRow>> topProductsByRange({
    required int userId,
    required DateTime from,
    required DateTime to,
    int limit = 30,
  }) async {
    final db = await AppDb.get();
    final f = startOfDay(from).toIso8601String();
    final t = endOfDay(to).toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT 
        p.id AS productId,
        p.name AS productName,
        p.productImagePath AS productImagePath,
        COALESCE(SUM(oi.qty), 0) AS qty,
        COALESCE(SUM(oi.lineTotal), 0) AS sales,
        COALESCE(SUM(oi.lineProfit), 0) AS profit
      FROM order_items oi
      JOIN orders o ON o.id = oi.orderId
      JOIN products p ON p.id = oi.productId
      WHERE o.userId = ?
        AND o.status = 'paid'
        AND o.closedAt IS NOT NULL
        AND o.closedAt >= ?
        AND o.closedAt <= ?
      GROUP BY p.id, p.name, p.productImagePath
      ORDER BY sales DESC
      LIMIT ?
    ''',
      [userId, f, t, limit],
    );

    return rows.map((m) {
      return ProductReportRow(
        productId: m['productId'] as int,
        productName: (m['productName'] as String?) ?? '',
        productImagePath: m['productImagePath'] as String?,
        qty: (m['qty'] as num).toDouble(),
        sales: (m['sales'] as num).toDouble(),
        profit: (m['profit'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<CategoryReportRow>> topCategoriesByRange({
    required int userId,
    required DateTime from,
    required DateTime to,
    int limit = 30,
  }) async {
    final db = await AppDb.get();
    final f = startOfDay(from).toIso8601String();
    final t = endOfDay(to).toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT 
        c.id AS categoryId,
        c.name AS categoryName,
        COALESCE(SUM(oi.lineTotal), 0) AS sales,
        COALESCE(SUM(oi.lineProfit), 0) AS profit
      FROM order_items oi
      JOIN orders o ON o.id = oi.orderId
      JOIN products p ON p.id = oi.productId
      JOIN categories c ON c.id = p.categoryId
      WHERE o.userId = ?
        AND o.status = 'paid'
        AND o.closedAt IS NOT NULL
        AND o.closedAt >= ?
        AND o.closedAt <= ?
      GROUP BY c.id, c.name
      ORDER BY sales DESC
      LIMIT ?
    ''',
      [userId, f, t, limit],
    );

    return rows.map((m) {
      return CategoryReportRow(
        categoryId: m['categoryId'] as int,
        categoryName: (m['categoryName'] as String?) ?? '',
        sales: (m['sales'] as num).toDouble(),
        profit: (m['profit'] as num).toDouble(),
      );
    }).toList();
  }

  Future<List<OrderHistoryRow>> orderHistoryByRange({
    required int userId,
    required DateTime from,
    required DateTime to,
    int limit = 100,
  }) async {
    final db = await AppDb.get();
    final f = startOfDay(from).toIso8601String();
    final t = endOfDay(to).toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT 
        o.id AS orderId,
        o.closedAt AS closedAt,
        o.total AS total,
        o.profit AS profit,
        tc.name AS tableClientName,
        tc.type AS tableClientType
      FROM orders o
      LEFT JOIN tables_or_clients tc ON tc.id = o.tableClientId
      WHERE o.userId = ?
        AND o.status = 'paid'
        AND o.closedAt IS NOT NULL
        AND o.closedAt >= ?
        AND o.closedAt <= ?
      ORDER BY o.closedAt DESC
      LIMIT ?
    ''',
      [userId, f, t, limit],
    );

    return rows.map((m) {
      return OrderHistoryRow(
        orderId: m['orderId'] as int,
        closedAt: (m['closedAt'] as String?) ?? '',
        total: (m['total'] as num).toDouble(),
        profit: (m['profit'] as num).toDouble(),
        tableClientName: m['tableClientName'] as String?,
        tableClientType: m['tableClientType'] as String?,
      );
    }).toList();
  }

  // ✅ PARTE 5: ventas por método de pago
  // Devuelve: { 'cash': X, 'card': Y, 'virtual': Z }
  Future<Map<String, double>> totalsByPaymentMethod({
    required int userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final db = await AppDb.get();
    final f = startOfDay(from).toIso8601String();
    final t = endOfDay(to).toIso8601String();

    final rows = await db.rawQuery(
      '''
      SELECT 
        COALESCE(paymentMethod, 'cash') as pm,
        COALESCE(SUM(total), 0) as sales
      FROM orders
      WHERE userId = ?
        AND status = 'paid'
        AND closedAt IS NOT NULL
        AND closedAt >= ?
        AND closedAt <= ?
      GROUP BY pm
    ''',
      [userId, f, t],
    );

    double cash = 0, card = 0, virtual = 0;

    for (final r in rows) {
      final pm = (r['pm'] as String?) ?? 'cash';
      final sales = (r['sales'] as num).toDouble();

      if (pm == 'card') {
        card += sales;
      } else if (pm == 'virtual') {
        virtual += sales;
      } else {
        cash += sales;
      }
    }

    return {'cash': cash, 'card': card, 'virtual': virtual};
  }
}
