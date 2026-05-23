import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/utils/business_shop_location.dart';
import 'package:mauzo/utils/constants.dart';

/// Opens a Material-style dialog consistent with [showShopLocationEditorDialog].
Future<void> showAddBusinessEditorDialog(
  BuildContext navigatorContext, {
  required Future<void> Function({
    required String name,
    required String shopCountry,
    required String shopCity,
    required String shopStreet,
  }) onCreate,
}) async {
  await showDialog<void>(
    context: navigatorContext,
    useRootNavigator: true,
    builder: (ctx) => _AddBusinessDialog(onCreate: onCreate),
  );
}

class _AddBusinessDialog extends StatefulWidget {
  const _AddBusinessDialog({required this.onCreate});

  final Future<void> Function({
    required String name,
    required String shopCountry,
    required String shopCity,
    required String shopStreet,
  }) onCreate;

  @override
  State<_AddBusinessDialog> createState() => _AddBusinessDialogState();
}

class _AddBusinessDialogState extends State<_AddBusinessDialog> {
  late final TextEditingController _name;
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _street;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _country = TextEditingController(text: BusinessShopLocation.defaultCountry);
    _city = TextEditingController();
    _street = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    _country.dispose();
    _city.dispose();
    _street.dispose();
    super.dispose();
  }

  InputDecoration _decoration(BuildContext context, String label) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      errorSnackbar('fill_required_fields'.tr);
      return;
    }
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    try {
      await widget.onCreate(
        name: name,
        shopCountry: _country.text,
        shopCity: _city.text,
        shopStreet: _street.text,
      );
      if (!mounted) return;
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      errorSnackbar(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        Icons.add_business_rounded,
                        color: cs.onPrimaryContainer,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'add_new_business'.tr,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'add_business_dialog_hint'.tr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _name,
                  enabled: !_saving,
                  maxLength: 25,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(context, 'business_name'.tr).copyWith(
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'optional_shop_location'.tr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _country,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(context, 'shop_country'.tr),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _city,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: _decoration(context, 'shop_city'.tr),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _street,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: _decoration(context, 'shop_street'.tr),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(
                      onPressed:
                          _saving ? null : () => Navigator.of(context).pop(),
                      child: Text('cancel'.tr),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text('save'.tr),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
