import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/delete_save_button.dart';

class DiscountPercentDialog extends StatefulWidget {
  const DiscountPercentDialog({Key? key}) : super(key: key);

  @override
  State<DiscountPercentDialog> createState() => _DiscountPercentDialogState();
}

class _DiscountPercentDialogState extends State<DiscountPercentDialog> {
  late TextEditingController discountController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with an empty string so the hint remains visible.
    discountController = TextEditingController();
  }

  @override
  void dispose() {
    discountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BusinessController businessController = Get.find();
    return AlertDialog(
      title: Text(
        'discountPercent'.tr,
        style: h5(Theme.of(context).textTheme.bodyLarge!.color),
      ),
      content: TextField(
        controller: discountController,
        maxLength: 25,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          contentPadding: inputPadding,
          hintText: 'Enter discount percent'.tr,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          counterText: '',
        ),
      ),
      actions: [
        DeleteSaveButton(
          onDelete: () {
            Navigator.pop(context);
          },
          onSave: () {
            if (discountController.text.isNotEmpty) {
              firestore
                  .collection('businesses')
                  .doc(businessController.business['id'])
                  .update({
                'discountPercent': int.tryParse(discountController.text.trim()) ?? 0,
              });
              businessController.updateBusinessData();
              Navigator.pop(context);
            } else {
              errorSnackbar('fill_required_fields'.tr);
            }
          },
          text: 'save'.tr,
        )
      ],
    );
  }
}
