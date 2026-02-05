import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/files/image_store.dart';
import 'store_service.dart';
import 'categories_page.dart';

class StoreSetupPage extends StatefulWidget {
  final int userId;
  final bool isWizard;
  const StoreSetupPage({super.key, required this.userId, this.isWizard = true});

  @override
  State<StoreSetupPage> createState() => _StoreSetupPageState();
}

class _StoreSetupPageState extends State<StoreSetupPage> {
  final _storeService = StoreService();
  final _imageStore = ImageStore();

  final _name = TextEditingController();
  String? _imagePath;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final user = await _storeService.getUser(widget.userId);
    if (user != null) {
      _name.text = (user['storeName'] as String?) ?? '';
      _imagePath = user['storeImagePath'] as String?;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickGallery() async {
    final p = await _imageStore.pickFromGalleryAndStore(folderName: 'store');
    if (p == null) return;
    setState(() => _imagePath = p);
  }

  Future<void> _takePhoto() async {
    final p = await _imageStore.takePhotoAndStore(folderName: 'store');
    if (p == null) return;
    setState(() => _imagePath = p);
  }

  Future<void> _saveAndNext() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre del establecimiento')),
      );
      return;
    }

    await _storeService.updateStore(
      userId: widget.userId,
      storeName: name,
      storeImagePath: _imagePath,
    );

    if (!mounted) return;

    if (widget.isWizard) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CategoriesPage(userId: widget.userId, isWizard: true),
        ),
      );
    } else {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configurar negocio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Nombre del establecimiento'),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ej: Tienda Don Ferney',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Logo o foto del local (opcional)'),
            const SizedBox(height: 8),

            if (_imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.file(
                    File(_imagePath!),
                    fit: BoxFit.cover, // ✅ no deforma
                  ),
                ),
              )
            else
              Container(
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: const Center(child: Text('Sin imagen')),
              ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickGallery,
                    icon: const Icon(Icons.photo),
                    label: const Text('Galería'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Cámara'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveAndNext,
                child: Text(widget.isWizard ? 'Continuar' : 'Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
