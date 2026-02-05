import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final _svc = BackupService();
  bool _loading = false;

  Future<void> _export() async {
    setState(() => _loading = true);
    try {
      final file = await _svc.exportBackup();
      await Share.shareXFiles([XFile(file.path)], text: 'Backup POS Offline');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    setState(() => _loading = true);
    try {
      final ok = await _svc.importBackupFromZip();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? '✅ Backup restaurado' : 'No se pudo restaurar el backup',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Exporta un .zip con la base de datos y las imágenes.\n'
              'Útil para cambiar de teléfono o restaurar.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _export,
                icon: const Icon(Icons.upload_file),
                label: const Text('Exportar backup (.zip)'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _import,
                icon: const Icon(Icons.restore),
                label: const Text('Importar backup (.zip)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
