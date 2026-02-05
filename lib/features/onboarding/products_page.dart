import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/files/image_store.dart';
import '../catalog/category_service.dart';
import '../catalog/product_service.dart';
import '../catalog/models.dart';

class ProductsPage extends StatefulWidget {
  final int userId;
  final bool isWizard;
  const ProductsPage({super.key, required this.userId, this.isWizard = true});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _catService = CategoryService();
  final _prodService = ProductService();
  final _imageStore = ImageStore();

  List<Category> _cats = [];
  Category? _selected;
  List<Product> _products = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCats();
  }

  Future<void> _loadCats() async {
    _cats = await _catService.list(widget.userId);
    _selected = _cats.isNotEmpty ? _cats.first : null;

    if (_selected != null) {
      _products = await _prodService.listByCategory(
        userId: widget.userId,
        categoryId: _selected!.id,
      );
    } else {
      _products = [];
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProducts() async {
    if (_selected == null) return;
    _products = await _prodService.listByCategory(
      userId: widget.userId,
      categoryId: _selected!.id,
    );
    if (mounted) setState(() {});
  }

  Future<void> _addProductDialog() async {
    if (_selected == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Primero crea categorías')));
      return;
    }

    final name = TextEditingController();
    final stock = TextEditingController(text: '0');
    final price = TextEditingController(text: '0');
    final profit = TextEditingController(text: '0');

    String? imagePath;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            void refresh() => setStateDialog(() {});

            Future<void> pickGalleryLocal() async {
              final p = await _imageStore.pickFromGalleryAndStore(
                folderName: 'products',
              );
              if (p != null) {
                imagePath = p;
                refresh();
              }
            }

            Future<void> takePhotoLocal() async {
              final p = await _imageStore.takePhotoAndStore(
                folderName: 'products',
              );
              if (p != null) {
                imagePath = p;
                refresh();
              }
            }

            return AlertDialog(
              title: Text('Nuevo producto (${_selected!.name})'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Nombre',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stock,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Cantidad (stock)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Precio de venta',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: profit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Ganancia por unidad',
                        helperText: 'Costo = Precio - Ganancia',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (imagePath != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Image.file(
                            File(imagePath!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: const Center(child: Text('Sin imagen')),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickGalleryLocal,
                            icon: const Icon(Icons.photo),
                            label: const Text('Galería'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: takePhotoLocal,
                            icon: const Icon(Icons.photo_camera),
                            label: const Text('Cámara'),
                          ),
                        ),
                      ],
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
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (ok != true) return;

    final n = name.text.trim();
    final st = double.tryParse(stock.text.trim()) ?? 0;
    final pr = double.tryParse(price.text.trim()) ?? 0;
    final pf = double.tryParse(profit.text.trim()) ?? 0;

    if (n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El producto debe tener nombre')),
      );
      return;
    }

    if (pf > pr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La ganancia no puede ser mayor que el precio'),
        ),
      );
      return;
    }

    final cost = pr - pf;

    await _prodService.create(
      userId: widget.userId,
      categoryId: _selected!.id,
      name: n,
      stockQty: st,
      salePrice: pr,
      costPrice: cost,
      imagePath: imagePath,
    );

    await _loadProducts();
  }

  Future<void> _finishWizard() async {
    final total = await _prodService.countAll(widget.userId);
    if (!mounted) return;

    if (widget.isWizard && total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos 1 producto para finalizar'),
        ),
      );
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Productos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_cats.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'No hay categorías. Regresa y crea al menos una categoría.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    DropdownButtonFormField<Category>(
                      initialValue: _selected, // ✅ (value está deprecated)
                      items: _cats
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: (c) async {
                        setState(() => _selected = c);
                        await _loadProducts();
                      },
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Categoría',
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _cats.isEmpty ? null : _addProductDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar producto'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _products.isEmpty
                        ? const Center(
                            child: Text('Sin productos en esta categoría'),
                          )
                        : ListView.separated(
                            itemCount: _products.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = _products[i];
                              return ListTile(
                                leading: p.productImagePath == null
                                    ? const CircleAvatar(
                                        child: Icon(Icons.inventory_2_outlined),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(p.productImagePath!),
                                          width: 42,
                                          height: 42,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                title: Text(p.name),
                                subtitle: Text(
                                  'Stock: ${p.stockQty} | Precio: ${p.salePrice} | Ganancia/U: ${p.profitPerUnit}',
                                ),
                              );
                            },
                          ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _finishWizard,
                      child: Text(
                        widget.isWizard ? 'Finalizar configuración' : 'Volver',
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
