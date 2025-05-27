import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/delete_save_button.dart';

class EditBusinessDialog extends StatefulWidget {
  const EditBusinessDialog({Key? key, required this.info}) : super(key: key);
  final String info;

  @override
  State<EditBusinessDialog> createState() => _EditBusinessDialogState();
}

class _EditBusinessDialogState extends State<EditBusinessDialog> {
  late TextEditingController infoController;

  @override
  void initState() {
    super.initState();
    // Do not pre-populate the text field so that the hint/label remains visible.
    infoController = TextEditingController();
  }

  @override
  void dispose() {
    infoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BusinessController businessController = Get.find();
    return AlertDialog(
      title: Text(
        "Edit Business Name".tr,
        style: h5(Theme.of(context).textTheme.bodyLarge!.color),
      ),
      content: TextField(
        controller: infoController,
        maxLength: 25,
        autofocus: true,
        decoration: InputDecoration(
          // Use labelText with always-floating behavior so the hint stays visible
          labelText: 'Enter name'.tr,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: inputPadding,
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
            if (infoController.text.isNotEmpty) {
              firestore.collection('businesses')
                  .doc(businessController.business['id'])
                  .update({
                'name': infoController.text.trim(),
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
