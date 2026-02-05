import 'package:flutter/material.dart';
import 'table_client_service.dart';
import 'models.dart';
import 'order_page.dart';

class TablesClientsPage extends StatefulWidget {
  final int userId;
  const TablesClientsPage({super.key, required this.userId});

  @override
  State<TablesClientsPage> createState() => _TablesClientsPageState();
}

class _TablesClientsPageState extends State<TablesClientsPage>
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

  Future<void> _add(String type) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'table' ? 'Nueva mesa' : 'Nuevo cliente'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            labelText: type == 'table' ? 'Nombre de mesa' : 'Nombre de cliente',
            hintText: type == 'table' ? 'Mesa 1' : 'Juan',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false), // ✅ usar ctx del dialog
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), // ✅ usar ctx del dialog
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    final name = ctrl.text.trim();
    ctrl.dispose();

    if (ok != true) return;
    if (name.isEmpty) return;

    await _svc.create(userId: widget.userId, type: type, name: name);
    await _load();
  }

  Future<void> _delete(TableClient tc) async {
    await _svc.delete(tc.id);
    await _load();
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

  Widget _list(List<TableClient> items) {
    if (items.isEmpty) return const Center(child: Text('Aún no hay registros'));

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final tc = items[i];
        return ListTile(
          title: Text(tc.name),
          leading: CircleAvatar(
            child: Icon(
              tc.type == 'table' ? Icons.table_restaurant : Icons.person,
            ),
          ),
          onTap: () => _openOrder(tc),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(tc),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesas / Clientes'),
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
              children: [_list(_tables), _list(_clients)],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final type = _tab.index == 0 ? 'table' : 'client';
          _add(type);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
