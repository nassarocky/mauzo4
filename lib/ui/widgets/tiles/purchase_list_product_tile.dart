import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/business_controller.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';

class PurchaseListProductTile extends StatelessWidget {
  PurchaseListProductTile({
    super.key,
    required this.product,
    required this.selectedQuantity,
    required this.onAdd,
    required this.onChange,
    required this.onRemove,
  });

  final Product product;
  final double selectedQuantity;
  final VoidCallback onAdd;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  final BusinessController _businessController = Get.find();

  @override
  Widget build(BuildContext context) {
    final isService = product.itemType == 'service';
    final expireWarning =
        _businessController.business['expireWarning'] as int? ?? 30;
    final expiring = !isService &&
        product.expireDate != null &&
        product.expireDate!.isBefore(
          DateTime.now().add(Duration(days: expireWarning)),
        );
    final nameColor =
        expiring ? Colors.orange : Theme.of(context).textTheme.bodyLarge!.color!;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isService ? Colors.purple : const Color(0xFF80B2FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: isService
                ? const Icon(
                    Icons.miscellaneous_services,
                    color: Colors.white,
                    size: 28,
                  )
                : Image.asset('assets/images/box.png'),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: h6(nameColor)),
                const SizedBox(height: 5),
                Text(
                  formatCurrency(
                    product.price,
                    _businessController.business['mainCurrency'],
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF999999),
                  ),
                ),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isService ? 'N/A' : _formatQuantity(product.quantity),
                      style: bodyText(isService ? Colors.grey : warningColor),
                    ),
                    Text(
                      isService
                          ? 'Service'
                          : (product.reserveString1.isEmpty
                              ? 'unit'
                              : product.reserveString1),
                      style: TextStyle(
                        fontSize: 14,
                        color: isService ? Colors.grey : warningColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                const VerticalDivider(color: borderColor, width: 1),
                if (selectedQuantity > 0)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(40, 40),
                    ),
                    onPressed: () => _showActions(context),
                    child: Text(
                      _formatQuantity(selectedQuantity),
                      style: TextStyle(
                        fontSize: 24,
                        color: Preferences.getTheme()
                            ? primaryLightColor
                            : primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: onAdd,
                    icon: Icon(
                      Icons.add_circle,
                      color: Preferences.getTheme()
                          ? primaryLightColor
                          : primaryColor,
                      size: 28,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showActions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.8,
      ),
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              children: [
                _action(
                  context: sheetContext,
                  label: 'change'.tr,
                  color: primaryColor,
                  action: onChange,
                ),
                const Divider(height: 0),
                _action(
                  context: sheetContext,
                  label: 'delete'.tr,
                  color: const Color(0xFFEB5757),
                  action: onRemove,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: _action(
              context: sheetContext,
              label: 'cancel'.tr,
              action: () {},
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _action({
    required BuildContext context,
    required String label,
    required VoidCallback action,
    Color? color,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: TextButton(
        onPressed: () {
          Navigator.pop(context);
          action();
        },
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  String _formatQuantity(double quantity) =>
      quantity == quantity.roundToDouble()
          ? quantity.toInt().toString()
          : quantity.toStringAsFixed(2);
}
