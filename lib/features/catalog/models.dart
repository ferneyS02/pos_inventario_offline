class Category {
  final int id;
  final int userId;
  final String name;
  final int sortOrder;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.sortOrder,
  });

  factory Category.fromMap(Map<String, dynamic> m) => Category(
    id: m['id'] as int,
    userId: m['userId'] as int,
    name: (m['name'] as String?) ?? '',
    sortOrder: (m['sortOrder'] as int?) ?? 0,
  );
}

class Product {
  final int id;
  final int userId;
  final int categoryId;
  final String name;
  final double stockQty;
  final double salePrice;
  final double costPrice;
  final String? productImagePath;

  Product({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.name,
    required this.stockQty,
    required this.salePrice,
    required this.costPrice,
    required this.productImagePath,
  });

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'] as int,
    userId: m['userId'] as int,
    categoryId: m['categoryId'] as int,
    name: (m['name'] as String?) ?? '',
    stockQty: (m['stockQty'] as num?)?.toDouble() ?? 0,
    salePrice: (m['salePrice'] as num?)?.toDouble() ?? 0,
    costPrice: (m['costPrice'] as num?)?.toDouble() ?? 0,
    productImagePath: m['productImagePath'] as String?,
  );

  double get profitPerUnit => salePrice - costPrice;
}
