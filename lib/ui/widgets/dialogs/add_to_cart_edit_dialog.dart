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

// ignore: must_be_immutable
class AddToCartDialogEdit extends StatefulWidget {
  AddToCartDialogEdit({
    Key? key,
    required this.product,
    required this.itemCounter,
    this.addition = 0,
    this.soldQuantity = 0,
  }) : super(key: key);
  final Product product;
  final double addition;
  final double soldQuantity;

  double itemCounter;

  @override
  State<AddToCartDialogEdit> createState() => _AddToCartDialogEditState();
}

class _AddToCartDialogEditState extends State<AddToCartDialogEdit> {
  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();

  late TextEditingController _priceController;
  late TextEditingController _totalPriceController;
  late TextEditingController quantityController;

  @override
  void initState() {
    super.initState();
    final existing = _cartController.getPrice(widget.product.id);
    final unit = existing > 0
        ? existing
        : _cartController.defaultUnitSellingPrice(widget.product);
    _priceController = TextEditingController(
      text: formatCurrencyWithoutSymbol(unit),
    );
    _totalPriceController = TextEditingController(
      text: formatCurrencyWithoutSymbol(unit * widget.itemCounter),
    );
    quantityController = TextEditingController(
      text: widget.itemCounter.toString(),
    );
  }

  @override
  void dispose() {
    quantityController.dispose();
    _priceController.dispose();
    _totalPriceController.dispose();
    super.dispose();
  }

  void _updatePrices() {
    final singlePrice =
        double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
    final totalPrice = singlePrice * widget.itemCounter;
    _totalPriceController.text = formatCurrencyWithoutSymbol(totalPrice);
  }

  void _confirmAdd() {
    if (widget.itemCounter <= 0) {
      errorSnackbar('Please select a quantity greater than zero'.tr);
      return;
    }

    final enteredPrice =
        double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0;
    if (enteredPrice <= 0) {
      errorSnackbar('Enter a valid price'.tr);
      return;
    }

    final prevTotal = _cartController.productsPrice;

    if (widget.product.itemType == 'service') {
      _cartController.updateCart(
        widget.product,
        widget.itemCounter,
        enteredPrice,
      );
      _cartController.scalePaymentsAfterLineTotalChange(
          previousProductsPrice: prevTotal);
      Navigator.of(context).pop();
      return;
    }

    if (widget.itemCounter <=
        widget.product.quantity + widget.addition + 1e-9) {
      _cartController.updateCart(
        widget.product,
        widget.itemCounter,
        enteredPrice,
      );
      _cartController.scalePaymentsAfterLineTotalChange(
          previousProductsPrice: prevTotal);
      Navigator.of(context).pop();
    } else {
      errorSnackbar('not_enough'.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    quantityController.selection = TextSelection.fromPosition(
      TextPosition(offset: quantityController.text.length),
    );

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildIconButton(Icons.remove, () {
                setState(() {
                  if (widget.itemCounter > 0) {
                    widget.itemCounter--;
                    quantityController.text = widget.itemCounter.toString();
                    _updatePrices();
                  }
                });
              }),
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
                  style: TextStyle(
                    fontSize: 36,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                  textAlign: TextAlign.center,
                  controller: quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
              _buildIconButton(Icons.add, () {
                setState(() {
                  widget.itemCounter++;
                  quantityController.text = widget.itemCounter.toString();
                  _updatePrices();
                });
              }),
            ],
          ),
          const SizedBox(height: 36),
          _buildPriceRow('1x = ', _priceController, _updatePrices),
          const SizedBox(height: 16),
          _buildPriceRow('Total = ', _totalPriceController, _updatePrices),
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
                onPressed: _confirmAdd,
                text: 'confirm'.tr,
              ),
            ),
          ],
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

  SizedBox _buildPriceRow(
    String label,
    TextEditingController controller,
    VoidCallback onChanged,
  ) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          _buildPriceLabel(label),
          Expanded(
            child: TextField(
              inputFormatters: [ThousandsFormatter(allowFraction: true)],
              controller: controller,
              onChanged: (_) => onChanged(),
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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
}
