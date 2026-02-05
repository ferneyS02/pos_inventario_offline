import 'package:flutter/material.dart';
import '../auth/auth_service.dart';
import '../auth/recovery_codes_page.dart';
import '../backup/backup_page.dart';

class SecurityPage extends StatefulWidget {
  final int userId;
  const SecurityPage({super.key, required this.userId});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  final _auth = AuthService();

  final _current = TextEditingController();
  final _new1 = TextEditingController();
  final _new2 = TextEditingController();

  bool _loading = false;

  Future<void> _changePin() async {
    if (_new1.text != _new2.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Los PIN no coinciden')));
      return;
    }

    setState(() => _loading = true);
    try {
      final ok = await _auth.changePin(
        userId: widget.userId,
        currentPin: _current.text,
        newPin: _new1.text,
      );
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok ? '✅ PIN cambiado' : 'PIN actual incorrecto'),
        ),
      );

      if (ok) {
        _current.clear();
        _new1.clear();
        _new2.clear();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _regenCodes() async {
    setState(() => _loading = true);
    try {
      final codes = await _auth.regenerateRecoveryCodes(widget.userId);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => RecoveryCodesPage(
            codes: codes,
            onContinue: () => Navigator.pop(ctx, true),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguridad y Backup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BackupPage()),
                      ),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Backup (Exportar / Importar)'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cambiar PIN',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'PIN actual',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _new1,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Nuevo PIN',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _new2,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Confirmar nuevo PIN',
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _loading ? null : _changePin,
                child: const Text('Cambiar PIN'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Códigos de recuperación',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Puedes generar un nuevo set de 10 códigos (se reemplazan los anteriores).',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _regenCodes,
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('Generar nuevos códigos'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
