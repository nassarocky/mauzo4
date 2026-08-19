import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/models/sms_pack_model.dart';
import 'package:mauzo/services/sms_reminder_service.dart';
import 'package:mauzo/ui/widgets/dialogs/sms_payment_dialog.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/debt_reminder_message.dart';
import 'package:mauzo/utils/sms_phone.dart';

class SmsCreditsScreen extends StatefulWidget {
  const SmsCreditsScreen({Key? key}) : super(key: key);

  @override
  State<SmsCreditsScreen> createState() => _SmsCreditsScreenState();
}

class _SmsCreditsScreenState extends State<SmsCreditsScreen> {
  final BusinessController _businessController = Get.find();
  final ClientController _clientController = Get.find();
  final ProfileController _profileController = Get.find();
  final SmsReminderService _smsService = SmsReminderService();

  final Set<String> _selectedIds = {};
  List<SmsPack> _packs = SmsPack.defaults;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _smsService.loadPacks().then((packs) {
      if (mounted) setState(() => _packs = packs);
    });
  }

  bool get _isOwner =>
      (_profileController.user['role'] ?? '').toString() == 'owner';

  bool get _canSend =>
      _profileController.hasPermission('send_debt_sms') ||
      _profileController.hasPermission('manage_debt');

  List<Client> get _debtorsWithPhone {
    return _clientController.clients
        .where((c) => c.debt > 0 && isValidSmsPhone(c.phone))
        .toList()
      ..sort((a, b) => b.debt.compareTo(a.debt));
  }

  int get _smsCredits {
    final raw = _businessController.business['smsCredits'];
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? 0}') ?? 0;
  }

  Future<void> _refreshBusiness() async {
    await _businessController.updateBusinessData();
    if (mounted) setState(() {});
  }

  void _showBuyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('sms_subscribe'.tr),
        content: SingleChildScrollView(
          child: SmsPaymentDialogContent(packs: _packs),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('close'.tr),
          ),
        ],
      ),
    ).then((_) => _refreshBusiness());
  }

  Future<void> _send(List<String> clientIds) async {
    if (clientIds.isEmpty) {
      errorSnackbar('sms_select_clients'.tr);
      return;
    }
    if (_smsCredits <= 0) {
      errorSnackbar('sms_no_credits'.tr);
      if (_isOwner) _showBuyDialog();
      return;
    }

    final lang = Get.locale?.languageCode == 'en' ? 'en' : 'sw';
    setState(() => _sending = true);
    try {
      final result = await _smsService.sendReminders(
        businessId: _businessController.businessId.value,
        clientIds: clientIds,
        lang: lang,
      );
      await _refreshBusiness();
      final sent = result['sent'] ?? 0;
      final failed = result['failed'] ?? 0;
      if (sent > 0) {
        successSnackbar('${'sms_sent'.tr}: $sent. ${'sms_failed'.tr}: $failed');
      } else {
        errorSnackbar('sms_send_failed'.tr);
      }
    } catch (e) {
      errorSnackbar(smsFunctionErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency =
        _businessController.business['mainCurrency']?.toString() ?? 'TZS';
    final shop =
        _businessController.business['name']?.toString() ?? '';
    final debtors = _debtorsWithPhone;

    return Scaffold(
      appBar: AppBar(
        title: Text('sms_debt_reminders'.tr),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshBusiness,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.sms_outlined, color: primaryColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'sms_credits_remaining'.tr,
                                style: h6(
                                  Theme.of(context).textTheme.bodyLarge!.color,
                                ),
                              ),
                            ),
                            Text(
                              '$_smsCredits',
                              style: h5(primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'sms_credits_explain'.tr,
                          style: bodyText(textMutedColor),
                        ),
                        if (_isOwner) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _showBuyDialog,
                              icon: const Icon(Icons.shopping_cart_outlined),
                              label: Text('sms_buy_credits'.tr),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'sms_debtors'.tr,
                        style: h6(Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                    ),
                    if (_canSend && debtors.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedIds.length == debtors.length) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds
                                ..clear()
                                ..addAll(debtors.map((c) => c.id));
                            }
                          });
                        },
                        child: Text(
                          _selectedIds.length == debtors.length
                              ? 'clear'.tr
                              : 'sms_select_all'.tr,
                        ),
                      ),
                  ],
                ),
                if (debtors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'sms_no_debtors'.tr,
                      style: bodyText(textMutedColor),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  ...debtors.map((client) {
                    final selected = _selectedIds.contains(client.id);
                    final preview = buildDebtReminderMessage(
                      clientName: client.name,
                      amount: client.debt,
                      currency: currency,
                      businessName: shop,
                      lang: Get.locale?.languageCode == 'en' ? 'en' : 'sw',
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: CheckboxListTile(
                        value: selected,
                        onChanged: _canSend
                            ? (v) {
                                setState(() {
                                  if (v == true) {
                                    _selectedIds.add(client.id);
                                  } else {
                                    _selectedIds.remove(client.id);
                                  }
                                });
                              }
                            : null,
                        title: Text(client.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${'debt'.tr}: ${formatCurrency(client.debt, currency)}',
                              style: const TextStyle(color: redColor),
                            ),
                            Text(client.phone),
                            const SizedBox(height: 4),
                            Text(
                              preview,
                              style: const TextStyle(
                                fontSize: 12,
                                color: textMutedColor,
                              ),
                            ),
                          ],
                        ),
                        secondary: _canSend
                            ? IconButton(
                                tooltip: 'sms_send_one'.tr,
                                icon: const Icon(Icons.send),
                                onPressed: _sending
                                    ? null
                                    : () => _send([client.id]),
                              )
                            : null,
                      ),
                    );
                  }),
                const SizedBox(height: 16),
                Text(
                  'sms_recent'.tr,
                  style: h6(Theme.of(context).textTheme.bodyLarge!.color),
                ),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _smsService
                      .logs(_businessController.businessId.value),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Text('sms_log_error'.tr);
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Text(
                        'sms_no_logs'.tr,
                        style: bodyText(textMutedColor),
                      );
                    }
                    return Column(
                      children: docs.take(20).map((doc) {
                        final d = doc.data();
                        final status = (d['status'] ?? '').toString();
                        final when = d['createdAt'] is Timestamp
                            ? DateFormat('dd/MM HH:mm').format(
                                (d['createdAt'] as Timestamp).toDate(),
                              )
                            : '';
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            status == 'sent'
                                ? Icons.check_circle
                                : Icons.error_outline,
                            color: status == 'sent' ? greenColor : redColor,
                          ),
                          title: Text(
                            (d['clientName'] ?? d['phone'] ?? '').toString(),
                          ),
                          subtitle: Text(
                            '${d['phone'] ?? ''}  $when',
                            maxLines: 1,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
          if (_sending)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x33000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _canSend && _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: _sending
                      ? null
                      : () => _send(_selectedIds.toList()),
                  icon: const Icon(Icons.sms),
                  label: Text(
                    '${'sms_send_selected'.tr} (${_selectedIds.length})',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
