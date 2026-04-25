import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/auth_controller.dart';
import '../../../utils/constants.dart';
import 'register_screen.dart' show normalizePhoneToE164;

enum _ResetMethod { none, email, phone }

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final AuthController _authController = Get.find();
  _ResetMethod _method = _ResetMethod.none;

  // Email reset
  final _emailCtrl = TextEditingController();

  // Phone reset
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _otpSent = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _goBack() {
    if (_method == _ResetMethod.phone && _otpSent) {
      setState(() {
        _otpSent = false;
        _authController.otpSent.value = false;
      });
    } else if (_method != _ResetMethod.none) {
      setState(() {
        _method = _ResetMethod.none;
        _otpSent = false;
        _authController.otpSent.value = false;
      });
    } else {
      Get.back();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _goBack();
        return false;
      },
      child: Scaffold(
        backgroundColor: whiteColor,
        appBar: AppBar(
          backgroundColor: whiteColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: textDarkColor),
            onPressed: _goBack,
          ),
          title: Text(
            'Reset Password'.tr,
            style: const TextStyle(color: textDarkColor, fontWeight: FontWeight.w600),
          ),
        ),
        body: Obx(() {
          if (_authController.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          switch (_method) {
            case _ResetMethod.email:
              return _buildEmailReset();
            case _ResetMethod.phone:
              return _buildPhoneReset();
            case _ResetMethod.none:
            default:
              return _buildMethodChoice();
          }
        }),
      ),
    );
  }

  Widget _buildMethodChoice() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'How did you register?'.tr,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textDarkColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the method you used to create your account.'.tr,
            style: const TextStyle(fontSize: 14, color: textMutedColor),
          ),
          const SizedBox(height: 32),
          _MethodCard(
            icon: Icons.email_rounded,
            title: 'Registered with Email'.tr,
            subtitle: 'We will send a reset link to your email address.'.tr,
            onTap: () => setState(() => _method = _ResetMethod.email),
          ),
          const SizedBox(height: 16),
          _MethodCard(
            icon: Icons.phone_android_rounded,
            title: 'Registered with Phone'.tr,
            subtitle: 'Verify your phone with an OTP to set a new password.'.tr,
            onTap: () => setState(() => _method = _ResetMethod.phone),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailReset() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Enter your email'.tr,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: textDarkColor),
          ),
          const SizedBox(height: 6),
          Text(
            'A password reset link will be sent to your inbox.'.tr,
            style: const TextStyle(fontSize: 14, color: textMutedColor),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: () {
                final email = _emailCtrl.text.trim();
                if (email.isEmpty) {
                  Get.snackbar('Error'.tr, 'Please enter your email.'.tr,
                      snackPosition: SnackPosition.BOTTOM);
                  return;
                }
                _authController.resetPassword(email);
              },
              child: Text(
                'Send Reset Link'.tr,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneReset() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (!_otpSent) ...[
            Text(
              'Enter your phone number'.tr,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textDarkColor),
            ),
            const SizedBox(height: 6),
            Text(
              'We will send a verification code to your phone.'.tr,
              style: const TextStyle(fontSize: 14, color: textMutedColor),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (e.g. +255712345678)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () async {
                  final raw = _phoneCtrl.text.trim();
                  if (raw.isEmpty) {
                    Get.snackbar('Error'.tr, 'Please enter your phone number.'.tr,
                        snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  final phone = normalizePhoneToE164(raw);
                  await _authController.startPhoneVerification(phone);
                  if (_authController.otpSent.value) {
                    setState(() => _otpSent = true);
                  }
                },
                child: Text(
                  'Send OTP'.tr,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Verify & Set New Password'.tr,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: textDarkColor),
            ),
            const SizedBox(height: 6),
            Text(
              '${'Code sent to'.tr} ${_phoneCtrl.text.trim()}',
              style: const TextStyle(fontSize: 14, color: textMutedColor),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP Code',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _newPasswordCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password'.tr,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureNew ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password'.tr,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () {
                  final code = _otpCtrl.text.trim();
                  final newPwd = _newPasswordCtrl.text;
                  final confirmPwd = _confirmPasswordCtrl.text;
                  if (code.length != 6) {
                    Get.snackbar('Error'.tr, 'Enter the 6-digit OTP code.'.tr,
                        snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  if (newPwd.length < 8) {
                    Get.snackbar('Error'.tr,
                        'Password must be at least 8 characters.'.tr,
                        snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  if (newPwd != confirmPwd) {
                    Get.snackbar(
                        'Error'.tr, 'Passwords do not match.'.tr,
                        snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  _authController.resetPasswordWithOtp(
                    phone: normalizePhoneToE164(_phoneCtrl.text.trim()),
                    code: code,
                    newPassword: newPwd,
                  );
                },
                child: Text(
                  'Reset Password'.tr,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: () async {
                  await _authController.startPhoneVerification(
                      normalizePhoneToE164(_phoneCtrl.text.trim()));
                },
                child: Text(
                  'Resend OTP'.tr,
                  style: const TextStyle(color: primaryColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: primaryColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: textDarkColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: textMutedColor),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: textMutedColor),
          ],
        ),
      ),
    );
  }
}
