import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';

class PaymentDialogContent extends StatefulWidget {
  const PaymentDialogContent({super.key});

  @override
  State<PaymentDialogContent> createState() => _PaymentDialogContentState();
}

class _PaymentDialogContentState extends State<PaymentDialogContent> {
  final BusinessController _businessController = Get.find();

  String selectedProvider = 'Tigo';
  String accountNumber = '';
  String selectedPackage = '';
  String selectedDurationSeconds = '';
  String selectedPrice = '';
  bool isLoading = false;

  void successSnackbar(String message, {Duration duration = const Duration(seconds: 3)}) {
    Get.snackbar(
      'Success',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.green.shade700,
      colorText: Colors.white,
      duration: duration,
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
    );
  }

  Future<void> callCloudPaymentFunction() async {
    setState(() => isLoading = true);

    try {
      final email = _businessController.business['email'];
      final response = await http.post(
        Uri.parse('https://us-central1-hesabumauzo.cloudfunctions.net/makePayment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': accountNumber,
          'provider': selectedProvider,
          'amount': selectedPrice,
          'durationSeconds': selectedDurationSeconds,
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);
      setState(() => isLoading = false);

      if (response.statusCode == 200 && data['success'] == true) {
        successSnackbar('Malipo yameanza. Weka namba ya siri kuthibitisha'.tr, duration: const Duration(seconds: 13));
        // Navigator.of(context).pop(); // Optionally close
      } else {
        errorSnackbar(data['message'] ?? 'Malipo hayakufanikiwa.');
      }
    } catch (e) {
      setState(() => isLoading = false);
      errorSnackbar('Hitilafu wakati wa kutuma malipo.');
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
          opacity: isLoading ? 0.4 : 1.0,
          child: AbsorbPointer(
            absorbing: isLoading,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Taarifa za Malipo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 20),

                  // Provider selection
                  DropdownButtonFormField<String>(
                    decoration: inputDecoration.copyWith(labelText: 'Chagua Mtandao'),
                    value: selectedProvider,
                    items: ['Tigo', 'Halopesa', 'Airtel', 'Azampesa']
                        .map((provider) => DropdownMenuItem(
                      value: provider,
                      child: Text(provider),
                    ))
                        .toList(),
                    onChanged: (value) => setState(() => selectedProvider = value!),
                  ),
                  const SizedBox(height: 16),

                  // Phone number input
                  TextField(
                    decoration: inputDecoration.copyWith(
                      labelText: 'Namba ya Simu',
                      hintText: 'mfano: 0750123456',
                    ),
                    keyboardType: TextInputType.phone,
                    onChanged: (value) => setState(() => accountNumber = value),
                  ),
                  const SizedBox(height: 16),

                  // Package selection
                  DropdownButtonFormField<String>(
                    decoration: inputDecoration.copyWith(labelText: 'Chagua Kifurushi'),
                    value: selectedPackage.isEmpty ? null : selectedPackage,
                    items: [
                      {'label': 'Wiki - 5000 TSH', 'seconds': '604800', 'price': '5000'},
                      {'label': 'Mwezi - 15,000 TSH', 'seconds': '2592000', 'price': '15000'},
                      {'label': 'Miezi 6 - 75,000 TSH', 'seconds': '15552000', 'price': '75000'},
                      {'label': 'Mwaka - 130,000 TSH', 'seconds': '31622400', 'price': '130000'},
                    ].map((pkg) {
                      return DropdownMenuItem<String>(
                        value: pkg['label'],
                        child: Text(pkg['label']!),
                        onTap: () {
                          selectedDurationSeconds = pkg['seconds']!;
                          selectedPrice = pkg['price']!;
                        },
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => selectedPackage = value!),
                  ),
                  const SizedBox(height: 24),

                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (accountNumber.isEmpty || selectedPrice.isEmpty || selectedDurationSeconds.isEmpty) {
                          errorSnackbar('Tafadhali jaza taarifa zote.');
                          return;
                        }
                        callCloudPaymentFunction();
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Thibitisha Malipo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
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
