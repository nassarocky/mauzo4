import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../controllers/business_controller.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/purchase_list_controller.dart';
import '../../../controllers/supplier_controller.dart';
import '../../../models/purchase_list_draft.dart';
import '../../../models/supplier_model.dart';
import '../../../services/purchase_list_export_service.dart';
import '../../../services/sms_reminder_service.dart';
import '../../../utils/constants.dart';
import '../../../utils/operation_error_message.dart';
import '../../../utils/preferences.dart';
import '../../../utils/sms_phone.dart';
import '../../../utils/sms_settings.dart';
import '../../widgets/dashed_seperator.dart';
import '../../widgets/dialogs/sms_recipient_dialog.dart';
import 'purchase_list_editor_screen.dart';

class PurchaseListsScreen extends StatefulWidget {
  const PurchaseListsScreen({super.key});

  @override
  State<PurchaseListsScreen> createState() => _PurchaseListsScreenState();
}

class _PurchaseListsScreenState extends State<PurchaseListsScreen> {
  final PurchaseListController _controller =
      Get.isRegistered<PurchaseListController>()
          ? Get.find<PurchaseListController>()
          : Get.put(PurchaseListController());
  final SupplierController _supplierController =
      Get.isRegistered<SupplierController>()
          ? Get.find<SupplierController>()
          : Get.put(SupplierController());
  final ProductController _productController = Get.find();
  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();
  final Set<String> _busyDrafts = {};

  String get _businessName =>
      (_businessController.business['name'] ?? 'Business').toString();

  Future<void> _openEditor([PurchaseListDraft? draft]) async {
    final message = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PurchaseListEditorScreen(draft: draft),
      ),
    );
    if (!mounted || message == null || message.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) successSnackbar(message);
    });
  }

  Future<void> _sendSms(PurchaseListDraft draft) async {
    if (_busyDrafts.contains(draft.id)) return;
    setState(() => _busyDrafts.add(draft.id));
    try {
      String? phone = draft.supplierPhone;
      if (!isValidSmsPhone(phone)) {
        phone = await showSmsPhoneOnlyDialog(
          context: context,
          title: 'sms_send_purchase_list'.tr,
        );
        if (phone == null) return;
      }
      await SmsReminderService().sendBusinessSms(
        businessId: draft.businessId,
        type: 'purchase_list',
        phone: phone,
        supplierId: draft.supplierId.isNotEmpty ? draft.supplierId : null,
        supplierName:
            draft.supplierName.isNotEmpty ? draft.supplierName : phone,
        referenceId: draft.id,
        lines: productLinesForSms(draft.products),
        lang: Get.locale?.languageCode == 'en' ? 'en' : 'sw',
      );
      successSnackbar('sms_sent_purchase_list'.tr);
    } catch (error) {
      errorSnackbar(operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyDrafts.remove(draft.id));
    }
  }

  Future<void> _sharePdf(PurchaseListDraft draft) async {
    await _runBusy(draft, () {
      return PurchaseListExportService.sharePdf(
        draft: draft,
        businessName: _businessName,
      );
    });
  }

  Future<void> _shareExcel(PurchaseListDraft draft) async {
    await _runBusy(draft, () {
      return PurchaseListExportService.shareExcel(
        draft: draft,
        businessName: _businessName,
      );
    });
  }

  Future<void> _runBusy(
    PurchaseListDraft draft,
    Future<void> Function() operation,
  ) async {
    if (_busyDrafts.contains(draft.id)) return;
    setState(() => _busyDrafts.add(draft.id));
    try {
      await operation();
    } catch (error) {
      errorSnackbar(operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busyDrafts.remove(draft.id));
    }
  }

  Future<void> _convert(PurchaseListDraft draft) async {
    final products = draft.products.map((line) {
      return _productController.getProduct((line['id'] ?? '').toString());
    }).toList();
    final missing = products.where((product) => product.id.isEmpty).length;
    if (missing > 0) {
      errorSnackbar(
        '$missing product(s) no longer exist. Edit the list before converting.',
      );
      return;
    }
    Supplier? supplier;
    if (draft.supplierId.isNotEmpty) {
      supplier = _supplierController.getSupplier(draft.supplierId);
      if (supplier.id.isEmpty) {
        errorSnackbar('Supplier no longer exists. Edit the list first.');
        return;
      }
    }

    _cartController.clearCart();
    _cartController.clearPayments();
    _cartController.clearDiscount();
    _cartController.clearComment();
    _cartController.passedArgument = 'NOT';
    _cartController.origin = 'purchase_list';
    _cartController.purchaseListDraftId = draft.id;
    if (supplier != null) {
      _cartController.setSupplier(supplier);
    } else {
      _cartController.clearSupplier();
    }
    final maps = <Map<String, dynamic>>[
      for (var i = 0; i < draft.products.length; i++)
        {
          ...draft.products[i],
          'price': products[i].buyingPrice,
          'buyingPrice': products[i].buyingPrice,
        },
    ];
    _cartController.setProducts(products, maps);
    if (!mounted) return;
    await Navigator.pushNamed(context, '/buycart');
  }

  Future<void> _delete(PurchaseListDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete purchase list?'),
        content: Text(
          'Delete ${draft.supplierName.isNotEmpty ? 'the list for ${draft.supplierName}' : 'this supplier-free list'}? This will not affect inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runBusy(draft, () => _controller.deleteDraft(draft.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier purchase lists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New list'),
      ),
      body: Obx(() {
        final drafts = _controller.drafts;
        if (drafts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.playlist_add_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No supplier purchase lists yet',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Create a list to send to a supplier without recording an actual purchase.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
          itemCount: drafts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final draft = drafts[index];
            final busy = _busyDrafts.contains(draft.id);
            return Container(
              color: Preferences.getTheme() ? mediumGrayColor : whiteColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              margin: const EdgeInsets.only(left: 4, right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'List: ${DateFormat("hh:mm a", 'en_US').format(draft.updatedAt.toDate())}',
                        style: h6(
                          Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      const Spacer(),
                      if (busy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            color: Preferences.getTheme()
                                ? primaryLightColor
                                : primaryColor,
                          ),
                          onSelected: (value) {
                            if (value == 'edit') _openEditor(draft);
                            if (value == 'delete') _delete(draft);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('edit'.tr),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'delete'.tr,
                                style: bodyText(redColor),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.account_circle,
                        color: iconGrayColor,
                        size: 28,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          draft.supplierName.isNotEmpty
                              ? draft.supplierName
                              : 'No supplier selected',
                          style: bodyText(
                            Theme.of(context).textTheme.bodyMedium!.color,
                          ),
                        ),
                      ),
                      Text(
                        '${draft.products.length} products',
                        style: bodyText(textPlaceholderColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const DashedSeperator(),
                  const SizedBox(height: 12),
                  for (final line in draft.products)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (line['name'] ?? '').toString(),
                                  style: bodyText(
                                    Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Requested quantity: ${_formatQuantity((line['quantity'] as num?)?.toDouble() ?? 0)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium!
                                        .color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const DashedSeperator(),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: busy ? null : () => _sendSms(draft),
                        icon: const Icon(Icons.sms_outlined, size: 18),
                        label: const Text('SMS'),
                      ),
                      ElevatedButton.icon(
                        onPressed: busy ? null : () => _sharePdf(draft),
                        icon:
                            const Icon(Icons.picture_as_pdf_outlined, size: 18),
                        label: const Text('PDF'),
                      ),
                      ElevatedButton.icon(
                        onPressed: busy ? null : () => _shareExcel(draft),
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: const Text('Excel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: busy ? null : () => _convert(draft),
                        icon:
                            const Icon(Icons.shopping_cart_checkout, size: 18),
                        label: const Text('Convert'),
                      ),
                    ],
                  ),
                  if (draft.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      draft.note,
                      style: bodyText(
                        Theme.of(context).textTheme.bodyMedium!.color,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Qty ${_formatQuantity(draft.totalQuantity)}',
                        style: h6(
                          Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      if (draft.sendCount > 0)
                        Text(
                          'Sent ${draft.sendCount} time(s)',
                          style: bodyText(greenColor),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  String _formatQuantity(double quantity) =>
      quantity == quantity.roundToDouble()
          ? quantity.toInt().toString()
          : quantity.toString();
}
