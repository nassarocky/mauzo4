import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../models/subscription_pricing_model.dart';
import '../../../utils/constants.dart';

class PaymentDialogContent extends StatefulWidget {
  const PaymentDialogContent({super.key});

  @override
  State<PaymentDialogContent> createState() => _PaymentDialogContentState();
}

class _PaymentDialogContentState extends State<PaymentDialogContent> {
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  String selectedProvider = 'Tigo';
  String accountNumber = '';
  String selectedPackage = '';
  String selectedDurationSeconds = '';
  String selectedPrice = '';
  bool isLoading = false;
  bool isPricingLoading = true;
  int businessCount = 1;
  SubscriptionPricingModel? pricingModel;

  @override
  void initState() {
    super.initState();
    // Get the number of businesses the user owns
    final userBusinesses = _profileController.user['business'] as List<dynamic>?;
    businessCount = userBusinesses?.length ?? 1;
    if (businessCount < 1) businessCount = 1; // Minimum 1 business
    _loadPricing();
  }

  Future<void> _loadPricing() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('subscriptionPricing')
          .doc('config')
          .get();

      if (doc.exists) {
        pricingModel = SubscriptionPricingModel.fromFirestore(doc);
      } else {
        pricingModel = SubscriptionPricingModel.getDefault();
      }

      setState(() => isPricingLoading = false);
    } catch (e) {
      print('Error loading pricing: $e');
      pricingModel = SubscriptionPricingModel.getDefault();
      setState(() => isPricingLoading = false);
    }
  }

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

  List<DropdownMenuItem<String>> _buildPackageItems() {
    if (pricingModel == null) return [];

    final tierPrices = pricingModel!.getPricesForBusinessCount(businessCount);
    final durationSeconds = pricingModel!.durationSeconds;

    final packages = [
      {'key': 'week', 'label': 'Wiki'},
      {'key': 'month', 'label': 'Mwezi'},
      {'key': 'sixMonths', 'label': 'Miezi 6'},
      {'key': 'year', 'label': 'Mwaka'},
    ];

    return packages.map((pkg) {
      final key = pkg['key']!;
      final price = tierPrices[key] ?? 0;
      final formattedPrice = price.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      
      final label = '${pkg['label']} - $formattedPrice TSH';
      
      return DropdownMenuItem<String>(
        value: label,
        child: Text(label),
        onTap: () {
          selectedDurationSeconds = durationSeconds[key] ?? '';
          selectedPrice = price.toString();
        },
      );
    }).toList();
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
        if (isPricingLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          )
        else
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
                    const SizedBox(height: 12),
                    // Show business count info
                    Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.business, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Biashara: $businessCount ${businessCount == 1 ? "biashara" : "biashara"}',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
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
                    items: _buildPackageItems(),
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
