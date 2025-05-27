import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pattern_formatter/numeric_formatter.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';

import '../../../controllers/business_controller.dart';
import '../buttons/delete_save_button.dart';

class DiscountBottomSheet extends StatefulWidget {
  final String chosenCurrency;
  const DiscountBottomSheet({Key? key, required this.chosenCurrency})
      : super(key: key);

  @override
  State<DiscountBottomSheet> createState() => _DiscountBottomSheetState();
}
bool isDiscountExceedingPercent({
  required double price,
  required double discount,
  required int discountPercent,
}) {
  // Calculate the maximum allowable discount based on the percentage
  double maxDiscount = (price * discountPercent) / 100;

  // Compare the given discount with the maximum allowable discount
  return discount < maxDiscount;
}

class _DiscountBottomSheetState extends State<DiscountBottomSheet> {
  final BusinessController _businessController = Get.find();
  final CartController _cartController = Get.find();
  final TextEditingController _discountController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Wrap(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'discount'.tr,
                  style: h5(
                    Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  keyboardType: TextInputType.phone,
                  controller: _discountController,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  decoration: InputDecoration(
                    contentPadding: inputPadding,
                    hintText: 'enter_discount'.tr,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  inputFormatters: [
                    ThousandsFormatter(
                      allowFraction: true,
                      formatter: NumberFormat(
                        '###,###.###',
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                DeleteSaveButton(
                  onDelete: () {
                    _cartController.clearDiscount();
                    Navigator.pop(context);
                  },
                  onSave: () {

                    if (_discountController.text.isNotEmpty) {

                      double discount = double.tryParse(
                              _discountController.text.replaceAll(',', '')) ??
                          0;
                      if(((_cartController.productsPrice-discount)>=_cartController.productsOriginalPrice)||isDiscountExceedingPercent(price: _cartController.productsPrice, discount: discount, discountPercent: _businessController.business['discountPercent'])){
                      if (discount > 0 &&
                          widget.chosenCurrency ==
                              _businessController.business['secondaryCurrency']) {
                        discount =
                            discount * Preferences.getExchangeRateResult();
                      }
                      if (discount >= 0 &&
                          discount <= _cartController.productsPrice) {
                        _cartController.payments.clear();
                        _cartController.addPayment(
                          _cartController.productsPrice - discount,
                          _businessController.business['mainCurrency'],
                        );
                      } else if (widget.chosenCurrency ==
                              _businessController.business['mainCurrency'] &&
                          double.parse(_discountController.text
                                  .replaceAll(',', '')) >
                              _cartController.productsPrice) {
                        _cartController.clearPayments();
                        discount = _cartController.productsPrice;
                      } else if (widget.chosenCurrency ==
                              _businessController.business['secondaryCurrency'] &&
                          double.parse(_discountController.text
                                  .replaceAll(',', '')) >
                              _cartController.productsPrice /
                                  Preferences.getExchangeRateResult()) {
                        _cartController.payments.clear();
                        discount = _cartController.productsPrice;
                      }
                      if (discount > 0 &&
                          discount <= _cartController.productsPrice) {
                        _cartController.setDiscount(discount);
                      }} else{

                   errorSnackbar('Maximum allowed Discount is ${_businessController.business['discountPercent']} percent');

                      }
                    }
                    Navigator.pop(context);
                  },
                  text: 'save'.tr,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
