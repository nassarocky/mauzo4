import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/product_controller.dart';
import '../../../utils/preferences.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../../models/product_model.dart';
import '../../screens/product/edit_product_screen.dart';
import '../../../utils/constants.dart';
import '../../../utils/operation_error_message.dart';

// ignore: must_be_immutable
class ProductQuantityDialog extends StatefulWidget {
  ProductQuantityDialog({Key? key, required this.product}) : super(key: key);
  final Product product;
  double itemCounter = 0;

  @override
  State<ProductQuantityDialog> createState() => _ProductQuantityDialog();
}

class _ProductQuantityDialog extends State<ProductQuantityDialog> {
  final ProductController _productController = Get.find();
  late TextEditingController quantityController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with the initial value of itemCounter
    quantityController = TextEditingController(
      text: widget.itemCounter.toString(),
    );
  }

  @override
  void dispose() {
    // Dispose of the controller to avoid memory leaks
    quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        children: [
          Text(
            widget.product.name,
            style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
          ),
          Text(
            'stock_in_out'.tr,
            style: h6(Theme.of(context).textTheme.bodyLarge!.color),
          ),
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
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            if (-widget.product.quantity! <
                                widget.itemCounter) {
                              widget.itemCounter--;
                              quantityController.text = widget.itemCounter
                                  .toString();
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
                  enabled: !_isSubmitting,
                  onChanged: (value) {
                    final parsedValue = double.tryParse(value);
                    if (parsedValue != null) {
                      setState(() {
                        widget.itemCounter = parsedValue;
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
                  decoration: const InputDecoration(border: InputBorder.none),
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
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            widget.itemCounter++;
                            quantityController.text = widget.itemCounter
                                .toString();
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
          const SizedBox(height: 20),
          SizedBox(
            height: 44,
            child: TextField(
              onTap: () {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) =>
                        EditProductScreen(product: widget.product),
                  ),
                ).then((value) => Navigator.pop(context));
              },
              autofocus: true,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(
                    color: Preferences.getTheme()
                        ? lightGrayColor
                        : borderColor,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: borderColor, width: 1),
                ),
                prefix: Row(
                  children: [
                    Text(
                      '${widget.product.quantity!}',
                      style: const TextStyle(color: textPlaceholderColor),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      color: iconGrayColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.product.quantity! + widget.itemCounter}',
                      style: const TextStyle(color: warningColor),
                    ),
                  ],
                ),
                suffix: const Icon(Icons.edit, color: iconGrayColor, size: 18),
                labelText: 'total'.tr,
                labelStyle: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),
              keyboardType: TextInputType.number,
              readOnly: true,
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
                  if (_isSubmitting) return;
                  Navigator.pop(context);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                text: 'save'.tr,
                isLoading: _isSubmitting,
                onPressed: () async {
                  if (_isSubmitting) return;
                  setState(() => _isSubmitting = true);
                  try {
                    await _productController.updateProductCount(
                      widget.product,
                      (widget.itemCounter + widget.product.quantity),
                      '${widget.itemCounter < 0 ? 'Stock Reduced' : 'Stock Added'}',
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isSubmitting = false);
                    }
                    errorSnackbar(operationErrorMessage(e));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
