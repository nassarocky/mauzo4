import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class EditPhoneDialog extends StatefulWidget {
  const EditPhoneDialog({Key? key}) : super(key: key);

  @override
  State<EditPhoneDialog> createState() => _EditPhoneDialogState();
}

class _EditPhoneDialogState extends State<EditPhoneDialog> {
  final TextEditingController _phoneController = TextEditingController();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();
  String? _selectedCountryCode;
  String? _formattedNumber;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializePhoneNumber();
  }

  void _initializePhoneNumber() {
    final currentPhone = _businessController.business['phone'] ?? '';
    if (currentPhone.isNotEmpty) {
      // Extract country code and number
      if (currentPhone.startsWith('+')) {
        final parts = currentPhone.split(' ');
        if (parts.length > 1) {
          _selectedCountryCode = parts[0];
          _phoneController.text = parts[1];
        } else {
          // If no space, try to extract country code
          if (currentPhone.startsWith('+255')) {
            _selectedCountryCode = '+255';
            _phoneController.text = currentPhone.substring(4);
          } else if (currentPhone.startsWith('+254')) {
            _selectedCountryCode = '+254';
            _phoneController.text = currentPhone.substring(4);
          } else if (currentPhone.startsWith('+256')) {
            _selectedCountryCode = '+256';
            _phoneController.text = currentPhone.substring(4);
          } else if (currentPhone.startsWith('+250')) {
            _selectedCountryCode = '+250';
            _phoneController.text = currentPhone.substring(4);
          } else if (currentPhone.startsWith('+257')) {
            _selectedCountryCode = '+257';
            _phoneController.text = currentPhone.substring(4);
          }
        }
      }
      _formattedNumber = currentPhone;
    }
  }

  void _formatPhoneNumber() {
    if (_phoneController.text.isEmpty || _selectedCountryCode == null) return;

    // Remove any non-digit characters
    final cleanNumber = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    
    // Format the number
    setState(() {
      _formattedNumber = '$_selectedCountryCode$cleanNumber';
    });
  }

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
    }
    return false;
  }

  Future<void> _updatePhoneNumber() async {
    if (_formattedNumber == null || !_isValidPhoneNumber(_formattedNumber!)) {
      Get.snackbar(
        'Error',
        'Please enter a valid phone number',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String businessId = _businessController.business['id'];
      await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .update({'phone': _formattedNumber});

      await Preferences.setPhone(_formattedNumber!);
      _businessController.updateBusinessData();
      
      Get.back();
      successSnackbar('Phone number updated successfully');
    } catch (e) {
      print('Error updating phone number: $e');
      Get.snackbar(
        'Error',
        'Failed to update phone number',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Phone Number'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<String>(
            value: _selectedCountryCode,
            hint: Text('Select Country Code'.tr),
            items: [
              DropdownMenuItem(value: '+255', child: Text('Tanzania (+255)')),
              DropdownMenuItem(value: '+254', child: Text('Kenya (+254)')),
              DropdownMenuItem(value: '+256', child: Text('Uganda (+256)')),
              DropdownMenuItem(value: '+250', child: Text('Rwanda (+250)')),
              DropdownMenuItem(value: '+257', child: Text('Burundi (+257)')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCountryCode = value;
              });
              _formatPhoneNumber();
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Phone Number'.tr,
              hintText: 'Enter phone number'.tr,
            ),
            onChanged: (value) {
              _formatPhoneNumber();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Get.back(),
          child: Text('Cancel'.tr),
        ),
        ElevatedButton(
          onPressed: _isLoading || _formattedNumber == null ? null : _updatePhoneNumber,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Save'.tr),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
} 