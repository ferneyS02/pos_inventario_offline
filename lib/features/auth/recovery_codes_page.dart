import 'package:flutter/material.dart';

class RecoveryCodesPage extends StatelessWidget {
  final List<String> codes;
  final VoidCallback onContinue;

  const RecoveryCodesPage({
    super.key,
    required this.codes,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Códigos de recuperación')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Guarda estos códigos en un lugar seguro.\n'
              'Sirven para recuperar tu PIN SIN internet.\n\n'
              'Cada código se puede usar UNA sola vez.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: codes
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.vpn_key_outlined, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              c,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                child: const Text('Ya los guardé, continuar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
