import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'receipt_service.dart';
import 'pdf_share.dart';

class ReceiptPreviewPage extends StatefulWidget {
  final int orderId;
  const ReceiptPreviewPage({super.key, required this.orderId});

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  final _svc = ReceiptService();
  late final Future<Uint8List> _pdfFuture;

  @override
  void initState() {
    super.initState();
    _pdfFuture = _svc.buildReceiptPdf(orderId: widget.orderId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Factura #${widget.orderId}')),
      body: FutureBuilder<Uint8List>(
        future: _pdfFuture,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final bytes = snap.data!;

          return PdfPreview(
            build: (_) async => bytes,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            actions: [
              PdfPreviewAction(
                icon: const Icon(Icons.share_outlined),
                onPressed: (context, build, pageFormat) async {
                  await PdfShare.shareBytes(
                    bytes,
                    filename: 'factura_${widget.orderId}.pdf',
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
