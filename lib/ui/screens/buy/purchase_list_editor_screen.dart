import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/product_controller.dart';
import '../../../controllers/purchase_list_controller.dart';
import '../../../controllers/supplier_controller.dart';
import '../../../models/product_model.dart';
import '../../../models/purchase_list_draft.dart';
import '../../../models/supplier_model.dart';
import '../../../services/sms_reminder_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/operation_error_message.dart';
import '../../../utils/preferences.dart';
import '../../../utils/sms_phone.dart';
import '../../../utils/sms_settings.dart';
import '../../widgets/dialogs/sms_recipient_dialog.dart';
import '../../widgets/dialogs/purchase_list_quantity_dialog.dart';
import '../../widgets/tiles/purchase_list_product_tile.dart';

class PurchaseListEditorScreen extends StatefulWidget {
  const PurchaseListEditorScreen({super.key, this.draft});

  final PurchaseListDraft? draft;

  @override
  State<PurchaseListEditorScreen> createState() =>
      _PurchaseListEditorScreenState();
}

class _PurchaseListEditorScreenState
    extends State<PurchaseListEditorScreen> {
  final ProductController _productController = Get.find();
  final SupplierController _supplierController = Get.find();
  final PurchaseListController _draftController = Get.find();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final Map<String, double> _quantities = {};
  final Map<String, Map<String, dynamic>> _lineMeta = {};
  Supplier? _supplier;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _productController.filteredProducts.value = _productController.products;
    final draft = widget.draft;
    if (draft != null) {
      _noteController.text = draft.note;
      for (final line in draft.products) {
        final id = (line['id'] ?? '').toString();
        final qty = (line['quantity'] as num?)?.toDouble() ?? 0;
        if (id.isNotEmpty && qty > 0) {
          _quantities[id] = qty;
          _lineMeta[id] = Map<String, dynamic>.from(line);
        }
      }
      if (draft.supplierId.isNotEmpty) {
        _supplier = _supplierController.getSupplier(draft.supplierId);
        if (_supplier?.id.isEmpty ?? true) {
          _supplier = Supplier(
            id: draft.supplierId,
            owner: draft.businessId,
            name: draft.supplierName,
            phone: draft.supplierPhone,
            date: draft.createdAt,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    Timer.run(() {
      _productController.filterCategories.clear();
      _productController.searchText.value = '';
      _productController.searchProducts.value = _productController.products;
      _productController.filteredProducts.value = _productController.products;
    });
    super.dispose();
  }

  List<Map<String, dynamic>> get _lines {
    return _quantities.entries.map((entry) {
      final current = _productController.getProduct(entry.key);
      final saved = _lineMeta[entry.key] ?? const <String, dynamic>{};
      return {
        'id': entry.key,
        'name': current.id.isNotEmpty
            ? current.name
            : (saved['name'] ?? 'Unknown product').toString(),
        'quantity': entry.value,
        'itemType': current.id.isNotEmpty
            ? current.itemType
            : (saved['itemType'] ?? 'product').toString(),
      };
    }).toList();
  }

  Future<void> _pickSupplier() async {
    final value = await Navigator.pushNamed(context, '/supplier/select');
    if (value is Supplier && mounted) {
      setState(() => _supplier = value);
    }
  }

  Future<void> _editQuantity(Product product) async {
    final value = await showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PurchaseListQuantityDialog(
        product: product,
        initialQuantity: _quantities[product.id] ?? 1,
      ),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (value <= 0) {
        _quantities.remove(product.id);
        _lineMeta.remove(product.id);
      } else {
        _quantities[product.id] = value;
        _lineMeta[product.id] = {
          'id': product.id,
          'name': product.name,
          'itemType': product.itemType,
        };
      }
    });
  }

  Future<void> _showFinishDialog() async {
    final sendSms = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Finish supplier list'),
        content: Text(
          _supplier == null
              ? '${_quantities.length} products selected. No supplier is attached.'
              : '${_quantities.length} products selected for ${_supplier!.name}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, false),
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save draft'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.sms_outlined),
            label: const Text('Save & send'),
          ),
        ],
      ),
    );
    if (sendSms == null || !mounted) return;
    await _submit(sendSms: sendSms);
  }

  Future<String> _save() async {
    return _draftController.saveDraft(
      draftId: widget.draft?.id,
      supplier: _supplier,
      products: _lines,
      note: _noteController.text,
    );
  }

  Future<void> _submit({required bool sendSms}) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final draftId = await _save();
      if (sendSms) {
        if (!mounted) return;
        final supplier = _supplier;
        String? phone = supplier?.phone;
        if (!isValidSmsPhone(phone)) {
          phone = await showSmsPhoneOnlyDialog(
            context: context,
            title: 'sms_send_purchase_list'.tr,
          );
          if (phone == null) {
            if (mounted) setState(() => _isSubmitting = false);
            return;
          }
        }
        await SmsReminderService().sendBusinessSms(
          businessId: _draftController.businessId,
          type: 'purchase_list',
          phone: phone,
          supplierId:
              supplier != null && supplier.id.isNotEmpty ? supplier.id : null,
          supplierName:
              supplier != null && supplier.name.isNotEmpty
                  ? supplier.name
                  : phone,
          referenceId: draftId,
          lines: productLinesForSms(_lines),
          lang: Get.locale?.languageCode == 'en' ? 'en' : 'sw',
        );
      }
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(
        context,
        sendSms ? 'sms_sent_purchase_list'.tr : 'Purchase list saved',
      );
    } catch (error) {
      errorSnackbar(operationErrorMessage(error));
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            Preferences.getTheme() ? darkGrayColor : primaryUltraLightColor,
        foregroundColor:
            Preferences.getTheme() ? primaryUltraLightColor : textDarkColor,
        elevation: 0,
        title: Text(
          widget.draft == null ? 'select_items'.tr : 'Edit supplier list',
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 62,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      _quantities.length.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        color: Preferences.getTheme()
                            ? primaryLightColor
                            : primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' ${'selected'.tr}',
                      style: bodyText(const Color(0xFFA9A9A9)),
                    ),
                  ],
                ),
                SizedBox(
                  width: 124,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                    ),
                    onPressed: _isSubmitting || _quantities.isEmpty
                        ? null
                        : _showFinishDialog,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'done'.tr,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(
                    _supplier?.name ?? 'Select supplier',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: _supplier == null
                      ? const Text('Optional')
                      : Text(_supplier!.phone),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isSubmitting ? null : _pickSupplier,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    labelText: 'Note (optional)',
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Preferences.getTheme()
                            ? mediumGrayColor
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      enabled: !_isSubmitting,
                      onChanged: _productController.search,
                      decoration: InputDecoration(
                        contentPadding: EdgeInsets.zero,
                        hintText: 'search'.tr,
                        hintStyle: bodyText(iconGrayColor),
                        prefixIcon:
                            const Icon(Icons.search, color: iconGrayColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              final products = _productController.filteredProducts;
              if (products.isEmpty) {
                return Center(
                  child: Text(
                    'not_found'.tr,
                    style: bodyText(
                      Theme.of(context).textTheme.bodyMedium!.color,
                    ),
                  ),
                );
              }
              final sortedProducts =
                  _productController.sortProductsForDisplay(products);
              return ListView.builder(
                padding: const EdgeInsets.only(top: 8),
                itemCount: sortedProducts.length,
                itemBuilder: (context, index) {
                  final product = sortedProducts[index];
                  return PurchaseListProductTile(
                    key: ValueKey(product.id),
                    product: product,
                    selectedQuantity: _quantities[product.id] ?? 0,
                    onAdd: () => _editQuantity(product),
                    onChange: () => _editQuantity(product),
                    onRemove: () {
                      if (!mounted) return;
                      setState(() {
                        _quantities.remove(product.id);
                        _lineMeta.remove(product.id);
                      });
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
