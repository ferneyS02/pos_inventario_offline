import '../../core/db/app_db.dart';

class BusinessSettings {
  final int userId;
  final String? nit;
  final String? address;
  final String? phone;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final int invoicePadding;
  final String receiptFormat; // '80mm' | 'a4'
  final String? footerText;
  final double taxRateDefault;

  BusinessSettings({
    required this.userId,
    required this.nit,
    required this.address,
    required this.phone,
    required this.invoicePrefix,
    required this.nextInvoiceNumber,
    required this.invoicePadding,
    required this.receiptFormat,
    required this.footerText,
    required this.taxRateDefault,
  });

  factory BusinessSettings.fromMap(Map<String, dynamic> m) => BusinessSettings(
    userId: m['userId'] as int,
    nit: m['nit'] as String?,
    address: m['address'] as String?,
    phone: m['phone'] as String?,
    invoicePrefix: (m['invoicePrefix'] as String?) ?? 'F-',
    nextInvoiceNumber: (m['nextInvoiceNumber'] as int?) ?? 1,
    invoicePadding: (m['invoicePadding'] as int?) ?? 5,
    receiptFormat: (m['receiptFormat'] as String?) ?? '80mm',
    footerText: m['footerText'] as String?,
    taxRateDefault: (m['taxRateDefault'] as num?)?.toDouble() ?? 0,
  );
}

class BusinessSettingsService {
  Future<BusinessSettings> getOrCreate(int userId) async {
    final db = await AppDb.get();

    await db.insert('store_settings', {
      'userId': userId,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    final rows = await db.query(
      'store_settings',
      where: 'userId = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return BusinessSettings.fromMap(rows.first);
  }

  Future<void> update(int userId, Map<String, dynamic> data) async {
    final db = await AppDb.get();
    await db.update(
      'store_settings',
      data,
      where: 'userId = ?',
      whereArgs: [userId],
    );
  }
}
