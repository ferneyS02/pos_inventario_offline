import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'register_page.dart';
import 'forgot_pin_page.dart';
import '../onboarding/store_setup_page.dart';
import '../onboarding/store_service.dart';

class LoginPage extends StatefulWidget {
  final void Function(int userId) onLoggedIn;
  const LoginPage({super.key, required this.onLoggedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  final _storeService = StoreService();

  final _phone = TextEditingController();
  final _pin = TextEditingController();
  bool _loading = false;

  Future<void> _doLogin() async {
    setState(() => _loading = true);
    try {
      final userId = await _auth.login(phone: _phone.text, pin: _pin.text);
      if (!mounted) return;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas')),
        );
        return;
      }

      final u = await _storeService.getUser(userId);
      if (!mounted) return;

      final storeName = (u?['storeName'] as String?)?.trim() ?? '';
      if (storeName.isEmpty) {
        final ok = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => StoreSetupPage(userId: userId, isWizard: true),
          ),
        );
        if (!mounted) return;
        if (ok != true) return;
      }

      widget.onLoggedIn(userId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _goRegister() async {
    final userId = await Navigator.push<int?>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterPage()),
    );
    if (!mounted) return;
    if (userId != null) widget.onLoggedIn(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar sesión')),
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
              decoration: const InputDecoration(labelText: 'PIN / Contraseña'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _doLogin,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Entrar'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _goRegister,
              child: const Text('Crear cuenta'),
            ),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ForgotPinPage()),
              ),
              child: const Text('Olvidé mi PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
