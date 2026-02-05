class TableClient {
  final int id;
  final int userId;
  final String name;
  final String type; // 'table' | 'client'

  TableClient({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
  });

  factory TableClient.fromMap(Map<String, dynamic> m) => TableClient(
    id: m['id'] as int,
    userId: m['userId'] as int,
    name: (m['name'] as String?) ?? '',
    type: (m['type'] as String?) ?? 'table',
  );
}

class OrderItemView {
  final int id;
  final int productId;
  final String productName;
  final String? productImagePath;
  final double qty;
  final double unitPrice;
  final double unitCost;
  final double lineTotal;
  final double lineProfit;

  OrderItemView({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImagePath,
    required this.qty,
    required this.unitPrice,
    required this.unitCost,
    required this.lineTotal,
    required this.lineProfit,
  });
}
