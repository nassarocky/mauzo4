import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/delete_save_button.dart';

class EditExpireDialog extends StatefulWidget {
  const EditExpireDialog({Key? key}) : super(key: key);

  @override
  State<EditExpireDialog> createState() => _EditExpireDialogState();
}

class _EditExpireDialogState extends State<EditExpireDialog> {
  late TextEditingController expireController;

  @override
  void initState() {
    super.initState();
    // Initialize with an empty string so the hint remains visible
    expireController = TextEditingController();
  }

  @override
  void dispose() {
    expireController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BusinessController businessController = Get.find();
    return AlertDialog(
      title: Text(
        'Expire Warning'.tr,
        style: h5(Theme.of(context).textTheme.bodyLarge!.color),
      ),
      content: TextField(
        controller: expireController,
        maxLength: 25,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          contentPadding: inputPadding,
          hintText: 'Enter days'.tr,
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
            if (expireController.text.isNotEmpty) {
              firestore.collection('businesses')
                  .doc(businessController.business['id'])
                  .update({
                'expireWarning': int.tryParse(expireController.text.trim()) ?? 0,
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
