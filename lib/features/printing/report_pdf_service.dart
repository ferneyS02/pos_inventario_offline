import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../reports/reports_models.dart';

class ReportPdfService {
  Future<Uint8List> buildReportPdf({
    required String title,
    required String fromLabel,
    required String toLabel,
    required double totalSales,
    required double totalProfit,
    required double cashSales,
    required double cardSales,
    required double virtualSales,
    required List<ProductReportRow> topProducts,
    required List<CategoryReportRow> topCategories,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Rango: $fromLabel  →  $toLabel'),
          pw.SizedBox(height: 12),
          pw.Divider(),

          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Ventas totales:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                totalSales.toStringAsFixed(2),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Ganancias:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                totalProfit.toStringAsFixed(2),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Text(
            'Ventas por método',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Bullet(text: 'Efectivo: ${cashSales.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Tarjeta: ${cardSales.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Virtual: ${virtualSales.toStringAsFixed(2)}'),

          pw.SizedBox(height: 12),
          pw.Text(
            'Top Productos',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),

          // ✅ FIX: TableHelper.fromTextArray (en lugar de Table.fromTextArray)
          pw.TableHelper.fromTextArray(
            headers: const ['Producto', 'Cant', 'Ventas', 'Ganancia'],
            data: topProducts
                .take(30)
                .map(
                  (p) => [
                    p.productName,
                    p.qty.toStringAsFixed(0),
                    p.sales.toStringAsFixed(2),
                    p.profit.toStringAsFixed(2),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),

          pw.SizedBox(height: 12),
          pw.Text(
            'Top Categorías',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),

          // ✅ FIX: TableHelper.fromTextArray (en lugar de Table.fromTextArray)
          pw.TableHelper.fromTextArray(
            headers: const ['Categoría', 'Ventas', 'Ganancia'],
            data: topCategories
                .take(30)
                .map(
                  (c) => [
                    c.categoryName,
                    c.sales.toStringAsFixed(2),
                    c.profit.toStringAsFixed(2),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
        ],
      ),
    );

    return doc.save();
  }
}
