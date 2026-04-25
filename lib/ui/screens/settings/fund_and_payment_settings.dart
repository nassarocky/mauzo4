import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/services/fund_source_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FUND SOURCE SETTINGS SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class FundSourceSettingsScreen extends StatefulWidget {
  const FundSourceSettingsScreen({Key? key}) : super(key: key);

  @override
  State<FundSourceSettingsScreen> createState() =>
      _FundSourceSettingsScreenState();
}

class _FundSourceSettingsScreenState extends State<FundSourceSettingsScreen> {
  final _service = FundSourceService();
  late final BusinessController _bc;
  bool _loading = true;

  String get _bizId => _bc.businessId.value;

  @override
  void initState() {
    super.initState();
    _bc = Get.find<BusinessController>();
    _reload();
  }

  Future<void> _reload() async {
    if (mounted) setState(() => _loading = true);
    try {
      final list = await _service.loadFundSources(_bizId);
      _bc.reloadFundSources(list);
    } catch (e) {
      Get.snackbar('Error', 'Could not load fund sources: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _OptionsSettingsScreen(
      title: 'Fund Sources',
      addButtonLabel: 'Add fund source',
      fabHeroTag: 'settings_fund_sources_add',
      subtitle:
          'Accounts for money in and out: expenses, checkout payments, payroll, and debt payments (e.g. Cash, Bank, M-Pesa). The checkout screen still says "Payment method" but uses this list. Cash cannot be renamed.',
      items: _bc.allFundSources,
      loading: _loading,
      onAdd: (label, ledgerType) async {
        if (_bizId.isEmpty) {
          Get.snackbar('Error', 'No business selected. Open the app from home first.',
              backgroundColor: Colors.red, colorText: Colors.white);
          return;
        }
        await _service.addFundSource(
            businessId: _bizId, label: label, ledgerType: ledgerType);
        await _reload();
      },
      onRename: (id, label) async {
        await _service.updateFundSource(id,
            businessId: _bizId, label: label);
        await _reload();
      },
      onToggle: (id, active) async {
        await _service.updateFundSource(id,
            businessId: _bizId, isActive: active);
        await _reload();
      },
      onDelete: (id) async {
        await _service.deleteFundSource(id, businessId: _bizId);
        await _reload();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED INTERNAL SCREEN WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _OptionsSettingsScreen extends StatelessWidget {
  final String title;
  final String addButtonLabel;
  final String fabHeroTag;
  final String subtitle;
  final List<Map<String, dynamic>> items;
  final bool loading;
  final Future<void> Function(String label, String ledgerType) onAdd;
  final Future<void> Function(String id, String label) onRename;
  final Future<void> Function(String id, bool active) onToggle;
  final Future<void> Function(String id) onDelete;

  const _OptionsSettingsScreen({
    required this.title,
    required this.addButtonLabel,
    required this.fabHeroTag,
    required this.subtitle,
    required this.items,
    required this.loading,
    required this.onAdd,
    required this.onRename,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    void openAdd() => _showAddDialog(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: fabHeroTag,
        tooltip: addButtonLabel,
        onPressed: openAdd,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          color: Colors.blue.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(subtitle,
                            style: const TextStyle(fontSize: 13)),
                      ),
                    ],
                  ),
                ),
                if (items.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No options yet.',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ...items.map((item) => _ItemTile(
                        item: item,
                        onRename: item['isPermanent'] == true
                            ? null
                            : (label) => onRename(item['id'].toString(), label),
                        onToggle: item['isPermanent'] == true
                            ? null
                            : (v) => onToggle(item['id'].toString(), v),
                        // Cash row is permanent (cannot delete).
                        onDelete: item['isPermanent'] == true
                            ? null
                            : () => onDelete(item['id'].toString()),
                      )),
              ],
            ),
    );
  }

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddOptionDialog(onAdd: onAdd),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM TILE
// ─────────────────────────────────────────────────────────────────────────────

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final Future<void> Function(String label)? onRename;
  final Future<void> Function(bool active)? onToggle;
  final Future<void> Function()? onDelete;

  const _ItemTile({
    required this.item,
    this.onRename,
    this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isPermanent = item['isPermanent'] == true;
    final isActive = item['isActive'] != false;
    final ledger = item['ledgerType']?.toString() ?? 'cash';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              isPermanent ? Colors.amber.shade50 : Colors.grey.shade100,
          child: Icon(
            isPermanent ? Icons.lock_outline : Icons.label_outline,
            size: 18,
            color: isPermanent ? Colors.amber.shade700 : Colors.grey,
          ),
        ),
        title: Text(
          item['label']?.toString() ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive ? null : Colors.grey,
          ),
        ),
        subtitle: Text(
          _typeLabel(ledger),
          style: TextStyle(
            fontSize: 12,
            color: _typeColor(ledger),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPermanent && onToggle != null)
              Switch(
                value: isActive,
                onChanged: onToggle,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            if (!isPermanent && onRename != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 20),
                onPressed: () => _showRenameDialog(context),
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: Colors.red),
                onPressed: () => _confirmDelete(context),
              ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String ledger) {
    switch (ledger) {
      case 'bank':
        return 'Bank / Card';
      case 'mobile':
        return 'Mobile Money';
      default:
        return 'Cash';
    }
  }

  Color _typeColor(String ledger) {
    switch (ledger) {
      case 'bank':
        return Colors.blue.shade700;
      case 'mobile':
        return Colors.green.shade700;
      default:
        return Colors.orange.shade700;
    }
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: item['label']?.toString() ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                onRename!(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Delete "${item['label']}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              onDelete!();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD OPTION DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _AddOptionDialog extends StatefulWidget {
  final Future<void> Function(String label, String ledgerType) onAdd;
  const _AddOptionDialog({required this.onAdd});

  @override
  State<_AddOptionDialog> createState() => _AddOptionDialogState();
}

class _AddOptionDialogState extends State<_AddOptionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelCtrl = TextEditingController();
  String _type = 'cash';
  bool _saving = false;

  static const _typeOptions = [
    {
      'value': 'cash',
      'label': 'Cash',
      'hint': 'Physical cash (notes & coins)',
    },
    {
      'value': 'bank',
      'label': 'Bank / Card',
      'hint': 'Bank transfer, cheque, POS card',
    },
    {
      'value': 'mobile',
      'label': 'Mobile Money',
      'hint': 'M-Pesa, Airtel Money, Tigo Pesa, etc.',
    },
  ];

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedHint = _typeOptions
        .firstWhere((o) => o['value'] == _type,
            orElse: () => _typeOptions.first)['hint'] as String;

    return AlertDialog(
      title: const Text('Add Option'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _labelCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Name (e.g. NMB Bank, M-Pesa)',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a name' : null,
            ),
            const SizedBox(height: 16),
            const Text('Type',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 8),
            ..._typeOptions.map((o) => RadioListTile<String>(
                  value: o['value'] as String,
                  groupValue: _type,
                  title: Text(o['label'] as String),
                  subtitle: Text(o['hint'] as String,
                      style: const TextStyle(fontSize: 12)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) =>
                      setState(() => _type = v ?? 'cash'),
                )),
            if (selectedHint.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(selectedHint,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _saving = true);
                  try {
                    await widget.onAdd(_labelCtrl.text.trim(), _type);
                    if (mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      Get.snackbar(
                        'Error',
                        e.toString(),
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                      );
                    }
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Add'),
        ),
      ],
    );
  }
}
