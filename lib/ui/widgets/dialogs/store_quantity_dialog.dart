import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/store_controller.dart';
import '../../../utils/preferences.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';

// ignore: must_be_immutable
class StoreQuantityDialog extends StatefulWidget {
  StoreQuantityDialog({
    Key? key,
    required this.product,
    this.isMoveToStore = false,
  }) : super(key: key);
  final Product product;
  final bool isMoveToStore; // New parameter to determine direction
  double itemCounter = 0.0;

  @override
  State<StoreQuantityDialog> createState() => _StoreQuantityDialog();
}

class _StoreQuantityDialog extends State<StoreQuantityDialog> {
  final StoreController _storeController = Get.find();
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
            widget.isMoveToStore ? 'Move to Store'.tr : 'stock_in_out'.tr,
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
                    // Handle decimal input properly
                    final parsedValue = double.tryParse(value);
                    if (parsedValue != null) {
                      setState(() {
                        widget.itemCounter = parsedValue;
                        quantityController
                            .selection = TextSelection.fromPosition(
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
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                text: widget.isMoveToStore
                    ? 'Move to Store'.tr
                    : 'Move to Shop'.tr,
                isLoading: _isSubmitting,
                onPressed: () async {
                  if (_isSubmitting) return;
                  setState(() => _isSubmitting = true);
                  final bool moved;
                  if (widget.isMoveToStore) {
                    moved = await _storeController.moveStockToStore(
                      widget.product,
                      widget.itemCounter,
                    );
                  } else {
                    moved = await _storeController.moveStockToShop(
                      widget.product,
                      widget.itemCounter,
                    );
                  }
                  if (moved && context.mounted) {
                    Navigator.of(context).pop();
                  } else if (mounted) {
                    setState(() => _isSubmitting = false);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                text: 'Add to Store'.tr,
                isLoading: _isSubmitting,
                onPressed: () async {
                  if (_isSubmitting) return;
                  setState(() => _isSubmitting = true);
                  final updated = await _storeController
                      .updateStoreProductCount(
                        widget.product,
                        widget.product.quantity + widget.itemCounter,
                      );
                  if (updated && context.mounted) {
                    Navigator.of(context).pop();
                  } else if (mounted) {
                    setState(() => _isSubmitting = false);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
          ],
        ),
      ],
    );
  }
}
