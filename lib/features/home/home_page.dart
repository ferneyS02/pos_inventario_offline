import 'dart:io';
import 'package:flutter/material.dart';
import '../onboarding/store_service.dart';
import '../onboarding/store_setup_page.dart';
import '../onboarding/categories_page.dart';
import '../onboarding/products_page.dart';
import '../catalog/category_service.dart';
import '../catalog/product_service.dart';
import '../sales/tables_clients_page.dart';
import '../sales/sales_home_page.dart';
import '../reports/reports_page.dart';

// ✅ PARTE 5: Seguridad / Backup
import '../settings/security_page.dart';

class HomePage extends StatefulWidget {
  final int userId;
  final VoidCallback onLogout;

  const HomePage({super.key, required this.userId, required this.onLogout});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storeService = StoreService();
  final _catService = CategoryService();
  final _prodService = ProductService();

  Map<String, dynamic>? _user;
  int _catCount = 0;
  int _prodCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _user = await _storeService.getUser(widget.userId);
    _catCount = await _catService.count(widget.userId);
    _prodCount = await _prodService.countAll(widget.userId);

    if (mounted) setState(() => _loading = false);

    final storeName = (_user?['storeName'] as String?)?.trim() ?? '';
    if (storeName.isEmpty) {
      await _runWizard();
      await _load();
    }
  }

  Future<void> _runWizard() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StoreSetupPage(userId: widget.userId, isWizard: true),
      ),
    );
    if (ok != true) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final storeName = (_user?['storeName'] as String?) ?? '';
    final img = _user?['storeImagePath'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  Text(
                    storeName.isEmpty ? 'Mi negocio' : storeName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (img != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.file(File(img), fit: BoxFit.cover),
                      ),
                    )
                  else
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: const Center(child: Text('Sin imagen')),
                    ),

                  const SizedBox(height: 16),
                  Text('Categorías: $_catCount'),
                  Text('Productos: $_prodCount'),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SalesHomePage(userId: widget.userId),
                          ),
                        );
                        await _load();
                      },
                      icon: const Icon(Icons.point_of_sale),
                      label: const Text('Ventas'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                TablesClientsPage(userId: widget.userId),
                          ),
                        );
                        await _load();
                      },
                      icon: const Icon(Icons.table_restaurant),
                      label: const Text('Mesas / Clientes'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ReportsPage(userId: widget.userId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Reportes'),
                    ),
                  ),

                  // ✅ PARTE 5: Seguridad / Backup
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SecurityPage(userId: widget.userId),
                          ),
                        );
                      },
                      icon: const Icon(Icons.security_outlined),
                      label: const Text('Seguridad / Backup'),
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Divider(),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StoreSetupPage(
                              userId: widget.userId,
                              isWizard: false,
                            ),
                          ),
                        );
                        await _load();
                      },
                      child: const Text('Editar negocio'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CategoriesPage(
                              userId: widget.userId,
                              isWizard: false,
                            ),
                          ),
                        );
                        await _load();
                      },
                      child: const Text('Gestionar categorías'),
                    ),
                  ),
                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductsPage(
                              userId: widget.userId,
                              isWizard: false,
                            ),
                          ),
                        );
                        await _load();
                      },
                      child: const Text('Gestionar productos'),
                    ),
                  ),

                  const SizedBox(height: 18),
                  const Text(
                    '✅ Parte 5: Métodos de pago + Reportes por método + Seguridad/Backup + Recuperación offline.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}
