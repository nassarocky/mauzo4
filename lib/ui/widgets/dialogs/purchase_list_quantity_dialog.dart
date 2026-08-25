import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../models/product_model.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class PurchaseListQuantityDialog extends StatefulWidget {
  const PurchaseListQuantityDialog({
    super.key,
    required this.product,
    required this.initialQuantity,
  });

  final Product product;
  final double initialQuantity;

  @override
  State<PurchaseListQuantityDialog> createState() =>
      _PurchaseListQuantityDialogState();
}

class _PurchaseListQuantityDialogState
    extends State<PurchaseListQuantityDialog> {
  late double _quantity;
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity > 0 ? widget.initialQuantity : 1;
    _quantityController = TextEditingController(
      text: _formatQuantity(_quantity),
    );
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _setQuantity(double value) {
    final next = value < 0 ? 0.0 : value;
    setState(() {
      _quantity = next;
      _quantityController.text = _formatQuantity(next);
      _quantityController.selection = TextSelection.collapsed(
        offset: _quantityController.text.length,
      );
    });
  }

  void _confirm() {
    final parsed = double.tryParse(_quantityController.text.trim());
    final quantity = parsed ?? _quantity;
    if (quantity <= 0) {
      errorSnackbar('Please select a quantity greater than zero'.tr);
      return;
    }
    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        children: [
          Text(
            'select_quantity'.tr,
            style: h6(Theme.of(context).textTheme.bodyLarge!.color),
          ),
          Text(
            widget.product.name,
            textAlign: TextAlign.center,
            style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
          ),
        ],
      ),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _quantityButton(
            icon: Icons.remove,
            onPressed: () => _setQuantity(_quantity - 1),
          ),
          Expanded(
            child: TextField(
              controller: _quantityController,
              autofocus: true,
              onChanged: (value) {
                final parsed = double.tryParse(value);
                if (parsed != null) _quantity = parsed;
              },
              style: TextStyle(
                fontSize: 36,
                color: Theme.of(context).textTheme.bodyLarge!.color,
              ),
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
          _quantityButton(
            icon: Icons.add,
            onPressed: () => _setQuantity(_quantity + 1),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                text: 'cancel'.tr,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                text: 'confirm'.tr,
                onPressed: _confirm,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quantityButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Preferences.getTheme() ? lightGrayColor : primaryUltraLightColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Preferences.getTheme() ? whiteColor : primaryColor,
        ),
      ),
    );
  }

  String _formatQuantity(double quantity) =>
      quantity == quantity.roundToDouble()
          ? quantity.toInt().toString()
          : quantity.toString();
}
