import 'dart:io';
import 'package:flutter/material.dart';
import '../catalog/product_service.dart';
import '../catalog/models.dart' as cat;
import 'models.dart';
import 'sales_service.dart';

// ✅ Parte 6/7: Vista previa / compartir factura PDF
import '../printing/receipt_preview_page.dart';

// ✅ Parte 7: Configuración del negocio (impuesto por defecto)
import '../settings/business_settings_service.dart';

class OrderPage extends StatefulWidget {
  final int userId;
  final TableClient? tableClient;

  const OrderPage({super.key, required this.userId, required this.tableClient});

  // (Reserva) ventas rápidas sin mesa
  const OrderPage.quick({super.key, required this.userId}) : tableClient = null;

  @override
  State<OrderPage> createState() => _OrderPageState();
}

class _OrderPageState extends State<OrderPage> {
  final _sales = SalesService();
  final _products = ProductService();

  int? _orderId;
  List<OrderItemView> _items = [];
  double _total = 0; // En orden abierta: subtotal
  double _profit = 0; // En orden abierta: ganancia base (items)
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final orderId = await _sales.getOrCreateOpenOrder(
      userId: widget.userId,
      tableClientId: widget.tableClient?.id,
    );
    _orderId = orderId;
    await _reload();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _reload() async {
    if (_orderId == null) return;
    _items = await _sales.listItems(_orderId!);
    final totals = await _sales.getTotals(_orderId!);
    _total = totals['total'] ?? 0;
    _profit = totals['profit'] ?? 0;
    if (mounted) setState(() {});
  }

  Future<void> _pickAndAddProduct() async {
    final q = TextEditingController();
    List<cat.Product> results = [];

    final selected = await showDialog<int?>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> doSearch() async {
              results = await _products.search(
                userId: widget.userId,
                q: q.text,
              );
              setStateDialog(() {});
            }

            return AlertDialog(
              title: const Text('Buscar producto'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: q,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Ej: Coca cola',
                      ),
                      onChanged: (_) => doSearch(),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: results.isEmpty
                          ? const Center(child: Text('Escribe para buscar...'))
                          : ListView.separated(
                              itemCount: results.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final p = results[i];
                                return ListTile(
                                  title: Text(p.name),
                                  subtitle: Text(
                                    'Stock: ${p.stockQty} | Precio: ${p.salePrice}',
                                  ),
                                  onTap: () => Navigator.pop(ctx, p.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selected == null) return;
    if (_orderId == null) return;

    await _sales.addProduct(orderId: _orderId!, productId: selected);
    await _reload();
  }

  Future<void> _changeQty(OrderItemView it, double newQty) async {
    if (_orderId == null) return;
    await _sales.setItemQty(orderId: _orderId!, itemId: it.id, qty: newQty);
    await _reload();
  }

  // ✅ Parte 6: Preguntar si desea ver/compartir factura PDF
  Future<bool?> _askSeeReceipt() async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Factura'),
        content: const Text('¿Deseas ver/compartir la factura en PDF?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeSale() async {
    if (_orderId == null) return;

    // ✅ Parte 7: cargar impuesto por defecto
    final settings = await BusinessSettingsService().getOrCreate(widget.userId);

    String paymentMethod = 'cash';
    final discountCtrl = TextEditingController(text: '0');
    final tipCtrl = TextEditingController(text: '0');
    final taxCtrl = TextEditingController(
      text: settings.taxRateDefault.toString(),
    );

    double parseNum(String s) => double.tryParse(s.trim()) ?? 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            final subtotal = _total; // orden abierta => subtotal
            final baseProfit = _profit;

            final discount = parseNum(discountCtrl.text);
            final tip = parseNum(tipCtrl.text);
            final taxRate = parseNum(taxCtrl.text);

            final safeDiscount = discount < 0 ? 0 : discount;
            final safeTip = tip < 0 ? 0 : tip;
            final safeTaxRate = taxRate < 0 ? 0 : taxRate;

            final taxAmount = subtotal * (safeTaxRate / 100.0);
            final totalFinal = subtotal - safeDiscount + safeTip + taxAmount;
            final profitFinal = baseProfit - safeDiscount + safeTip;

            return AlertDialog(
              title: const Text('Cerrar venta'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Método de pago'),
                    RadioListTile<String>(
                      value: 'cash',
                      groupValue: paymentMethod,
                      onChanged: (v) =>
                          setStateDialog(() => paymentMethod = v ?? 'cash'),
                      title: const Text('Efectivo'),
                    ),
                    RadioListTile<String>(
                      value: 'card',
                      groupValue: paymentMethod,
                      onChanged: (v) =>
                          setStateDialog(() => paymentMethod = v ?? 'card'),
                      title: const Text('Tarjeta'),
                    ),
                    RadioListTile<String>(
                      value: 'virtual',
                      groupValue: paymentMethod,
                      onChanged: (v) =>
                          setStateDialog(() => paymentMethod = v ?? 'virtual'),
                      title: const Text('Virtual'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Descuento (opcional)',
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: tipCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Propina (opcional)',
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: taxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Impuesto % (opcional)',
                      ),
                      onChanged: (_) => setStateDialog(() {}),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Expanded(child: Text('Subtotal')),
                              Text(subtotal.toStringAsFixed(2)),
                            ],
                          ),
                          Row(
                            children: [
                              const Expanded(child: Text('Impuesto')),
                              Text(taxAmount.toStringAsFixed(2)),
                            ],
                          ),
                          Row(
                            children: [
                              const Expanded(child: Text('Descuento')),
                              Text(safeDiscount.toStringAsFixed(2)),
                            ],
                          ),
                          Row(
                            children: [
                              const Expanded(child: Text('Propina')),
                              Text(safeTip.toStringAsFixed(2)),
                            ],
                          ),
                          const Divider(),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Total final',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                totalFinal.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Ganancia final',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(
                                profitFinal.toStringAsFixed(2),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Cerrar venta'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;

    try {
      final discount = parseNum(discountCtrl.text);
      final tip = parseNum(tipCtrl.text);
      final taxRate = parseNum(taxCtrl.text);

      await _sales.closeOrder(
        userId: widget.userId,
        orderId: _orderId!,
        paymentMethod: paymentMethod,
        discount: discount,
        tip: tip,
        taxRate: taxRate,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Venta cerrada y guardada')),
      );

      final see = await _askSeeReceipt();
      if (!mounted) return;

      if (see == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReceiptPreviewPage(orderId: _orderId!),
          ),
        );
        if (!mounted) return;
      }

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.tableClient == null
        ? 'Venta'
        : 'Venta - ${widget.tableClient!.name}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _items.isEmpty ? null : _closeSale,
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Cerrar venta',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _pickAndAddProduct,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar producto'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text('Agrega productos a la venta'),
                          )
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final it = _items[i];
                              final ganU = (it.unitPrice - it.unitCost);

                              return ListTile(
                                leading: it.productImagePath == null
                                    ? const CircleAvatar(
                                        child: Icon(Icons.inventory_2_outlined),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(it.productImagePath!),
                                          width: 44,
                                          height: 44,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                title: Text(it.productName),
                                subtitle: Text(
                                  'Precio: ${it.unitPrice.toStringAsFixed(2)} | Gan/U: ${ganU.toStringAsFixed(2)} | Subtotal: ${it.lineTotal.toStringAsFixed(2)}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      onPressed: () =>
                                          _changeQty(it, it.qty - 1),
                                      icon: const Icon(
                                        Icons.remove_circle_outline,
                                      ),
                                    ),
                                    Text(it.qty.toStringAsFixed(0)),
                                    IconButton(
                                      onPressed: () =>
                                          _changeQty(it, it.qty + 1),
                                      icon: const Icon(
                                        Icons.add_circle_outline,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Subtotal')),
                            Text(
                              _total.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(child: Text('Ganancia (base)')),
                            Text(
                              _profit.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _items.isEmpty ? null : _closeSale,
                            child: const Text('Cerrar venta'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
