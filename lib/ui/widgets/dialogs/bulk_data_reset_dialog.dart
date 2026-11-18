import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/utils/bulk_data_reset.dart';
import 'package:mauzo/utils/constants.dart';

Future<String?> showBulkDataResetPasswordDialog({
  required BuildContext context,
  required BulkDataResetAction action,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _BulkDataResetPasswordDialog(action: action),
  );
}

class _BulkDataResetPasswordDialog extends StatefulWidget {
  const _BulkDataResetPasswordDialog({required this.action});

  final BulkDataResetAction action;

  @override
  State<_BulkDataResetPasswordDialog> createState() =>
      _BulkDataResetPasswordDialogState();
}

class _BulkDataResetPasswordDialogState
    extends State<_BulkDataResetPasswordDialog> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.action) {
      case BulkDataResetAction.deleteStocks:
        return 'delete_all_stocks'.tr;
      case BulkDataResetAction.zeroStocks:
        return 'zero_all_stocks'.tr;
      case BulkDataResetAction.deleteSales:
        return 'delete_all_sales'.tr;
      case BulkDataResetAction.deleteExpenses:
        return 'delete_all_expenses'.tr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('data_reset_hint'.tr, style: bodyText(textMutedColor)),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'enter_owner_password'.tr,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              onSubmitted: (_) => _confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: redColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _confirm,
          child: Text('bulk_reset_confirm'.tr),
        ),
      ],
    );
  }

  void _confirm() {
    final password = _passwordCtrl.text.trim();
    if (password.isEmpty) {
      errorSnackbar('enter_owner_password'.tr);
      return;
    }
    Navigator.pop(context, password);
  }
}
