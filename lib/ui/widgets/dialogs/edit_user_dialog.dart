import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/delete_save_button.dart';

class EditUserDialog extends StatefulWidget {
  const EditUserDialog({Key? key, required this.info}) : super(key: key);
  final String info;

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  late TextEditingController infoController;

  @override
  void initState() {
    super.initState();
    // Initialize the controller with an empty string
    infoController = TextEditingController();
  }

  @override
  void dispose() {
    infoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ProfileController profileController = Get.find();
    return AlertDialog(
      title: Text(
        "Edit ${widget.info}".tr,
        style: h5(Theme.of(context).textTheme.bodyLarge!.color),
      ),
      content: TextField(
        controller: infoController,
        maxLength: 25,
        autofocus: true,
        decoration: InputDecoration(
          contentPadding: inputPadding,
          // Show the current value as a floating label
          labelText: 'Enter name'.tr,
          floatingLabelBehavior: FloatingLabelBehavior.always,
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
              firestore
                  .collection('gmanusers')
                  .doc(profileController.user['id'])
                  .update({
                'name': infoController.text.trim(),
              });
              profileController.updateUserData();
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
