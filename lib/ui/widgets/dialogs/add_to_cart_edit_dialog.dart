import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/cart_controller.dart';
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

  late final TextEditingController quantityController = TextEditingController(
    text: widget.itemCounter.toString(),
  );

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  void _confirmAdd() {
    if (widget.itemCounter <= 0) {
      errorSnackbar('Please select a quantity greater than zero'.tr);
      return;
    }

    final unitPrice =
        _cartController.defaultUnitSellingPrice(widget.product);
    final prevTotal = _cartController.productsPrice;

    if (widget.product.itemType == 'service') {
      _cartController.updateCart(
        widget.product,
        widget.itemCounter,
        unitPrice,
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
        unitPrice,
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
                onPressed: _confirmAdd,
                text: 'confirm'.tr,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
