import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../controllers/business_controller.dart';
import '../../utils/constants.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({Key? key}) : super(key: key);

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String selectedProvider = 'Tigo';
  String accountNumber = '';
  String selectedPackage = '';
  String selectedDurationSeconds = '';
  String selectedPrice = '';
  final String macAddress = '00:11:22:33:44:55'; // Replace with dynamic if needed

  String? accessToken;
  final BusinessController _businessController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment'.tr),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18.0),
          child: Column(
            children: [
              Center(
                child: SizedBox(
                  height: 124,
                  width: 124,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      color: primaryUltraLightColor,
                      child: Image.asset(
                        'assets/images/splash.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 200,
                child: Text(
                  'Nunua kifurushi kulingana na matumizi yako.',
                  textAlign: TextAlign.center,
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // Provider
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Chagua Mtandao',
                  border: OutlineInputBorder(),
                ),
                value: selectedProvider,
                items: ['Tigo', 'Halopesa', 'Airtel', 'Azampesa']
                    .map((provider) => DropdownMenuItem(
                  value: provider,
                  child: Text(provider),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedProvider = value!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Namba ya Simu (mfano: 0750123456)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                onChanged: (value) {
                  setState(() {
                    accountNumber = value;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Package
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Chagua Kifurushi',
                  border: OutlineInputBorder(),
                ),
                value: selectedPackage.isEmpty ? null : selectedPackage,
                items: [
                  {
                    'label': 'Siku - 1000 TSH',
                    'seconds': '86400',
                    'price': '1000'
                  },
                  {
                    'label': 'Wiki - 5000 TSH',
                    'seconds': '604800',
                    'price': '5000'
                  },
                  {
                    'label': 'Mwezi - 18000 TSH',
                    'seconds': '2592000',
                    'price': '18000'
                  },
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
                onChanged: (value) {
                  setState(() {
                    selectedPackage = value!;
                  });
                },
              ),
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: () {
                  if (accountNumber.isEmpty ||
                      selectedPrice.isEmpty ||
                      selectedDurationSeconds.isEmpty) {
                    errorSnackbar('Tafadhali jaza taarifa zote.');
                    return;
                  }
                  makeCheckoutRequest();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  textStyle: const TextStyle(fontSize: 16),
                ),
                child: const Text('Nunua Vocha'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> generateAccessToken() async {
    const String baseUrl =
        'https://authenticator.azampay.co.tz/AppRegistration/GenerateToken';

    final Map<String, String> data = {
      'appName': 'Hesabu Mauzo',
      'clientId': '01963395-6a54-7444-b323-5ee39cdc4326',
      'clientSecret':
      'U2dqWWORy9Aze/...your_full_secret_here...jNNE=' // replace with full key
    };

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        accessToken = responseBody['data']['accessToken'];
        print('Access Token: $accessToken');
      } else {
        print('Failed to generate token: ${response.statusCode}');
      }
    } catch (error) {
      print('Error generating token: $error');
    }
  }

  Future<void> makeCheckoutRequest() async {
    await generateAccessToken();
    if (accessToken == null) {
      print('Token generation failed.');
      return;
    }

    const String baseUrl =
        'https://checkout.azampay.co.tz/azampay/mno/checkout';
    String email = _businessController.business['email'];
    double numberOfDays =
        (double.parse(selectedDurationSeconds)) / (60 * 60 * 24);

    final Map<String, dynamic> data = {
      'accountNumber': accountNumber,
      'amount': selectedPrice,
      'currency': 'TZS',
      'externalId': '123',
      'provider': selectedProvider,
      'additionalProperties': {
        'email': email,
        'numberOfDays': numberOfDays,
        'source': 'HesabuMauzo',
      }
    };

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $accessToken',
      'X-API-Key': 'none',
    };

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: headers,
        body: jsonEncode(data),
      );

      accessToken = null;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        print('Checkout Success: ${body['message']}');
        successSnackbar('Malipo yameanza. Subiri uthibitisho.');
      } else {
        print('Checkout failed: ${response.body}');
        errorSnackbar('Malipo hayakufanikiwa.');
      }
    } catch (e) {
      print('Checkout exception: $e');
      errorSnackbar('Hitilafu wakati wa kutuma malipo.');
      accessToken = null;
    }
  }
}
