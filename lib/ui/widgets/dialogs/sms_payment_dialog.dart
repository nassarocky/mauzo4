import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../controllers/business_controller.dart';
import '../../../models/sms_pack_model.dart';
import '../../../utils/constants.dart';

class SmsPaymentDialogContent extends StatefulWidget {
  const SmsPaymentDialogContent({super.key, required this.packs});

  final List<SmsPack> packs;

  @override
  State<SmsPaymentDialogContent> createState() =>
      _SmsPaymentDialogContentState();
}

class _SmsPaymentDialogContentState extends State<SmsPaymentDialogContent> {
  final BusinessController _businessController = Get.find();

  String selectedProvider = 'Tigo';
  String accountNumber = '';
  SmsPack? selectedPack;
  bool isLoading = false;

  Future<void> _pay() async {
    final pack = selectedPack;
    if (accountNumber.trim().isEmpty || pack == null) {
      errorSnackbar('sms_fill_payment'.tr);
      return;
    }
    setState(() => isLoading = true);
    try {
      final email = _businessController.business['email'];
      final response = await http.post(
        Uri.parse(
          'https://us-central1-hesabumauzo.cloudfunctions.net/makeSmsPayment',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': accountNumber.trim(),
          'provider': selectedProvider,
          'amount': pack.price.toString(),
          'email': email,
          'businessId': _businessController.businessId.value,
          'packId': pack.id,
        }),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        Get.snackbar(
          'Success',
          'Malipo yameanza. Weka namba ya siri kuthibitisha'.tr,
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.green.shade700,
          colorText: Colors.white,
          duration: const Duration(seconds: 13),
        );
      } else {
        errorSnackbar(data['message']?.toString() ?? 'sms_payment_failed'.tr);
      }
    } catch (_) {
      errorSnackbar('sms_payment_failed'.tr);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    final inputDecoration = InputDecoration(
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primaryColor, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return Stack(
      children: [
        Opacity(
          opacity: isLoading ? 0.4 : 1,
          child: AbsorbPointer(
            absorbing: isLoading,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'sms_buy_title'.tr,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'sms_buy_subtitle'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration:
                      inputDecoration.copyWith(labelText: 'Chagua Mtandao'),
                  value: selectedProvider,
                  items: ['Mpesa', 'Tigo', 'Halopesa', 'Airtel', 'Azampesa']
                      .map(
                        (p) => DropdownMenuItem(value: p, child: Text(p)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedProvider = v!),
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: inputDecoration.copyWith(
                    labelText: 'Namba ya Simu',
                    hintText: 'mfano: 0765908208',
                  ),
                  keyboardType: TextInputType.phone,
                  onChanged: (v) => accountNumber = v,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<SmsPack>(
                  decoration:
                      inputDecoration.copyWith(labelText: 'sms_choose_pack'.tr),
                  value: selectedPack,
                  items: widget.packs
                      .map(
                        (p) => DropdownMenuItem(
                          value: p,
                          child: Text(
                            '${p.label} — ${p.price} TZS',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => selectedPack = v),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _pay,
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text('Thibitisha Malipo'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isLoading)
          const Positioned.fill(
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
