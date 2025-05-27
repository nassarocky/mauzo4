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
  State<AddToCartDialogEdit> createState() => _AddToCartDialogState();
}

class _AddToCartDialogState extends State<AddToCartDialogEdit> {
  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();

  late final TextEditingController _priceController = TextEditingController(
    text: formatCurrencyWithoutSymbol(widget.product.price),
  );
  late final TextEditingController quantityController = TextEditingController(
    text: widget.itemCounter.toString(),
  );

  @override
  void initState() {
    super.initState();
    quantityController.selection = TextSelection.fromPosition(
      TextPosition(offset: quantityController.text.length),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        children: [
          Text('select_quantity'.tr,
              style: h6(
                Theme.of(context).textTheme.bodyLarge!.color,
              )),
          Text(widget.product.name,
              style: bodyText(Theme.of(context).textTheme.bodyMedium!.color)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Preferences.getTheme()
                      ? lightGrayColor
                      : primaryUltraLightColor,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      if (widget.itemCounter > 0) {
                        widget.itemCounter--;
                        quantityController.text = widget.itemCounter.toString();
                        quantityController.selection =
                            TextSelection.fromPosition(TextPosition(
                                offset: quantityController.text.length));
                      }
                    });
                  },
                  icon: Icon(
                    Icons.remove,
                    color: Preferences.getTheme() ? whiteColor : primaryColor,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  onChanged: (value) {
                    if (double.tryParse(value) != null) {
                      setState(() {
                        widget.itemCounter = double.parse(value);
                        quantityController.selection = TextSelection.fromPosition(
                          TextPosition(offset: quantityController.text.length),
                        );
                      });
                    }
                  },
                  style: TextStyle(
                    fontSize: 36,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                  textAlign: TextAlign.center,
                  controller: quantityController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Preferences.getTheme()
                      ? lightGrayColor
                      : primaryUltraLightColor,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      widget.itemCounter++;
                      quantityController.text = widget.itemCounter.toString();
                      quantityController.selection = TextSelection.fromPosition(
                          TextPosition(offset: quantityController.text.length));
                    });
                  },
                  icon: Icon(
                    Icons.add,
                    color: Preferences.getTheme() ? whiteColor : primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 36),
          SizedBox(
            height: 44,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                    Preferences.getTheme() ? lightGrayColor : gray200Color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '1x = ',
                      style: bodyText(
                          Theme.of(context).textTheme.bodyMedium!.color),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    inputFormatters: [ThousandsFormatter(allowFraction: true)],
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      border: const OutlineInputBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          )),
                      suffixText: _businessController.business['mainCurrency'],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                text: 'cancel'.tr,
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                onPressed: () {
                  double enteredPrice = double.parse(_priceController.text.replaceAll(',', ''));

                  // ✅ Check if quantity is zero or less
              /*    if (widget.itemCounter <= 0) {
                    errorSnackbar('Please select a quantity greater than zero'.tr);
                    return; // Exit early to prevent submission
                  }*/

                  // ✅ Continue your existing logic
                  if (widget.product.discount > 0) {
                    // Case: Discount is greater than zero
                    if ((widget.product.price - widget.product.discount) <= enteredPrice) {
                      if (widget.itemCounter <= widget.product.quantity + widget.addition) {
                        _cartController.updateCart(
                          widget.product,
                          widget.itemCounter,
                          enteredPrice,
                        );
                        Navigator.of(context).pop();
                      } else {
                        errorSnackbar('not_enough'.tr);
                      }
                    } else {
                      errorSnackbar(
                        'You can\'t sell below ${(widget.product.price - widget.product.discount).toStringAsFixed(2)}'.tr,
                      );
                    }
                  } else {
                    // Case: No discount
                    if (widget.product.price <= enteredPrice) {
                      if (widget.itemCounter <= widget.product.quantity + widget.addition) {
                        _cartController.updateCart(
                          widget.product,
                          widget.itemCounter,
                          enteredPrice,
                        );
                        Navigator.of(context).pop();
                      } else {
                        errorSnackbar('not_enough'.tr);
                      }
                    } else {
                      errorSnackbar('No Discount'.tr);
                    }
                  }
                },

                text: 'confirm'.tr,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
