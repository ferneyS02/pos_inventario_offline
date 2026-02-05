import 'package:flutter/material.dart';
import '../catalog/category_service.dart';
import '../catalog/models.dart';
import 'products_page.dart';

class CategoriesPage extends StatefulWidget {
  final int userId;
  final bool isWizard;
  const CategoriesPage({super.key, required this.userId, this.isWizard = true});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _service = CategoryService();
  final _name = TextEditingController();
  final _targetCount = TextEditingController();

  List<Category> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _items = await _service.list(widget.userId);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    await _service.create(
      userId: widget.userId,
      name: name,
      sortOrder: _items.length,
    );
    _name.clear();
    await _load();
  }

  Future<void> _delete(Category c) async {
    await _service.delete(c.id);
    await _load();
  }

  void _next() {
    if (widget.isWizard && _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Crea al menos 1 categoría')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductsPage(userId: widget.userId, isWizard: widget.isWizard),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = int.tryParse(_targetCount.text.trim());
    final progressText = (target != null && target > 0)
        ? 'Creadas: ${_items.length} / $target'
        : 'Creadas: ${_items.length}';

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text(
                    '¿Cuántas categorías de productos tiene? (opcional)',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _targetCount,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Ej: 5',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(progressText),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: 'Nombre de categoría',
                            hintText: 'Ej: Cervezas',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: _add,
                        child: const Text('Agregar'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(child: Text('Aún no hay categorías'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final c = _items[i];
                              return ListTile(
                                title: Text(c.name),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(c),
                                ),
                              );
                            },
                          ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      child: Text(
                        widget.isWizard ? 'Continuar a productos' : 'Volver',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
