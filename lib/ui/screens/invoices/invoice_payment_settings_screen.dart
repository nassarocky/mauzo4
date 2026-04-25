import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/utils/constants.dart';

class InvoicePaymentSettingsScreen extends StatefulWidget {
  const InvoicePaymentSettingsScreen({Key? key}) : super(key: key);

  @override
  State<InvoicePaymentSettingsScreen> createState() =>
      _InvoicePaymentSettingsScreenState();
}

class _InvoicePaymentSettingsScreenState
    extends State<InvoicePaymentSettingsScreen> {
  final BusinessController _businessController = Get.find();
  late List<Map<String, dynamic>> _paymentDetails;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final raw = _businessController.business['invoicePaymentDetails'];
    _paymentDetails = raw != null
        ? List<Map<String, dynamic>>.from(
            (raw as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : [];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final businessId = _businessController.business['id'];
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .update({'invoicePaymentDetails': _paymentDetails});
      await _businessController.updateBusinessData();
      successSnackbar('Payment details saved');
    } catch (e) {
      errorSnackbar('Failed to save: $e');
    }
    setState(() => _saving = false);
  }

  void _addPaymentMethod(String type) {
    showDialog(
      context: context,
      builder: (context) => _AddPaymentMethodDialog(
        type: type,
        onAdd: (method) {
          setState(() {
            _paymentDetails.add({
              'id': DateTime.now().millisecondsSinceEpoch.toString(),
              'type': type,
              'provider': method['provider'],
              'number': method['number'],
              'showOnInvoice': true,
            });
          });
        },
      ),
    );
  }

  void _deleteAt(int index) {
    setState(() => _paymentDetails.removeAt(index));
  }

  void _toggleShowAt(int index, bool value) {
    setState(() => _paymentDetails[index]['showOnInvoice'] = value);
  }

  @override
  Widget build(BuildContext context) {
    final banks =
        _paymentDetails.where((e) => e['type'] == 'bank').toList();
    final mobile =
        _paymentDetails.where((e) => e['type'] == 'mobile').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Payment Details'),
        actions: [
          _saving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('Save',
                      style: TextStyle(color: Colors.white)),
                ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Add your bank accounts and mobile money numbers. '
                    'Toggle the switch to choose which ones appear on your invoice.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Bank Accounts ──────────────────────────────────────
          _SectionHeader(
            icon: Icons.account_balance,
            title: 'Bank Accounts',
            onAdd: () => _addPaymentMethod('bank'),
          ),
          const SizedBox(height: 8),
          if (banks.isEmpty)
            _EmptyHint(text: 'No bank accounts added yet')
          else
            ...banks.map((m) {
              final idx = _paymentDetails.indexOf(m);
              return _PaymentMethodTile(
                method: m,
                onDelete: () => _deleteAt(idx),
                onToggle: (v) => _toggleShowAt(idx, v),
              );
            }),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),

          // ── Mobile Money ───────────────────────────────────────
          _SectionHeader(
            icon: Icons.phone_android,
            title: 'Mobile Money (Lipa Namba)',
            onAdd: () => _addPaymentMethod('mobile'),
          ),
          const SizedBox(height: 8),
          if (mobile.isEmpty)
            _EmptyHint(text: 'No mobile money numbers added yet')
          else
            ...mobile.map((m) {
              final idx = _paymentDetails.indexOf(m);
              return _PaymentMethodTile(
                method: m,
                onDelete: () => _deleteAt(idx),
                onToggle: (v) => _toggleShowAt(idx, v),
              );
            }),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Supporting widgets
// ──────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onAdd;

  const _SectionHeader(
      {required this.icon, required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child:
          Text(text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  final Map<String, dynamic> method;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  const _PaymentMethodTile(
      {required this.method,
      required this.onDelete,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final isBank = method['type'] == 'bank';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isBank ? Colors.blue.shade50 : Colors.green.shade50,
          child: Icon(
            isBank ? Icons.account_balance : Icons.phone_android,
            color: isBank ? Colors.blue : Colors.green,
            size: 20,
          ),
        ),
        title: Text(method['provider'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(method['number'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Show', style: TextStyle(fontSize: 10)),
                Switch(
                  value: method['showOnInvoice'] ?? true,
                  onChanged: onToggle,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Add-payment-method dialog
// ──────────────────────────────────────────────────────────────────

class _AddPaymentMethodDialog extends StatefulWidget {
  final String type;
  final void Function(Map<String, String>) onAdd;

  const _AddPaymentMethodDialog(
      {required this.type, required this.onAdd});

  @override
  State<_AddPaymentMethodDialog> createState() =>
      _AddPaymentMethodDialogState();
}

class _AddPaymentMethodDialogState
    extends State<_AddPaymentMethodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _numberController = TextEditingController();
  String? _selectedProvider;

  static const _bankProviders = [
    'CRDB Bank',
    'NMB Bank',
    'NBC Bank',
    'Stanbic Bank',
    'Equity Bank',
    'KCB Bank',
    'Azania Bank',
    'Diamond Trust Bank',
    'Bank of Africa',
    'Exim Bank',
    'Standard Chartered',
    'PBZ Bank',
    'Other',
  ];

  static const _mobileProviders = [
    'M-Pesa (Vodacom)',
    'Tigo Pesa',
    'Airtel Money',
    'HaloPesa',
    'T-Pesa',
    'Other',
  ];

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBank = widget.type == 'bank';
    final providers = isBank ? _bankProviders : _mobileProviders;
    final numberLabel = isBank ? 'Account Number' : 'Lipa Namba / Number';
    final title = isBank ? 'Add Bank Account' : 'Add Mobile Money';

    return AlertDialog(
      title: Text(title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _selectedProvider,
              decoration: InputDecoration(
                labelText: isBank ? 'Bank Name' : 'Provider',
                border: const OutlineInputBorder(),
              ),
              items: providers
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              validator: (v) =>
                  v == null ? 'Please select a provider' : null,
              onChanged: (v) => setState(() => _selectedProvider = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _numberController,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                labelText: numberLabel,
                border: const OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Please enter a number' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onAdd({
                'provider': _selectedProvider!,
                'number': _numberController.text.trim(),
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
