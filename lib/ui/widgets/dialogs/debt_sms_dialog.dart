import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/services/sms_reminder_service.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/debt_reminder_message.dart';
import 'package:mauzo/utils/sms_phone.dart';

Future<bool> showDebtSmsDialog({
  required BuildContext context,
  required String clientName,
  required String phone,
  required double amount,
  String? clientId,
  String? dueDateLabel,
}) async {
  if (!isValidSmsPhone(phone)) {
    errorSnackbar('sms_fill_new_recipient'.tr);
    return false;
  }

  final businessController = Get.find<BusinessController>();
  final credits =
      (businessController.business['smsCredits'] as num?)?.toInt() ?? 0;
  if (credits <= 0) {
    errorSnackbar('sms_no_credits'.tr);
    return false;
  }

  final currency =
      businessController.business['mainCurrency']?.toString() ?? 'TZS';
  final shop = businessController.business['name']?.toString() ?? '';
  final lang = Get.locale?.languageCode == 'en' ? 'en' : 'sw';
  final defaultMessage = buildDebtReminderMessage(
    clientName: clientName,
    amount: amount,
    currency: currency,
    businessName: shop,
    dueDateLabel: dueDateLabel,
    template: businessController.smsSettings.debtReminderTemplate,
    lang: lang,
  );

  final sent = await showDialog<bool>(
    context: context,
    builder: (ctx) => _DebtSmsDialog(
      phone: phone,
      clientName: clientName,
      clientId: clientId,
      amount: amount,
      defaultMessage: defaultMessage,
      businessId: businessController.businessId.value,
    ),
  );
  if (sent == true) {
    await businessController.updateBusinessData();
  }
  return sent == true;
}

class _DebtSmsDialog extends StatefulWidget {
  const _DebtSmsDialog({
    required this.phone,
    required this.clientName,
    required this.amount,
    required this.defaultMessage,
    required this.businessId,
    this.clientId,
  });

  final String phone;
  final String clientName;
  final String? clientId;
  final double amount;
  final String defaultMessage;
  final String businessId;

  @override
  State<_DebtSmsDialog> createState() => _DebtSmsDialogState();
}

class _DebtSmsDialogState extends State<_DebtSmsDialog> {
  late final TextEditingController _messageCtrl;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messageCtrl = TextEditingController(text: widget.defaultMessage);
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      errorSnackbar('sms_custom_message_required'.tr);
      return;
    }
    final segments = countSmsSegments(message);
    if (segments < 1 || segments > 4) {
      errorSnackbar('sms_message_too_long'.tr);
      return;
    }

    setState(() => _sending = true);
    try {
      final lang = Get.locale?.languageCode == 'en' ? 'en' : 'sw';
      await SmsReminderService().sendBusinessSms(
        businessId: widget.businessId,
        type: 'debt_reminder',
        phone: widget.phone,
        clientId: widget.clientId,
        clientName: widget.clientName,
        amount: widget.amount,
        message: message,
        lang: lang,
      );
      if (mounted) Navigator.pop(context, true);
      successSnackbar('sms_sent_one'.tr);
    } catch (e) {
      errorSnackbar(smsFunctionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final segments = countSmsSegments(_messageCtrl.text.trim());
    return AlertDialog(
      title: Text('send_debt_sms'.tr),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.clientName}\n${widget.phone}',
              style: bodyText(textMutedColor),
            ),
            const SizedBox(height: 12),
            Text('sms_custom_message'.tr, style: bodyText(textMutedColor)),
            const SizedBox(height: 6),
            TextField(
              controller: _messageCtrl,
              maxLines: 5,
              enabled: !_sending,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'sms_custom_message_hint'.tr,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${'sms_segments'.tr}: $segments / 4',
                  style: bodyText(
                    segments > 4 ? redColor : textMutedColor,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _sending
                      ? null
                      : () {
                          _messageCtrl.text = widget.defaultMessage;
                          setState(() {});
                        },
                  child: Text('sms_use_default_message'.tr),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.pop(context, false),
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          child: _sending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('sms_send_one'.tr),
        ),
      ],
    );
  }
}
