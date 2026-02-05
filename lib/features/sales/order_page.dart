import 'dart:io';
import 'package:flutter/material.dart';
import '../catalog/product_service.dart';
import '../catalog/models.dart' as cat;
import 'models.dart';
import 'sales_service.dart';

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
  double _total = 0;
  double _profit = 0;
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

  Future<String?> _askPaymentMethod() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Método de pago'),
        content: const Text('Selecciona cómo pagó el cliente:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cash'),
            child: const Text('Efectivo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'card'),
            child: const Text('Tarjeta'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'virtual'),
            child: const Text('Virtual'),
          ),
        ],
      ),
    );
  }

  Future<void> _closeSale() async {
    if (_orderId == null) return;

    final paymentMethod = await _askPaymentMethod();
    if (paymentMethod == null) return;

    try {
      await _sales.closeOrder(
        userId: widget.userId,
        orderId: _orderId!,
        paymentMethod: paymentMethod,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Venta cerrada y guardada')),
      );
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
                                  'Precio: ${it.unitPrice} | Gan/U: ${(it.unitPrice - it.unitCost)} | Subtotal: ${it.lineTotal}',
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
                            const Expanded(child: Text('Total')),
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
                            const Expanded(child: Text('Ganancia')),
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
