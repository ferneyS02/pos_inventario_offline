import 'package:flutter/material.dart';
import 'auth_service.dart';

class ForgotPinPage extends StatefulWidget {
  const ForgotPinPage({super.key});

  @override
  State<ForgotPinPage> createState() => _ForgotPinPageState();
}

class _ForgotPinPageState extends State<ForgotPinPage> {
  final _auth = AuthService();

  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();

  bool _loading = false;

  Future<void> _recover() async {
    if (_pin1.text != _pin2.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Los PIN no coinciden')));
      return;
    }

    setState(() => _loading = true);
    try {
      final ok = await _auth.recoverWithCode(
        phone: _phone.text,
        recoveryCode: _code.text,
        newPin: _pin1.text,
      );

      if (!mounted) return;

      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Código inválido o ya usado')),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ PIN actualizado. Ahora inicia sesión.'),
        ),
      );
      Navigator.pop(context);
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
      appBar: AppBar(title: const Text('Recuperar PIN')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Recuperación OFFLINE usando un código de recuperación'),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Teléfono (usuario)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Código de recuperación',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin1,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Nuevo PIN',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pin2,
              obscureText: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Confirmar nuevo PIN',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _recover,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Recuperar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
