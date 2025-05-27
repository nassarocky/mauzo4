import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pattern_formatter/pattern_formatter.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/utils/preferences.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';

class AddToBuyDialog extends StatefulWidget {
  final Product product;
  double itemCounter;
  final double addition;
  final double soldQuantity;

  AddToBuyDialog({
    Key? key,
    required this.product,
    required this.itemCounter,
    this.addition = 0,
    this.soldQuantity = 0,
  }) : super(key: key);

  @override
  _AddToBuyDialogState createState() => _AddToBuyDialogState();
}

class _AddToBuyDialogState extends State<AddToBuyDialog> {
  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();

  late TextEditingController _priceController;
  late TextEditingController _totalPriceController;
  late TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: formatCurrencyWithoutSymbol(widget.product.buyingPrice),
    );
    _totalPriceController = TextEditingController(
      text: formatCurrencyWithoutSymbol(widget.product.buyingPrice * widget.itemCounter),
    );
    _quantityController = TextEditingController(
      text: widget.itemCounter.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    _quantityController.selection = TextSelection.fromPosition(
        TextPosition(offset: _quantityController.text.length));

    void updatePrices() {
      final singlePrice = double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
      final totalPrice = singlePrice * widget.itemCounter;
      _totalPriceController.text = formatCurrencyWithoutSymbol(totalPrice);
    }

    return AlertDialog(
      title: Column(
        children: [
          Text(
            'select_quantity'.tr,
            style: h6(Theme.of(context).textTheme.bodyLarge!.color),
          ),
          Text(
            widget.product.name,
            style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuantityRow(),
          const SizedBox(height: 36),
          _buildPriceRow('1x = ', _priceController, updatePrices),
          const SizedBox(height: 16),
          _buildPriceRow('Total = ', _totalPriceController, updatePrices),
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
                onPressed: _onConfirmPressed,
                text: 'confirm'.tr,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Row _buildQuantityRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildIconButton(
          Icons.remove,
              () {
            setState(() {
              if (widget.itemCounter > 0) {
                widget.itemCounter--;
                _quantityController.text = widget.itemCounter.toString();
                _updatePrices();
              }
            });
          },
        ),
        Expanded(
          child: TextField(
            onChanged: (value) {
              final parsedValue = double.tryParse(value);
              if (parsedValue != null) {
                setState(() {
                  widget.itemCounter = parsedValue;
                  _updatePrices();
                });
              }
            },
            style: TextStyle(fontSize: 36, color: Theme.of(context).textTheme.bodyLarge!.color),
            textAlign: TextAlign.center,
            controller: _quantityController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(border: InputBorder.none),
          ),
        ),
        _buildIconButton(
          Icons.add,
              () {
            setState(() {
              widget.itemCounter++;
              _quantityController.text = widget.itemCounter.toString();
              _updatePrices();
            });
          },
        ),
      ],
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onPressed) {
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

  SizedBox _buildPriceRow(String label, TextEditingController controller, VoidCallback onChanged) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _buildPriceLabel(label),
          Expanded(
            child: TextField(
              inputFormatters: [ThousandsFormatter(allowFraction: true)],
              controller: controller,
              onChanged: (value) => onChanged(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(4),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                suffixText: _businessController.business['mainCurrency'],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceLabel(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      height: 44,
      decoration: BoxDecoration(
        color: Preferences.getTheme() ? lightGrayColor : gray200Color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
        ),
      ),
    );
  }

  void _updatePrices() {
    final singlePrice = double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
    final totalPrice = singlePrice * widget.itemCounter;
    _totalPriceController.text = formatCurrencyWithoutSymbol(totalPrice);
  }

  void _onConfirmPressed() {
    double enteredPrice = double.parse(_priceController.text.replaceAll(',', ''));
    if (widget.product.price <= enteredPrice) {
      errorSnackbar('Buying price must be less than selling price'.tr);
    } else {
      _cartController.updateCart(
        widget.product,
        widget.itemCounter,
        enteredPrice,
      );
      Navigator.of(context).pop();
    }
  }
}
