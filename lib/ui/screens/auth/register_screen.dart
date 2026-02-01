import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/auth_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:flutter/services.dart';

import '../../widgets/bottomsheets/currency_picker_bottom_sheet.dart';
import '../../widgets/buttons/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _businessController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(
    text: '255', // Default country code for Tanzania
  );
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _Controller = TextEditingController();
  final AuthController _authController = Get.find();
  String placeholderHint = 'Enter phone number (e.g., 0712345678)';
  
  // Error tracking for each field
  bool _nameError = false;
  bool _businessError = false;
  bool _phoneError = false;
  bool _currencyError = false;
  bool _emailError = false;
  bool _passwordError = false;

  bool _isValidPhoneNumber(String number) {
    // Basic validation for East African numbers
    if (number.startsWith('+255')) {
      return RegExp(r'^\+255[0-9]{9}$').hasMatch(number);
    } else if (number.startsWith('+254')) {
      return RegExp(r'^\+254[0-9]{9}$').hasMatch(number);
    } else if (number.startsWith('+256')) {
      return RegExp(r'^\+256[0-9]{9}$').hasMatch(number);
    } else if (number.startsWith('+250')) {
      return RegExp(r'^\+250[0-9]{9}$').hasMatch(number);
    } else if (number.startsWith('+257')) {
      return RegExp(r'^\+257[0-9]{9}$').hasMatch(number);
    } else if (number.startsWith('+1')) {
      return RegExp(r'^\+1[0-9]{10}$').hasMatch(number);
    }
    return false;
  }

  void updatePlaceholderHint() {
    setState(() {
      switch (_countryController.text) {
        case '255':
          placeholderHint = 'Enter phone number (e.g., 0712345678)';
          break;
        case '254':
          placeholderHint = 'Enter phone number (e.g., 0712345678)';
          break;
        case '256':
          placeholderHint = 'Enter phone number (e.g., 0712345678)';
          break;
        case '250':
          placeholderHint = 'Enter phone number (e.g., 0712345678)';
          break;
        case '257':
          placeholderHint = 'Enter phone number (e.g., 0712345678)';
          break;
        case '1':
          placeholderHint = 'Enter phone number (e.g., 2345678901)';
          break;
        default:
          placeholderHint = 'Enter phone number';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    updatePlaceholderHint();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            _authController.mainCurrency.value = '';
            _authController.secondaryCurrency.value = '';
            _authController.isLoading.value = false;
            Navigator.pop(context);
          },
        ),
      ),
      body: Obx(
            () => SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  runAlignment: WrapAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.7,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'account_info'.tr,
                            style: const TextStyle(
                              color: textDarkColor,
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: gray200Color,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: const Icon(
                          Icons.person,
                          size: 40,
                          color: iconGrayColor,
                        ),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _nameController,
                    maxLength: 25,
                    autofocus: true,
                    onChanged: (value) {
                      if (_nameError && value.isNotEmpty) {
                        setState(() => _nameError = false);
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      labelText: '${'Your name'.tr}*',
                      counterText: '',
                      hintStyle: bodyText(textPlaceholderColor),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: _nameError ? Colors.red : borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _nameError ? Colors.red : borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _nameError ? Colors.red : primaryColor, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 44,
                  child: TextField(
                    maxLength: 25,
                    controller: _businessController,
                    onChanged: (value) {
                      if (_businessError && value.isNotEmpty) {
                        setState(() => _businessError = false);
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      labelText: '${'business_name'.tr}*',
                      counterText: '',
                      hintStyle: bodyText(textPlaceholderColor),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: _businessError ? Colors.red : borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _businessError ? Colors.red : borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _businessError ? Colors.red : primaryColor, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.1,
                        constraints: const BoxConstraints(minWidth: 80),
                        child: TextField(
                          onChanged: (v) {
                            updatePlaceholderHint();
                          },
                          controller: _countryController,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 0,
                            ),
                            labelText: 'Country Code',
                            counterText: '',
                            prefix: Text(
                              '+',
                              style: bodyText(
                                Theme.of(context).textTheme.bodyLarge!.color,
                              ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          maxLength: 3,
                          keyboardType: TextInputType.phone,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10), // Allow up to 10 digits
                          ],
                          onChanged: (value) {
                            if (_phoneError && value.isNotEmpty) {
                              setState(() => _phoneError = false);
                            }
                          },
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            labelText: '${'phone'.tr}*',
                            hintText: placeholderHint,
                            counterText: '',
                            hintStyle: bodyText(textPlaceholderColor),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: _phoneError ? Colors.red : borderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _phoneError ? Colors.red : borderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: _phoneError ? Colors.red : primaryColor, width: 2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: TextField(
                    onTap: () {
                      showModalBottomSheet(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        context: context,
                        isScrollControlled: true,
                        builder: (context) {
                          return const CurrencyPickerBottomSheet(
                            isAuth: true,
                          );
                        },
                      ).then((_) {
                        if (_currencyError && _authController.mainCurrency.value.isNotEmpty) {
                          setState(() => _currencyError = false);
                        }
                      });
                    },
                    readOnly: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      hintText: _authController.mainCurrency.value == ""
                          ? '${'main_currency'.tr}*'
                          : _authController.mainCurrency.value,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _currencyError ? Colors.red : borderColor),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: _currencyError ? Colors.red : borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _currencyError ? Colors.red : primaryColor, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: TextField(
                    keyboardType: TextInputType.emailAddress,
                    controller: _emailController,
                    onChanged: (value) {
                      if (_emailError && value.isNotEmpty) {
                        setState(() => _emailError = false);
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      labelText: '${'Email'.tr}*',
                      counterText: '',
                      hintStyle: bodyText(textPlaceholderColor),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _emailError ? Colors.red : borderColor),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: _emailError ? Colors.red : borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _emailError ? Colors.red : primaryColor, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 44,
                  child: TextField(
                    maxLength: 25,
                    controller: _passwordController,
                    onChanged: (value) {
                      if (_passwordError && value.isNotEmpty) {
                        setState(() => _passwordError = false);
                      }
                    },
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      labelText: '${'Password'.tr}*',
                      counterText: '',
                      hintStyle: bodyText(textPlaceholderColor),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _passwordError ? Colors.red : borderColor),
                      ),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: _passwordError ? Colors.red : borderColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _passwordError ? Colors.red : primaryColor, width: 2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: Obx(() {
                    return _authController.isLoading.value
                        ? const Center(child: CircularProgressIndicator())
                        : PrimaryButton(
                      text: 'save_and_continue'.tr,
                      onPressed: () {
                        // Reset all error states
                        setState(() {
                          _nameError = false;
                          _businessError = false;
                          _phoneError = false;
                          _currencyError = false;
                          _emailError = false;
                          _passwordError = false;
                        });
                        
                        // Validate each field individually and show specific error
                        if (_nameController.text.trim().isEmpty) {
                          setState(() => _nameError = true);
                          errorSnackbar('Please enter your name'.tr);
                          return;
                        }
                        
                        if (_businessController.text.trim().isEmpty) {
                          setState(() => _businessError = true);
                          errorSnackbar('Please enter business name'.tr);
                          return;
                        }
                        
                        if (_phoneController.text.trim().isEmpty) {
                          setState(() => _phoneError = true);
                          errorSnackbar('Please enter phone number'.tr);
                          return;
                        }
                        
                        String rawPhone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
                        // If exactly 10 digits, remove the first digit (likely a leading zero)
                        if (rawPhone.length == 10) {
                          rawPhone = rawPhone.substring(1);
                        }

                        final phoneNumber = '+${_countryController.text}$rawPhone';
                        
                        if (!_isValidPhoneNumber(phoneNumber)) {
                          setState(() => _phoneError = true);
                          errorSnackbar('Please enter valid phone number'.tr);
                          return;
                        }
                        
                        if (_authController.mainCurrency.value.isEmpty) {
                          setState(() => _currencyError = true);
                          errorSnackbar('Please select main currency'.tr);
                          return;
                        }
                        
                        if (_emailController.text.trim().isEmpty) {
                          setState(() => _emailError = true);
                          errorSnackbar('Please enter email address'.tr);
                          return;
                        }
                        
                        if (_passwordController.text.trim().isEmpty) {
                          setState(() => _passwordError = true);
                          errorSnackbar('Please enter password'.tr);
                          return;
                        }
                        
                        if (_passwordController.text.trim().length < 8) {
                          setState(() => _passwordError = true);
                          errorSnackbar('Password must be at least 8 characters'.tr);
                          return;
                        }

                        // All validations passed, proceed with registration
                        _authController.register(
                          _nameController.text.trim(),
                          _emailController.text.trim(),
                          phoneNumber,
                          _passwordController.text.trim(),
                          _businessController.text.trim(),
                          _authController.mainCurrency.value.trim(),
                          _authController.secondaryCurrency.value.trim(),
                        );
                      },
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}