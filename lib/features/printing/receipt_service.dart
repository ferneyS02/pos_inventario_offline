import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/db/app_db.dart';

class ReceiptService {
  Future<Uint8List> buildReceiptPdf({required int orderId}) async {
    final db = await AppDb.get();

    final headerRows = await db.rawQuery(
      '''
      SELECT
        o.id as orderId,
        o.invoiceNo as invoiceNo,
        o.openedAt as openedAt,
        o.closedAt as closedAt,
        o.subtotal as subtotal,
        o.discount as discount,
        o.tip as tip,
        o.taxRate as taxRate,
        o.taxAmount as taxAmount,
        o.total as total,
        o.profit as profit,
        COALESCE(o.paymentMethod, 'cash') as paymentMethod,
        tc.name as tableClientName,
        tc.type as tableClientType,
        u.storeName as storeName,
        u.storeImagePath as storeImagePath,
        ss.nit as nit,
        ss.address as address,
        ss.phone as bizPhone,
        ss.receiptFormat as receiptFormat,
        ss.footerText as footerText
      FROM orders o
      JOIN users u ON u.id = o.userId
      LEFT JOIN tables_or_clients tc ON tc.id = o.tableClientId
      LEFT JOIN store_settings ss ON ss.userId = o.userId
      WHERE o.id = ?
      LIMIT 1
    ''',
      [orderId],
    );

    if (headerRows.isEmpty) throw Exception('No se encontró la venta');

    final h = headerRows.first;

    final storeName = (h['storeName'] as String?)?.trim() ?? 'Mi Negocio';
    final storeImagePath = h['storeImagePath'] as String?;
    final invoiceNo = (h['invoiceNo'] as String?)?.trim();
    final openedAt = h['openedAt'] as String?;
    final closedAt = h['closedAt'] as String?;
    final paymentMethod = (h['paymentMethod'] as String?) ?? 'cash';

    final subtotal = (h['subtotal'] as num?)?.toDouble() ?? 0;
    final discount = (h['discount'] as num?)?.toDouble() ?? 0;
    final tip = (h['tip'] as num?)?.toDouble() ?? 0;
    final taxRate = (h['taxRate'] as num?)?.toDouble() ?? 0;
    final taxAmount = (h['taxAmount'] as num?)?.toDouble() ?? 0;
    final total = (h['total'] as num?)?.toDouble() ?? 0;
    final profit = (h['profit'] as num?)?.toDouble() ?? 0;

    final tcName = h['tableClientName'] as String?;
    final tcType = h['tableClientType'] as String?;

    final nit = h['nit'] as String?;
    final address = h['address'] as String?;
    final bizPhone = h['bizPhone'] as String?;
    final receiptFormat = (h['receiptFormat'] as String?) ?? '80mm';
    final footerText = h['footerText'] as String?;

    final itemsRows = await db.rawQuery(
      '''
      SELECT
        p.name as productName,
        oi.qty as qty,
        oi.unitPrice as unitPrice,
        oi.lineTotal as lineTotal
      FROM order_items oi
      JOIN products p ON p.id = oi.productId
      WHERE oi.orderId = ?
      ORDER BY p.name ASC
    ''',
      [orderId],
    );

    pw.ImageProvider? logo;
    if (storeImagePath != null && storeImagePath.trim().isNotEmpty) {
      final f = File(storeImagePath);
      if (await f.exists()) logo = pw.MemoryImage(await f.readAsBytes());
    }

    String pmLabel(String pm) {
      if (pm == 'card') return 'Tarjeta';
      if (pm == 'virtual') return 'Virtual';
      return 'Efectivo';
    }

    String whoLabel() {
      if (tcName == null || tcName.trim().isEmpty) return 'Sin mesa/cliente';
      final t = (tcType == 'client') ? 'Cliente' : 'Mesa';
      return '$t: $tcName';
    }

    final doc = pw.Document();

    if (receiptFormat == 'a4') {
      doc.addPage(
        _buildA4(
          storeName: storeName,
          logo: logo,
          invoiceNo: invoiceNo,
          orderId: orderId,
          openedAt: openedAt,
          closedAt: closedAt,
          who: whoLabel(),
          nit: nit,
          address: address,
          bizPhone: bizPhone,
          payment: pmLabel(paymentMethod),
          itemsRows: itemsRows,
          subtotal: subtotal,
          taxRate: taxRate,
          taxAmount: taxAmount,
          discount: discount,
          tip: tip,
          total: total,
          profit: profit,
          footerText: footerText,
        ),
      );
    } else {
      doc.addPage(
        _build80mm(
          storeName: storeName,
          logo: logo,
          invoiceNo: invoiceNo,
          orderId: orderId,
          openedAt: openedAt,
          closedAt: closedAt,
          who: whoLabel(),
          nit: nit,
          address: address,
          bizPhone: bizPhone,
          payment: pmLabel(paymentMethod),
          itemsRows: itemsRows,
          subtotal: subtotal,
          taxRate: taxRate,
          taxAmount: taxAmount,
          discount: discount,
          tip: tip,
          total: total,
          profit: profit,
          footerText: footerText,
        ),
      );
    }

    return doc.save();
  }

  pw.Page _buildA4({
    required String storeName,
    required pw.ImageProvider? logo,
    required String? invoiceNo,
    required int orderId,
    required String? openedAt,
    required String? closedAt,
    required String who,
    required String? nit,
    required String? address,
    required String? bizPhone,
    required String payment,
    required List<Map<String, Object?>> itemsRows,
    required double subtotal,
    required double taxRate,
    required double taxAmount,
    required double discount,
    required double tip,
    required double total,
    required double profit,
    required String? footerText,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (logo != null)
                  pw.Container(
                    width: 64,
                    height: 64,
                    child: pw.ClipRRect(
                      horizontalRadius: 8,
                      verticalRadius: 8,
                      child: pw.Image(logo, fit: pw.BoxFit.cover),
                    ),
                  ),
                if (logo != null) pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        storeName,
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if ((nit ?? '').trim().isNotEmpty)
                        pw.Text(
                          'NIT: $nit',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if ((address ?? '').trim().isNotEmpty)
                        pw.Text(
                          'Dirección: $address',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if ((bizPhone ?? '').trim().isNotEmpty)
                        pw.Text(
                          'Tel: $bizPhone',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                    ],
                  ),
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Pago: $payment',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Factura: ${invoiceNo?.isNotEmpty == true ? invoiceNo! : '#$orderId'}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                    pw.Text(
                      'Cierre: ${closedAt ?? ''}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Text(who, style: const pw.TextStyle(fontSize: 10)),
            pw.Text(
              'Apertura: ${openedAt ?? ''}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),

            pw.Table.fromTextArray(
              headers: const ['Producto', 'Cant', 'Precio', 'Total'],
              data: itemsRows.map((r) {
                final name = (r['productName'] as String?) ?? '';
                final qty = (r['qty'] as num).toDouble();
                final unit = (r['unitPrice'] as num).toDouble();
                final line = (r['lineTotal'] as num).toDouble();
                return [
                  name,
                  qty.toStringAsFixed(0),
                  unit.toStringAsFixed(2),
                  line.toStringAsFixed(2),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
            ),

            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 260,
                  child: pw.Column(
                    children: [
                      _rowKV('Subtotal', subtotal),
                      _rowKV('Impuesto ($taxRate%)', taxAmount),
                      _rowKV('Descuento', discount),
                      _rowKV('Propina', tip),
                      pw.Divider(),
                      _rowKV('TOTAL', total, bold: true),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              'Ganancia (info)',
                              style: const pw.TextStyle(fontSize: 9),
                            ),
                          ),
                          pw.Text(
                            profit.toStringAsFixed(2),
                            style: const pw.TextStyle(fontSize: 9),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Divider(),
            pw.Text(
              (footerText ?? 'Gracias por su compra'),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        );
      },
    );
  }

  pw.Page _build80mm({
    required String storeName,
    required pw.ImageProvider? logo,
    required String? invoiceNo,
    required int orderId,
    required String? openedAt,
    required String? closedAt,
    required String who,
    required String? nit,
    required String? address,
    required String? bizPhone,
    required String payment,
    required List<Map<String, Object?>> itemsRows,
    required double subtotal,
    required double taxRate,
    required double taxAmount,
    required double discount,
    required double tip,
    required double total,
    required double profit,
    required String? footerText,
  }) {
    final w = 80 * PdfPageFormat.mm;

    // Altura aproximada (multiPage no es necesario aquí, pero garantizamos espacio)
    final baseMm = 120;
    final perItemMm = 7;
    final height =
        (baseMm + (itemsRows.length * perItemMm)).toDouble() * PdfPageFormat.mm;

    final format = PdfPageFormat(w, height);

    pw.Widget line(
      String text, {
      bool bold = false,
      double size = 9,
      pw.TextAlign align = pw.TextAlign.left,
    }) {
      return pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: size,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      );
    }

    return pw.Page(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(8, 10, 8, 10),
      build: (_) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            if (logo != null)
              pw.Center(
                child: pw.Container(
                  width: 54,
                  height: 54,
                  child: pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(logo, fit: pw.BoxFit.cover),
                  ),
                ),
              ),
            pw.SizedBox(height: 6),
            line(storeName, bold: true, size: 12, align: pw.TextAlign.center),
            if ((nit ?? '').trim().isNotEmpty)
              line('NIT: $nit', align: pw.TextAlign.center),
            if ((address ?? '').trim().isNotEmpty)
              line('Dir: $address', align: pw.TextAlign.center),
            if ((bizPhone ?? '').trim().isNotEmpty)
              line('Tel: $bizPhone', align: pw.TextAlign.center),

            pw.SizedBox(height: 6),
            pw.Divider(),

            line(
              'Factura: ${invoiceNo?.isNotEmpty == true ? invoiceNo! : '#$orderId'}',
              bold: true,
              align: pw.TextAlign.center,
            ),
            line('Pago: $payment', align: pw.TextAlign.center),
            line(who, align: pw.TextAlign.center),
            line(
              'Cierre: ${closedAt ?? ''}',
              size: 8,
              align: pw.TextAlign.center,
            ),

            pw.SizedBox(height: 6),
            pw.Divider(),

            // Encabezado items
            pw.Row(
              children: [
                pw.Expanded(
                  flex: 5,
                  child: line('Producto', bold: true, size: 8),
                ),
                pw.Expanded(
                  flex: 1,
                  child: line(
                    'C',
                    bold: true,
                    size: 8,
                    align: pw.TextAlign.right,
                  ),
                ),
                pw.Expanded(
                  flex: 2,
                  child: line(
                    'Val',
                    bold: true,
                    size: 8,
                    align: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),

            ...itemsRows.map((r) {
              final name = (r['productName'] as String?) ?? '';
              final qty = (r['qty'] as num).toDouble();
              final lineTotal = (r['lineTotal'] as num).toDouble();
              return pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  children: [
                    pw.Expanded(flex: 5, child: line(name, size: 8)),
                    pw.Expanded(
                      flex: 1,
                      child: line(
                        qty.toStringAsFixed(0),
                        size: 8,
                        align: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 2,
                      child: line(
                        lineTotal.toStringAsFixed(2),
                        size: 8,
                        align: pw.TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 6),
            pw.Divider(),

            _row80('Subtotal', subtotal),
            _row80('Impuesto ($taxRate%)', taxAmount),
            if (discount > 0) _row80('Descuento', discount),
            if (tip > 0) _row80('Propina', tip),
            pw.Divider(),
            _row80('TOTAL', total, bold: true),

            pw.SizedBox(height: 6),
            line(
              'Ganancia (info): ${profit.toStringAsFixed(2)}',
              size: 8,
              align: pw.TextAlign.center,
            ),

            pw.SizedBox(height: 8),
            pw.Divider(),
            line(
              (footerText ?? 'Gracias por su compra'),
              align: pw.TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  pw.Widget _rowKV(String k, double v, {bool bold = false}) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            k,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Text(
          v.toStringAsFixed(2),
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  pw.Widget _row80(String k, double v, {bool bold = false}) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            k,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Text(
          v.toStringAsFixed(2),
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
