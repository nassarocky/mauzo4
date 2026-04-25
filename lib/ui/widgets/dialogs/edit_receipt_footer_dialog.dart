import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/delete_save_button.dart';

class EditReceiptFooterDialog extends StatefulWidget {
  const EditReceiptFooterDialog({Key? key}) : super(key: key);

  @override
  State<EditReceiptFooterDialog> createState() =>
      _EditReceiptFooterDialogState();
}

class _EditReceiptFooterDialogState extends State<EditReceiptFooterDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final BusinessController bc = Get.find();
    final raw = bc.business['receiptFooterMessage'];
    _controller = TextEditingController(text: raw?.toString() ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BusinessController businessController = Get.find();
    return AlertDialog(
      title: Text(
        'receipt_footer_message'.tr,
        style: h5(Theme.of(context).textTheme.bodyLarge!.color),
      ),
      content: SingleChildScrollView(
        child: TextField(
          controller: _controller,
          maxLines: 5,
          maxLength: 400,
          autofocus: true,
          decoration: InputDecoration(
            contentPadding: inputPadding,
            hintText: 'receipt_footer_hint'.tr,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
      actions: [
        DeleteSaveButton(
          onDelete: () => Navigator.pop(context),
          onSave: () {
            final text = _controller.text.trim();
            firestore
                .collection('businesses')
                .doc(businessController.business['id'])
                .update({'receiptFooterMessage': text}).then((_) async {
              await businessController.updateBusinessData();
              if (!context.mounted) return;
              Navigator.pop(context);
              successSnackbar('receipt_footer_saved'.tr);
            }).catchError((_) {
              errorSnackbar('Failed to save');
            });
          },
          text: 'save'.tr,
        )
      ],
    );
  }
}
