import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../../utils/constants.dart';

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
                        "assets/images/cash_register.png",
                        height: 90,
                        width: 90,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'HESABU MAUZO',
                        style: TextStyle(
                          fontSize: 32,
                          color: textDarkColor,
                          fontWeight: FontWeight.w700,
                        ),
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
                            labelText: '${'Enter Email'.tr}*',
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

                            String email = emailController.text.trim();
                            String password = passwordController.text.trim();

                            if (email.isEmpty) {
                              errorSnackbar('Email cannot be empty'.tr);
                              _authController.isLoading.value = false;
                            } else if (password.isEmpty) {
                              errorSnackbar('Password cannot be empty'.tr);
                              _authController.isLoading.value = false;
                            } else {
                              _authController.login(email, password);
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
