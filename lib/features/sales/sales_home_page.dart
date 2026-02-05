import 'package:flutter/material.dart';
import 'table_client_service.dart';
import 'models.dart';
import 'order_page.dart';

class SalesHomePage extends StatefulWidget {
  final int userId;
  const SalesHomePage({super.key, required this.userId});

  @override
  State<SalesHomePage> createState() => _SalesHomePageState();
}

class _SalesHomePageState extends State<SalesHomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _svc = TableClientService();

  List<TableClient> _tables = [];
  List<TableClient> _clients = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose(); // ✅ CLAVE
    super.dispose();
  }

  Future<void> _load() async {
    _tables = await _svc.list(userId: widget.userId, type: 'table');
    _clients = await _svc.list(userId: widget.userId, type: 'client');
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openOrder(TableClient tc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderPage(userId: widget.userId, tableClient: tc),
      ),
    );
    await _load();
  }

  Widget _list(List<TableClient> items, IconData icon) {
    if (items.isEmpty) {
      return const Center(
        child: Text('No hay registros. Crea mesas o clientes.'),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final tc = items[i];
        return ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(tc.name),
          onTap: () => _openOrder(tc),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ventas'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Mesas'),
            Tab(text: 'Clientes'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _list(_tables, Icons.table_restaurant),
                _list(_clients, Icons.person),
              ],
            ),
    );
  }
}
