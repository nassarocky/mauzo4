import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../../utils/constants.dart';
import 'register_screen.dart' show normalizePhoneToE164;

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthController _authController = Get.put(AuthController());
  static String countryCode = '255'; // Default country code set to 255 (Tanzania)

  String verificationID = "";

  @override
  void initState() {
    super.initState();
    _authController.isLoading.value = false;
  }

  final emailController = TextEditingController();
  final countryController = TextEditingController(text: countryCode);
  final passwordController = TextEditingController();

  var inputContainsCountryCode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: whiteColor,
      body: Obx(
            () => _authController.isLoading.value
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : LayoutBuilder(
          builder: (context, constraints) {
            // Ensuring the layout maintains an aspect ratio
            double aspectRatio = 9 / 16; // Example: 9:16 ratio
            return Center(
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Image.asset(
                        'assets/images/hesabu_mauzo_logo.png',
                        height: 96,
                        fit: BoxFit.contain,
                        alignment: Alignment.centerLeft,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.65,
                        child: Text(
                          'app_description'.tr,
                          style: bodyText(textMutedColor),
                        ),
                      ),
                      const Spacer(),
                          SizedBox(
                        height: 44,
                        child: TextField(
                          keyboardType: TextInputType.emailAddress,
                          controller: emailController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            labelText: '${'Email or Phone'.tr}*',
                            hintText: 'e.g. user@email.com or +255712345678',
                            counterText: '',
                            hintStyle: bodyText(
                              textPlaceholderColor,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: borderColor,
                              ),
                            ),
                            border: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: borderColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                            hintText: 'Enter your password'.tr,
                            hintStyle: bodyText(gray400Color),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            Get.toNamed('/resetPassword'); // Navigate to ResetPasswordScreen
                          },
                          child: Text(
                            'Forgot Password?'.tr,
                            style: TextStyle(color: primaryColor),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          onPressed: () {
                            FocusScope.of(context).unfocus();
                            setState(() {
                              _authController.isLoading.value = true;
                            });

                            String credential = emailController.text.trim();
                            String password = passwordController.text.trim();

                            if (credential.isEmpty) {
                              errorSnackbar('Email or phone cannot be empty'.tr);
                              _authController.isLoading.value = false;
                            } else if (password.isEmpty) {
                              errorSnackbar('Password cannot be empty'.tr);
                              _authController.isLoading.value = false;
                            } else {
                              // If the user typed a phone number (with or
                              // without leading 0), derive the hidden email
                              // used during registration.
                              final digitsOnly = credential.replaceAll(RegExp(r'[^0-9]'), '');
                              final looksLikePhone = RegExp(r'^\+?[0-9]{9,15}$').hasMatch(credential.replaceAll(' ', ''));
                              if (looksLikePhone && digitsOnly.isNotEmpty) {
                                final e164 = normalizePhoneToE164(credential);
                                final normalized = e164.replaceAll(RegExp(r'[^0-9]'), '');
                                credential = '$normalized@hesabumauzo.app';
                              }
                              _authController.login(credential, password);
                            }
                          },
                          text: 'continue'.tr,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: TextButton(
                          onPressed: () {
                            Get.toNamed('/register');
                          },
                          child: Text(
                            'Don\'t have an account? Register'.tr,
                            style: bodyText(primaryColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
