import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/delete_save_button.dart';

class EditTinDialog extends StatefulWidget {
  const EditTinDialog({Key? key}) : super(key: key);

  @override
  State<EditTinDialog> createState() => _EditTinDialogState();
}

class _EditTinDialogState extends State<EditTinDialog> {
  late TextEditingController tinController;

  @override
  void initState() {
    super.initState();
    // Start with an empty controller so that hint remains visible
    tinController = TextEditingController();
  }

  @override
  void dispose() {
    tinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BusinessController businessController = Get.find();
    return AlertDialog(
      title: Text(
        'TIN number'.tr,
        style: h5(Theme.of(context).textTheme.bodyLarge!.color),
      ),
      content: TextField(
        controller: tinController,
        maxLength: 25,
        autofocus: true,
        decoration: InputDecoration(
          contentPadding: inputPadding,
          hintText: 'Enter Tin'.tr,
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
            if (tinController.text.isNotEmpty) {
              firestore
                  .collection('businesses')
                  .doc(businessController.business['id'])
                  .update({
                'tin': tinController.text.trim(),
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
