import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'recovery_codes_page.dart';
import '../onboarding/store_setup_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = AuthService();
  final _phone = TextEditingController();
  final _pin = TextEditingController();
  final _pin2 = TextEditingController();
  bool _loading = false;

  Future<void> _doRegister() async {
    if (_pin.text != _pin2.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Los PIN no coinciden')));
      return;
    }

    setState(() => _loading = true);
    try {
      final userId = await _auth.register(phone: _phone.text, pin: _pin.text);
      if (!mounted) return;

      final codes = await _auth.regenerateRecoveryCodes(userId);
      if (!mounted) return;

      final codesOk = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (ctx) => RecoveryCodesPage(
            codes: codes,
            onContinue: () => Navigator.pop(ctx, true),
          ),
        ),
      );
      if (!mounted) return;

      if (codesOk != true) return;

      final ok = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => StoreSetupPage(userId: userId, isWizard: true),
        ),
      );
      if (!mounted) return;

      if (ok == true) Navigator.pop(context, userId);
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
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Número de teléfono',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Crear PIN / Contraseña',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin2,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmar PIN / Contraseña',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _doRegister,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Crear cuenta y configurar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
