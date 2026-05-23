import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/utils/business_shop_location.dart';
import 'package:mauzo/utils/constants.dart';

/// Wait until dialog routes + inherited widgets finish teardown before touching
/// [BusinessController] or overlays (avoids `_dependents.isEmpty` asserts).
void _scheduleAfterDialogDisposed(
  BuildContext rootContext,
  Map<String, dynamic> patch,
) {
  void defer(void Function() fn, int framesLeft) {
    if (framesLeft <= 0) {
      fn();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => defer(fn, framesLeft - 1));
  }

  defer(() {
    () async {
      try {
        final bc = Get.find<BusinessController>();
        bc.mergeShopLocationPatch(patch);
        await bc.updateBusinessData();
        if (!rootContext.mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(rootContext);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text('shop_location_saved'.tr),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        errorSnackbar(e.toString());
      }
    }();
  }, 3);
}

Future<void> showShopLocationEditorDialog(BuildContext navigatorContext) async {
  final bc = Get.find<BusinessController>();
  final id = bc.businessId.value.trim();
  if (id.isEmpty) return;

  final initialCountry =
      (bc.business[BusinessShopLocation.firestoreCountryKey]?.toString().trim().isNotEmpty ??
              false)
          ? bc.business[BusinessShopLocation.firestoreCountryKey].toString()
          : BusinessShopLocation.defaultCountry;
  final initialCity =
      bc.business[BusinessShopLocation.firestoreCityKey]?.toString() ?? '';
  final initialStreet =
      bc.business[BusinessShopLocation.firestoreStreetKey]?.toString() ?? '';

  await showDialog<void>(
    context: navigatorContext,
    useRootNavigator: true,
    builder: (ctx) => _ShopLocationEditorDialog(
      navigatorContext: navigatorContext,
      businessId: id,
      initialCountry: initialCountry,
      initialCity: initialCity,
      initialStreet: initialStreet,
    ),
  );
}

class _ShopLocationEditorDialog extends StatefulWidget {
  const _ShopLocationEditorDialog({
    required this.navigatorContext,
    required this.businessId,
    required this.initialCountry,
    required this.initialCity,
    required this.initialStreet,
  });

  final BuildContext navigatorContext;
  final String businessId;
  final String initialCountry;
  final String initialCity;
  final String initialStreet;

  @override
  State<_ShopLocationEditorDialog> createState() =>
      _ShopLocationEditorDialogState();
}

class _ShopLocationEditorDialogState extends State<_ShopLocationEditorDialog> {
  late final TextEditingController _country;
  late final TextEditingController _city;
  late final TextEditingController _street;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _country = TextEditingController(text: widget.initialCountry);
    _city = TextEditingController(text: widget.initialCity);
    _street = TextEditingController(text: widget.initialStreet);
  }

  @override
  void dispose() {
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

  Future<void> _save() async {
    final patch = BusinessShopLocation.firestoreFields(
      country: _country.text,
      city: _city.text,
      street: _street.text,
    );
    setState(() => _saving = true);
    final navigator = Navigator.of(context);
    final rootCtx = widget.navigatorContext;
    try {
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(widget.businessId)
          .set(patch, SetOptions(merge: true));
      if (!mounted) return;
      navigator.pop();
      if (!rootCtx.mounted) return;
      _scheduleAfterDialogDisposed(rootCtx, patch);
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
                        Icons.storefront_rounded,
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
                            'shop_location_dialog_title'.tr,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'shop_location_dialog_hint'.tr,
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
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : const Icon(Icons.save_rounded, size: 20),
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
