import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:pattern_formatter/pattern_formatter.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/utils/preferences.dart';
import '../../../models/client_model.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';

// ignore: must_be_immutable
class AddAdvance extends StatefulWidget {

  AddAdvance({
    Key? key,
    required this.client,
   // required this.itemCounter,
    this.addition = 0,
    this.soldQuantity = 0,
  }) : super(key: key);

  final double addition;
  final double soldQuantity;

 // double itemCounter;
  final Client client;
  @override
  State<AddAdvance> createState() => _AddAdvanceState();
}

class _AddAdvanceState extends State<AddAdvance> {
  final ClientController _clientController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  late final TextEditingController _priceController = TextEditingController();


  @override
  void initState() {
    super.initState();

  }

  @override
  void dispose() {
    _priceController.dispose();

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
          Text(widget.client.name,
              style: bodyText(Theme.of(context).textTheme.bodyMedium!.color)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
                        ),
                      ),
                      hintText: 'Enter Amount', // Placeholder text
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
            if(widget.client.advance>0&&_profileController.role=='owner')
    Expanded(
    child: SecondaryButton(
    text: 'reduce'.tr,
    onPressed: () {
    double enteredPrice = double.tryParse(_priceController.text.replaceAll(',', '')) ?? 0.0;

    if (enteredPrice > 0) {
    if (widget.client.advance - enteredPrice >= 0) {
    _clientController.reduceAdvance(
    widget.client,
    enteredPrice,
    );
    Navigator.of(context).pop(); // Close dialog after successful reduction
    } else {
    // Show error snackbar if the amount to reduce is greater than the available advance
    errorSnackbar('Amount exceeds available advance: ${formatCurrency(widget.client.advance, _businessController.business['mainCurrency'])}');
    }
    } else {
    errorSnackbar('ENTER AMOUNT TO REDUCE');
    }
    },
    ),
    ),

            const SizedBox(width: 8),
            Expanded(
              child: PrimaryButton(
                onPressed: () {
                  double enteredPrice = double.parse(_priceController.text.replaceAll(',', ''));
                  if (enteredPrice>0) {
                    _clientController.updateAdvance(
                      widget.client,
                      enteredPrice,
                    );
                    Navigator.of(context).pop();
                  }
                },
                text: 'Add'.tr,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
