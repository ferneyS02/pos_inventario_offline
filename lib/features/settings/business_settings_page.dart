import 'package:flutter/material.dart';
import 'business_settings_service.dart';

class BusinessSettingsPage extends StatefulWidget {
  final int userId;
  const BusinessSettingsPage({super.key, required this.userId});

  @override
  State<BusinessSettingsPage> createState() => _BusinessSettingsPageState();
}

class _BusinessSettingsPageState extends State<BusinessSettingsPage> {
  final _svc = BusinessSettingsService();

  bool _loading = true;

  final _nit = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();

  final _prefix = TextEditingController();
  final _nextNo = TextEditingController();
  final _padding = TextEditingController();

  final _footer = TextEditingController();
  final _taxDefault = TextEditingController();

  String _receiptFormat = '80mm';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _svc.getOrCreate(widget.userId);

    _nit.text = s.nit ?? '';
    _address.text = s.address ?? '';
    _phone.text = s.phone ?? '';

    _prefix.text = s.invoicePrefix;
    _nextNo.text = s.nextInvoiceNumber.toString();
    _padding.text = s.invoicePadding.toString();

    _receiptFormat = s.receiptFormat;
    _footer.text = s.footerText ?? '';
    _taxDefault.text = s.taxRateDefault.toString();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final next = int.tryParse(_nextNo.text.trim()) ?? 1;
    final pad = int.tryParse(_padding.text.trim()) ?? 5;
    final tax = double.tryParse(_taxDefault.text.trim()) ?? 0;

    await _svc.update(widget.userId, {
      'nit': _nit.text.trim().isEmpty ? null : _nit.text.trim(),
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'invoicePrefix': _prefix.text.trim().isEmpty ? 'F-' : _prefix.text.trim(),
      'nextInvoiceNumber': next < 1 ? 1 : next,
      'invoicePadding': pad < 1 ? 1 : pad,
      'receiptFormat': _receiptFormat,
      'footerText': _footer.text.trim().isEmpty ? null : _footer.text.trim(),
      'taxRateDefault': tax < 0 ? 0 : tax,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ Configuración guardada')));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración del negocio')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text(
              'Datos del negocio',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nit,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'NIT (opcional)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Dirección (opcional)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Teléfono (opcional)',
              ),
            ),

            const SizedBox(height: 18),
            const Text(
              'Factura / Consecutivo',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _prefix,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Prefijo (Ej: F-)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nextNo,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Siguiente número (Ej: 1)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _padding,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Relleno ceros (Ej: 5 → 00001)',
              ),
            ),

            const SizedBox(height: 18),
            const Text(
              'Ticket / Impuestos',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              value: _receiptFormat,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Formato de impresión',
              ),
              items: const [
                DropdownMenuItem(
                  value: '80mm',
                  child: Text('Tirilla 80mm (POS)'),
                ),
                DropdownMenuItem(value: 'a4', child: Text('Hoja A4')),
              ],
              onChanged: (v) => setState(() => _receiptFormat = v ?? '80mm'),
            ),

            const SizedBox(height: 10),
            TextField(
              controller: _taxDefault,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Impuesto % por defecto (opcional)',
                hintText: 'Ej: 19',
              ),
            ),

            const SizedBox(height: 10),
            TextField(
              controller: _footer,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Pie de página (opcional)',
                hintText: 'Ej: Gracias por su compra',
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
