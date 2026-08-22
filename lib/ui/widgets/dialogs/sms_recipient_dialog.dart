import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/supplier_controller.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/models/supplier_model.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/sms_phone.dart';

enum SmsRecipientKind { client, supplier }

class SmsRecipientChoice {
  final String phone;
  final String name;
  final String? clientId;
  final String? supplierId;

  const SmsRecipientChoice({
    required this.phone,
    required this.name,
    this.clientId,
    this.supplierId,
  });
}

class _ListContact {
  final String id;
  final String name;
  final String phone;

  const _ListContact({
    required this.id,
    required this.name,
    required this.phone,
  });
}

Future<String?> showSmsPhoneOnlyDialog({
  required BuildContext context,
  required String title,
  String? hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _SmsPhoneOnlyDialog(
      title: title,
      hint: hint,
    ),
  );
}

class _SmsPhoneOnlyDialog extends StatefulWidget {
  const _SmsPhoneOnlyDialog({
    required this.title,
    this.hint,
  });

  final String title;
  final String? hint;

  @override
  State<_SmsPhoneOnlyDialog> createState() => _SmsPhoneOnlyDialogState();
}

class _SmsPhoneOnlyDialogState extends State<_SmsPhoneOnlyDialog> {
  final _phoneCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final phone = _phoneCtrl.text.trim();
    if (!isValidSmsPhone(phone)) {
      setState(() => _error = 'sms_phone_required'.tr);
      return;
    }
    Navigator.pop(context, phone);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2430) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: primaryUltraLightColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.sms_outlined, color: primaryColor, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              widget.hint ?? 'sms_enter_phone_hint'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _phoneCtrl,
              autofocus: true,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'phone'.tr,
                hintText: '0712 345 678',
                prefixIcon: const Icon(Icons.phone_outlined, color: primaryColor),
                errorText: _error,
                filled: true,
                fillColor: isDark ? const Color(0xFF0E141E) : primaryUltraLightColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryColor, width: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('send'.tr),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

Future<SmsRecipientChoice?> showSmsRecipientDialog({
  required BuildContext context,
  required String title,
  Client? savedClient,
  Supplier? savedSupplier,
  SmsRecipientKind kind = SmsRecipientKind.client,
}) {
  return showDialog<SmsRecipientChoice>(
    context: context,
    builder: (ctx) => _SmsRecipientDialog(
      title: title,
      savedClient: savedClient,
      savedSupplier: savedSupplier,
      kind: kind,
    ),
  );
}

class _SmsRecipientDialog extends StatefulWidget {
  const _SmsRecipientDialog({
    required this.title,
    required this.kind,
    this.savedClient,
    this.savedSupplier,
  });

  final String title;
  final SmsRecipientKind kind;
  final Client? savedClient;
  final Supplier? savedSupplier;

  @override
  State<_SmsRecipientDialog> createState() => _SmsRecipientDialogState();
}

class _SmsRecipientDialogState extends State<_SmsRecipientDialog> {
  /// saved | list | manual
  late String _mode;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  _ListContact? _picked;

  bool get _hasSaved {
    final phone = widget.savedClient?.phone ?? widget.savedSupplier?.phone ?? '';
    return isValidSmsPhone(phone);
  }

  String get _savedName =>
      widget.savedClient?.name ?? widget.savedSupplier?.name ?? '';

  String get _savedPhone =>
      widget.savedClient?.phone ?? widget.savedSupplier?.phone ?? '';

  List<_ListContact> get _allContacts {
    if (widget.kind == SmsRecipientKind.supplier) {
      if (!Get.isRegistered<SupplierController>()) return const [];
      return Get.find<SupplierController>()
          .suppliers
          .map((s) => _ListContact(id: s.id, name: s.name, phone: s.phone))
          .where((c) => c.name.trim().isNotEmpty)
          .toList();
    }
    if (!Get.isRegistered<ClientController>()) return const [];
    return Get.find<ClientController>()
        .clients
        .map((c) => _ListContact(id: c.id, name: c.name, phone: c.phone))
        .where((c) => c.name.trim().isNotEmpty)
        .toList();
  }

  List<_ListContact> get _filteredContacts {
    final q = _searchCtrl.text.trim().toLowerCase();
    final all = _allContacts;
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.name.toLowerCase().contains(q) || c.phone.toLowerCase().contains(q))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _mode = _hasSaved ? 'saved' : 'list';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_mode == 'saved' && _hasSaved) {
      Navigator.pop(
        context,
        SmsRecipientChoice(
          phone: _savedPhone,
          name: _savedName,
          clientId: widget.savedClient?.id,
          supplierId: widget.savedSupplier?.id,
        ),
      );
      return;
    }
    if (_mode == 'list') {
      final picked = _picked;
      if (picked == null || !isValidSmsPhone(picked.phone)) {
        errorSnackbar('sms_pick_contact_required'.tr);
        return;
      }
      Navigator.pop(
        context,
        SmsRecipientChoice(
          phone: picked.phone,
          name: picked.name,
          clientId: widget.kind == SmsRecipientKind.client ? picked.id : null,
          supplierId:
              widget.kind == SmsRecipientKind.supplier ? picked.id : null,
        ),
      );
      return;
    }
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || !isValidSmsPhone(phone)) {
      errorSnackbar('sms_fill_new_recipient'.tr);
      return;
    }
    Navigator.pop(
      context,
      SmsRecipientChoice(phone: phone, name: name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredContacts;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasSaved)
                RadioListTile<String>(
                  value: 'saved',
                  groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v ?? 'saved'),
                  title: Text('sms_saved_contact'.tr),
                  subtitle: Text('$_savedName\n$_savedPhone'),
                ),
              RadioListTile<String>(
                value: 'list',
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v ?? 'list'),
                title: Text(
                  widget.kind == SmsRecipientKind.supplier
                      ? 'sms_pick_supplier'.tr
                      : 'sms_pick_client'.tr,
                ),
              ),
              RadioListTile<String>(
                value: 'manual',
                groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v ?? 'manual'),
                title: Text('sms_new_number'.tr),
              ),
              if (_mode == 'list') ...[
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'sms_search_contact'.tr,
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: filtered.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('not_found'.tr),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final c = filtered[index];
                            final selected = _picked?.id == c.id;
                            return ListTile(
                              dense: true,
                              selected: selected,
                              title: Text(c.name),
                              subtitle: Text(
                                c.phone.isEmpty ? 'sms_no_phone'.tr : c.phone,
                              ),
                              onTap: isValidSmsPhone(c.phone)
                                  ? () => setState(() => _picked = c)
                                  : () => errorSnackbar('sms_fill_new_recipient'.tr),
                            );
                          },
                        ),
                ),
              ],
              if (_mode == 'manual') ...[
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: 'name'.tr),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'phone'.tr),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text('send'.tr),
        ),
      ],
    );
  }
}
