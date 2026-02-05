class ProductReportRow {
  final int productId;
  final String productName;
  final String? productImagePath;
  final double qty;
  final double sales;
  final double profit;

  ProductReportRow({
    required this.productId,
    required this.productName,
    required this.productImagePath,
    required this.qty,
    required this.sales,
    required this.profit,
  });
}

class CategoryReportRow {
  final int categoryId;
  final String categoryName;
  final double sales;
  final double profit;

  CategoryReportRow({
    required this.categoryId,
    required this.categoryName,
    required this.sales,
    required this.profit,
  });
}

class OrderHistoryRow {
  final int orderId;
  final String closedAt; // ISO string
  final double total;
  final double profit;
  final String? tableClientName;
  final String? tableClientType;

  OrderHistoryRow({
    required this.orderId,
    required this.closedAt,
    required this.total,
    required this.profit,
    required this.tableClientName,
    required this.tableClientType,
  });
}
