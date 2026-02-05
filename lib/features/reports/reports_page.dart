import 'dart:io';
import 'package:flutter/material.dart';
import 'reports_models.dart';
import 'reports_service.dart';

class ReportsPage extends StatefulWidget {
  final int userId;
  const ReportsPage({super.key, required this.userId});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final _svc = ReportsService();

  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to = DateTime.now();

  bool _loading = true;

  double _totalSales = 0;
  double _totalProfit = 0;

  // ✅ PARTE 5: ventas por método de pago
  double _cashSales = 0;
  double _cardSales = 0;
  double _virtualSales = 0;

  List<ProductReportRow> _topProducts = [];
  List<CategoryReportRow> _topCategories = [];
  List<OrderHistoryRow> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _to = picked);
  }

  Future<void> _load() async {
    if (_from.isAfter(_to)) {
      final tmp = _from;
      _from = _to;
      _to = tmp;
    }

    setState(() => _loading = true);

    final totals = await _svc.totalsByRange(
      userId: widget.userId,
      from: _from,
      to: _to,
    );

    // ✅ PARTE 5: ventas por método
    final pm = await _svc.totalsByPaymentMethod(
      userId: widget.userId,
      from: _from,
      to: _to,
    );

    final topP = await _svc.topProductsByRange(
      userId: widget.userId,
      from: _from,
      to: _to,
      limit: 30,
    );
    final topC = await _svc.topCategoriesByRange(
      userId: widget.userId,
      from: _from,
      to: _to,
      limit: 30,
    );
    final hist = await _svc.orderHistoryByRange(
      userId: widget.userId,
      from: _from,
      to: _to,
      limit: 100,
    );

    setState(() {
      _totalSales = totals['totalSales'] ?? 0;
      _totalProfit = totals['totalProfit'] ?? 0;

      _cashSales = pm['cash'] ?? 0;
      _cardSales = pm['card'] ?? 0;
      _virtualSales = pm['virtual'] ?? 0;

      _topProducts = topP;
      _topCategories = topC;
      _history = hist;
      _loading = false;
    });
  }

  String _who(OrderHistoryRow o) {
    if (o.tableClientName == null || o.tableClientName!.trim().isEmpty) {
      return 'Sin mesa/cliente';
    }
    final type = o.tableClientType == 'client' ? 'Cliente' : 'Mesa';
    return '$type: ${o.tableClientName}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  // Rango de fechas
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
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickFrom,
                                child: Text('Desde: ${_d(_from)}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _pickTo,
                                child: Text('Hasta: ${_d(_to)}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.analytics_outlined),
                            label: const Text('Generar reporte'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Totales
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Ventas totales',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            Text(
                              _totalSales.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Ganancias',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                            Text(
                              _totalProfit.toStringAsFixed(2),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ✅ PARTE 5: Ventas por método
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Icon(Icons.payments_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Ventas por método',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(child: Text('Efectivo')),
                            Text(_cashSales.toStringAsFixed(2)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(child: Text('Tarjeta')),
                            Text(_cardSales.toStringAsFixed(2)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Expanded(child: Text('Virtual')),
                            Text(_virtualSales.toStringAsFixed(2)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Top productos
                  Row(
                    children: const [
                      Icon(Icons.inventory_2_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Top productos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_topProducts.isEmpty)
                    const Text('No hay ventas en este rango.')
                  else
                    ..._topProducts.map((p) {
                      return ListTile(
                        leading: p.productImagePath == null
                            ? const CircleAvatar(
                                child: Icon(Icons.inventory_2_outlined),
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(p.productImagePath!),
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                ),
                              ),
                        title: Text(p.productName),
                        subtitle: Text(
                          'Cant: ${p.qty.toStringAsFixed(0)} | Ventas: ${p.sales.toStringAsFixed(2)} | Gan: ${p.profit.toStringAsFixed(2)}',
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // Top categorías
                  Row(
                    children: const [
                      Icon(Icons.category_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Top categorías',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_topCategories.isEmpty)
                    const Text('No hay categorías con ventas en este rango.')
                  else
                    ..._topCategories.map((c) {
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.category_outlined),
                        ),
                        title: Text(c.categoryName),
                        subtitle: Text(
                          'Ventas: ${c.sales.toStringAsFixed(2)} | Gan: ${c.profit.toStringAsFixed(2)}',
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // Historial
                  Row(
                    children: const [
                      Icon(Icons.receipt_long_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Historial (últimas 100)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_history.isEmpty)
                    const Text('No hay ventas cerradas en este rango.')
                  else
                    ..._history.map((o) {
                      final dateOnly = o.closedAt.isEmpty
                          ? ''
                          : o.closedAt.split('T').first;
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt_long_outlined),
                        ),
                        title: Text(_who(o)),
                        subtitle: Text(
                          'Fecha: $dateOnly | Total: ${o.total.toStringAsFixed(2)} | Gan: ${o.profit.toStringAsFixed(2)}',
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}
