import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/auth_controller.dart';
import 'package:mauzo/services/referral_attribution_service.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/business_shop_location.dart';

import '../../widgets/buttons/primary_button.dart';

enum _RegMethod { none, phone, email }

/// Converts any local Tanzanian phone format to E.164.
/// Examples:
///   0712345678  → +255712345678
///   255712345678 → +255712345678
///   +255712345678 → +255712345678 (unchanged)
/// For non-TZ numbers already in E.164 (e.g. +254...) they pass through unchanged.
String normalizePhoneToE164(String input, {String defaultCountryCode = '255'}) {
  String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0') && digits.length == 10) {
    // Local format: 0712345678 → strip 0, prepend country code
    digits = '$defaultCountryCode${digits.substring(1)}';
  }
  return '+$digits';
}

/// Digits-only phone for derived Auth email — must match Cloud Functions
/// [normalizePhoneDigitsForDerivedEmail] and employee registration.
String phoneDigitsForDerivedEmail(String input) {
  String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0') && digits.length == 10) {
    digits = '255${digits.substring(1)}';
  } else if (digits.length == 9 && !digits.startsWith('255')) {
    digits = '255$digits';
  }
  return digits;
}

class RegisterScreen extends StatefulWidget {
  RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  _RegMethod _regMethod = _RegMethod.none;

  // Shared controllers
  final _nameController       = TextEditingController();
  final _businessController   = TextEditingController();
  final _passwordController   = TextEditingController();

  // Phone-form controllers
  final _countryController    = TextEditingController(text: '255');
  final _phoneController      = TextEditingController();

  // Email-form controllers
  final _emailController      = TextEditingController();
  /// Optional promo / referral code (same rules as settings).
  final _promoCodeController  = TextEditingController();

  final _shopCountryController =
      TextEditingController(text: BusinessShopLocation.defaultCountry);
  final _shopCityController = TextEditingController();
  final _shopStreetController = TextEditingController();

  final AuthController _authController = Get.find();

  bool _obscurePassword = true;

  // Error flags
  bool _nameError     = false;
  bool _businessError = false;
  bool _phoneError    = false;
  bool _emailError    = false;
  bool _passwordError = false;
  bool _promoError = false;

  // ── Validation helpers ──────────────────────────────────────────────────

  bool _isValidPhone(String e164) {
    final patterns = {
      '+255': r'^\+255[0-9]{9}$',
      '+254': r'^\+254[0-9]{9}$',
      '+256': r'^\+256[0-9]{9}$',
      '+250': r'^\+250[0-9]{9}$',
      '+1':   r'^\+1[0-9]{10}$',
    };
    for (final entry in patterns.entries) {
      if (e164.startsWith(entry.key)) {
        return RegExp(entry.value).hasMatch(e164);
      }
    }
    return false;
  }

  String _buildE164() {
    String raw = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    // Allow users to type with or without leading 0 (e.g. 0712345678 or 712345678)
    if (raw.startsWith('0')) raw = raw.substring(1);
    return '+${_countryController.text.trim()}$raw';
  }

  void _resetErrors() => setState(() {
        _nameError = _businessError = _phoneError =
            _emailError = _passwordError = _promoError = false;
      });

  /// Returns normalized code, or `null` if the field is empty. Sets error if non-empty but invalid.
  String? _validateOptionalPromoForSubmit() {
    final raw = _promoCodeController.text.trim();
    if (raw.isEmpty) return null;
    final normalized = ReferralAttributionService.normalizeReferrerCode(raw);
    if (normalized == null) {
      setState(() => _promoError = true);
      errorSnackbar('referral_code_invalid'.tr);
      return null;
    }
    return normalized;
  }

  Widget _optionalShopLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'optional_shop_location'.tr,
          style: const TextStyle(fontSize: 14, color: textMutedColor),
        ),
        const SizedBox(height: 12),
        _field(
          controller: _shopCountryController,
          label: 'shop_country'.tr,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        _field(
          controller: _shopCityController,
          label: 'shop_city'.tr,
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 16),
        _field(
          controller: _shopStreetController,
          label: 'shop_street'.tr,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  void _goBack() {
    if (_regMethod == _RegMethod.none) {
      Navigator.pop(context);
    } else {
      _resetErrors();
      _authController.isLoading.value = false;
      setState(() => _regMethod = _RegMethod.none);
    }
  }

  // ── Phone registration submit ───────────────────────────────────────────

  Future<void> _submitPhone() async {
    _resetErrors();

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
    final phoneE164 = _buildE164();
    if (!_isValidPhone(phoneE164)) {
      setState(() => _phoneError = true);
      errorSnackbar('Please enter a valid phone number'.tr);
      return;
    }
    if (_passwordController.text.trim().length < 8) {
      setState(() => _passwordError = true);
      errorSnackbar('Password must be at least 8 characters'.tr);
      return;
    }

    final signupPromo = _validateOptionalPromoForSubmit();
    if (signupPromo == null && _promoCodeController.text.trim().isNotEmpty) {
      return;
    }

    try {
      await _authController.registerWithPhone(
        name:                _nameController.text.trim(),
        phone:               phoneE164,
        password:            _passwordController.text.trim(),
        business:            _businessController.text.trim(),
        mainCurrencyVal:     'TZS',
        secondaryCurrencyVal: '',
        signupPromoCode:     signupPromo,
        shopCountry:         _shopCountryController.text.trim(),
        shopCity:            _shopCityController.text.trim(),
        shopStreet:          _shopStreetController.text.trim(),
      );
    } catch (e) {
      errorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Email registration submit ───────────────────────────────────────────

  Future<void> _submitEmail() async {
    _resetErrors();

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
    if (_emailController.text.trim().isEmpty ||
        !_emailController.text.contains('@')) {
      setState(() => _emailError = true);
      errorSnackbar('Please enter a valid email'.tr);
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _phoneError = true);
      errorSnackbar('Please enter phone number'.tr);
      return;
    }
    final phoneE164 = _buildE164();
    if (!_isValidPhone(phoneE164)) {
      setState(() => _phoneError = true);
      errorSnackbar('Please enter a valid phone number'.tr);
      return;
    }
    if (_passwordController.text.trim().length < 8) {
      setState(() => _passwordError = true);
      errorSnackbar('Password must be at least 8 characters'.tr);
      return;
    }

    final signupPromo = _validateOptionalPromoForSubmit();
    if (signupPromo == null && _promoCodeController.text.trim().isNotEmpty) {
      return;
    }

    try {
      await _authController.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        phoneE164,
        _passwordController.text.trim(),
        _businessController.text.trim(),
        'TZS',
        '',
        signupPromoCode: signupPromo,
        shopCountry: _shopCountryController.text.trim(),
        shopCity: _shopCityController.text.trim(),
        shopStreet: _shopStreetController.text.trim(),
      );
    } catch (e) {
      errorSnackbar(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _goBack();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: primaryColor,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
        ),
        body: Obx(() {
          if (_authController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          switch (_regMethod) {
            case _RegMethod.none:
              return _buildMethodChoice();
            case _RegMethod.phone:
              return _buildPhoneForm();
            case _RegMethod.email:
              return _buildEmailForm();
          }
        }),
      ),
    );
  }

  // ── Method choice screen ────────────────────────────────────────────────

  Widget _buildMethodChoice() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Account'.tr,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: textDarkColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How would you like to register?'.tr,
            style: const TextStyle(fontSize: 14, color: textMutedColor),
          ),
          const SizedBox(height: 36),
          _MethodCard(
            icon: Icons.phone_android_rounded,
            title: 'Phone Number'.tr,
            subtitle: 'Register using your phone number and a password'.tr,
            onTap: () {
              _passwordController.clear();
              setState(() => _regMethod = _RegMethod.phone);
            },
          ),
          const SizedBox(height: 16),
          _MethodCard(
            icon: Icons.email_rounded,
            title: 'Email Address'.tr,
            subtitle: 'Register using your email, phone, and a password'.tr,
            onTap: () {
              _passwordController.clear();
              setState(() => _regMethod = _RegMethod.email);
            },
          ),
        ],
      ),
    );
  }

  // ── Phone form ──────────────────────────────────────────────────────────

  Widget _buildPhoneForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phone Registration'.tr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textDarkColor,
            ),
          ),
          const SizedBox(height: 24),

          // Name
          _field(
            controller: _nameController,
            label: '${'Your name'.tr}*',
            hasError: _nameError,
            maxLength: 25,
            onChanged: (_) {
              if (_nameError) setState(() => _nameError = false);
            },
          ),
          const SizedBox(height: 16),

          // Business
          _field(
            controller: _businessController,
            label: '${'business_name'.tr}*',
            hasError: _businessError,
            maxLength: 25,
            onChanged: (_) {
              if (_businessError) setState(() => _businessError = false);
            },
          ),
          const SizedBox(height: 16),

          _phoneRow(),
          const SizedBox(height: 16),

          _promoCodeField(),
          const SizedBox(height: 16),

          // Password
          _passwordField(),
          const SizedBox(height: 16),

          _optionalShopLocationSection(),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: 'Create Account'.tr,
              onPressed: _submitPhone,
            ),
          ),
        ],
      ),
    );
  }

  // ── Email form ──────────────────────────────────────────────────────────

  Widget _buildEmailForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Email Registration'.tr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: textDarkColor,
            ),
          ),
          const SizedBox(height: 24),

          // Name
          _field(
            controller: _nameController,
            label: '${'Your name'.tr}*',
            hasError: _nameError,
            maxLength: 25,
            autofocus: true,
            onChanged: (_) {
              if (_nameError) setState(() => _nameError = false);
            },
          ),
          const SizedBox(height: 16),

          // Business
          _field(
            controller: _businessController,
            label: '${'business_name'.tr}*',
            hasError: _businessError,
            maxLength: 25,
            onChanged: (_) {
              if (_businessError) setState(() => _businessError = false);
            },
          ),
          const SizedBox(height: 16),

          // Email
          _field(
            controller: _emailController,
            label: '${'email'.tr}*',
            hasError: _emailError,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) {
              if (_emailError) setState(() => _emailError = false);
            },
          ),
          const SizedBox(height: 16),

          _phoneRow(),
          const SizedBox(height: 16),

          _promoCodeField(),
          const SizedBox(height: 16),

          // Password
          _passwordField(),
          const SizedBox(height: 16),

          _optionalShopLocationSection(),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: 'Create Account'.tr,
              onPressed: _submitEmail,
            ),
          ),
        ],
      ),
    );
  }

  /// Country code + local number (shared by phone and email registration).
  Widget _phoneRow() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: TextField(
              controller: _countryController,
              keyboardType: TextInputType.phone,
              maxLength: 3,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                labelText: 'Code',
                counterText: '',
                prefix: Text('+',
                    style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              onChanged: (_) {
                if (_phoneError) setState(() => _phoneError = false);
              },
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                labelText: '${'phone'.tr}*',
                hintText: 'e.g. 0712345678',
                counterText: '',
                hintStyle: bodyText(textPlaceholderColor),
                border: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _phoneError ? Colors.red : borderColor)),
                enabledBorder: OutlineInputBorder(
                    borderSide:
                        BorderSide(color: _phoneError ? Colors.red : borderColor)),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        color: _phoneError ? Colors.red : primaryColor, width: 2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _promoCodeField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _promoCodeController,
        maxLength: 40,
        textCapitalization: TextCapitalization.characters,
        onChanged: (_) {
          if (_promoError) setState(() => _promoError = false);
        },
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          labelText: 'register_promo_code_label'.tr,
          hintText: 'referral_code_dialog_hint'.tr,
          counterText: '',
          hintStyle: bodyText(textPlaceholderColor),
          border: OutlineInputBorder(
              borderSide: BorderSide(color: _promoError ? Colors.red : borderColor)),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _promoError ? Colors.red : borderColor)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: _promoError ? Colors.red : primaryColor, width: 2)),
        ),
      ),
    );
  }

  // ── Shared widgets ──────────────────────────────────────────────────────

  Widget _field({
    required TextEditingController controller,
    required String label,
    bool hasError = false,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
    bool autofocus = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    void Function(String)? onChanged,
  }) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        keyboardType: keyboardType,
        autofocus: autofocus,
        textCapitalization: textCapitalization,
        onChanged: onChanged,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          labelText: label,
          counterText: '',
          hintStyle: bodyText(textPlaceholderColor),
          border: OutlineInputBorder(
              borderSide: BorderSide(color: hasError ? Colors.red : borderColor)),
          enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: hasError ? Colors.red : borderColor)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: hasError ? Colors.red : primaryColor, width: 2)),
        ),
      ),
    );
  }

  Widget _passwordField() {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        onChanged: (_) {
          if (_passwordError) setState(() => _passwordError = false);
        },
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
          labelText: '${'Password'.tr}*',
          hintStyle: bodyText(textPlaceholderColor),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
          border: OutlineInputBorder(
              borderSide:
                  BorderSide(color: _passwordError ? Colors.red : borderColor)),
          enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: _passwordError ? Colors.red : borderColor)),
          focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: _passwordError ? Colors.red : primaryColor, width: 2)),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _passwordController.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _promoCodeController.dispose();
    _shopCountryController.dispose();
    _shopCityController.dispose();
    _shopStreetController.dispose();
    super.dispose();
  }
}

// ── Method choice card ──────────────────────────────────────────────────────

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primaryUltraLightColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: primaryColor, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textDarkColor)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: textMutedColor)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 16, color: textMutedColor),
          ],
        ),
      ),
    );
  }
}
