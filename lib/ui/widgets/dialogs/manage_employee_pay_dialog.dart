import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/pay_role_model.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class ManageEmployeePayDialog extends StatefulWidget {
  final ProfileModel employee;
  final String? businessId;
  final String? businessName;
  final PayRoleModel? existingPayRole;

  const ManageEmployeePayDialog({
    Key? key,
    required this.employee,
    this.businessId,
    this.businessName,
    this.existingPayRole,
  }) : super(key: key);

  @override
  State<ManageEmployeePayDialog> createState() => _ManageEmployeePayDialogState();
}

class _ManageEmployeePayDialogState extends State<ManageEmployeePayDialog> {
  final PayRoleController _payRoleController = Get.find();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  final _formKey = GlobalKey<FormState>();
  final _payRateController = TextEditingController();
  final _commissionRateController = TextEditingController();
  final _notesController = TextEditingController();

  String? selectedBusinessId;
  String? selectedBusinessName;
  PayType selectedPayType = PayType.salary;
  String selectedCurrency = 'TZS';
  PayPeriod selectedPayPeriod = PayPeriod.monthly;
  int selectedPayDay = 1;
  bool isLoading = false;

  List<Map<String, String>> availableBusinesses = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableBusinesses();
    _initializeFormData();
  }

  @override
  void dispose() {
    _payRateController.dispose();
    _commissionRateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _loadAvailableBusinesses() async {
    try {
      final userBusinesses = List<String>.from(_profileController.user['business'] ?? []);
      
      // If specific business provided, use only that business
      if (widget.businessId != null && widget.businessName != null) {
        availableBusinesses = [{
          'id': widget.businessId!,
          'name': widget.businessName!,
        }];
        selectedBusinessId = widget.businessId;
        selectedBusinessName = widget.businessName;
        if (mounted) setState(() {});
        return;
      }

      // Get employee's assigned businesses
      final employeeBusinesses = List<String>.from(widget.employee.business ?? []);
      
      // Find intersection of owner's businesses and employee's businesses
      final commonBusinesses = userBusinesses.where((id) => employeeBusinesses.contains(id)).toList();
      
      // If no common businesses, use all owner's businesses
      final businessesToLoad = commonBusinesses.isNotEmpty ? commonBusinesses : userBusinesses;

      // Load business names from Firestore
      availableBusinesses.clear();
      for (String businessId in businessesToLoad) {
        try {
          final businessName = await _fetchBusinessName(businessId);
          availableBusinesses.add({
            'id': businessId,
            'name': businessName,
          });
        } catch (e) {
          print('Error loading business $businessId: $e');
          // Add business with fallback name if fetch fails
          availableBusinesses.add({
            'id': businessId,
            'name': 'Business $businessId',
          });
        }
      }

      // Set default selection - prioritize employee's first business if available
      if (availableBusinesses.isNotEmpty) {
        if (commonBusinesses.isNotEmpty) {
          // Employee has businesses in common with owner - use first common business
          selectedBusinessId = commonBusinesses.first;
          selectedBusinessName = availableBusinesses.firstWhere((b) => b['id'] == commonBusinesses.first)['name'];
        } else {
          // Use owner's first business as fallback
          selectedBusinessId = availableBusinesses.first['id'];
          selectedBusinessName = availableBusinesses.first['name'];
        }
      }
      
      if (mounted) setState(() {}); // Refresh UI after loading
    } catch (e) {
      print('Error in _loadAvailableBusinesses: $e');
      // Ensure dialog doesn't stay in loading state
      if (mounted) setState(() {});
    }
  }

  Future<String> _fetchBusinessName(String businessId) async {
    try {
      // First try to get from current business controller
      if (_businessController.business['id'] == businessId) {
        return _businessController.business['name'] ?? 'Business $businessId';
      }
      
      // Fetch from Firestore
      final businessDoc = await FirebaseFirestore.instance
          .collection('businesses')
          .doc(businessId)
          .get();
      
      if (businessDoc.exists) {
        return businessDoc.data()?['name'] ?? 'Business $businessId';
      }
      
      return 'Business $businessId';
    } catch (e) {
      return 'Business $businessId';
    }
  }

  void _initializeFormData() {
    if (widget.existingPayRole != null) {
      final payRole = widget.existingPayRole!;
      selectedPayType = payRole.payType;
      selectedCurrency = payRole.currency;
      selectedPayPeriod = payRole.payPeriod;
      selectedPayDay = payRole.payDay;
      
      _payRateController.text = payRole.payRate.toString();
      _commissionRateController.text = payRole.commissionRate?.toString() ?? '';
      _notesController.text = payRole.notes ?? '';
    }
  }

  Future<void> _savePayRole() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedBusinessId == null) {
      Get.snackbar('Error', 'Please select a business');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final success = await _payRoleController.createOrUpdatePayRole(
        employeeId: widget.employee.id,
        employeeName: widget.employee.name,
        businessId: selectedBusinessId!,
        businessName: selectedBusinessName!,
        payType: selectedPayType,
        payRate: double.parse(_payRateController.text),
        commissionRate: _commissionRateController.text.isNotEmpty 
            ? double.parse(_commissionRateController.text) : null,
        currency: selectedCurrency,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        payPeriod: selectedPayPeriod,
        payDay: selectedPayDay,
        existingPayRoleId: widget.existingPayRole?.id,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error saving pay role: $e');
      if (mounted) {
        Get.snackbar('Error', 'Invalid input values: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existingPayRole != null 
                          ? 'Edit Pay Role' 
                          : 'Create Pay Role',
                      style: h5(Theme.of(context).textTheme.bodyLarge!.color),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Employee info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primaryColor,
                      child: Text(
                        widget.employee.name.isNotEmpty 
                            ? widget.employee.name[0].toUpperCase() 
                            : 'E',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.employee.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            widget.employee.role.replaceAll('_', ' ').capitalizeFirst!,
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Selection
                      if (availableBusinesses.length > 1) ...[
                        Text('Business', style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderColor),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedBusinessId,
                              isExpanded: true,
                              items: availableBusinesses.map((business) {
                                return DropdownMenuItem<String>(
                                  value: business['id'],
                                  child: Text(business['name']!),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  selectedBusinessId = value;
                                  selectedBusinessName = availableBusinesses
                                      .firstWhere((b) => b['id'] == value)['name'];
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Pay Type Selection
                      Text('Pay Type', style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PayType>(
                            value: selectedPayType,
                            isExpanded: true,
                            items: PayType.values.map((type) {
                              return DropdownMenuItem<PayType>(
                                value: type,
                                child: Text(type.toString().split('.').last.capitalizeFirst!),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedPayType = value!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pay Rate and Currency Row
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getPayRateLabel(), 
                                    style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _payRateController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                  decoration: InputDecoration(
                                    hintText: _getPayRateHint(),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Pay rate is required';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Enter a valid number';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Currency', style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: borderColor),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedCurrency,
                                      isExpanded: true,
                                      items: ['TZS', 'USD', 'EUR', 'KES'].map((currency) {
                                        return DropdownMenuItem<String>(
                                          value: currency,
                                          child: Text(currency),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          selectedCurrency = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Commission Rate (only for commission pay type)
                      if (selectedPayType == PayType.commission) ...[
                        Text('Commission Rate (%)', 
                            style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _commissionRateController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          decoration: InputDecoration(
                            hintText: 'e.g., 5.5 for 5.5%',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                          ),
                          validator: selectedPayType == PayType.commission ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Commission rate is required';
                            }
                            final rate = double.tryParse(value);
                            if (rate == null || rate < 0 || rate > 100) {
                              return 'Enter a valid percentage (0-100)';
                            }
                            return null;
                          } : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Pay Period
                      Text('Pay Period', 
                          style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PayPeriod>(
                            value: selectedPayPeriod,
                            isExpanded: true,
                            items: PayPeriod.values.map((period) {
                              return DropdownMenuItem<PayPeriod>(
                                value: period,
                                child: Text(period.toString().split('.').last.capitalizeFirst!),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedPayPeriod = value!;
                                // Reset pay day when period changes
                                selectedPayDay = selectedPayPeriod == PayPeriod.weekly ? 1 : 1;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Pay Day
                      Text(selectedPayPeriod == PayPeriod.weekly ? 'Pay Day (Day of Week)' : 'Pay Day (Day of Month)', 
                          style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: selectedPayDay,
                            isExpanded: true,
                            items: _getPayDayOptions().map((day) {
                              return DropdownMenuItem<int>(
                                value: day['value'] as int,
                                child: Text(day['label'] as String),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedPayDay = value!;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      Text('Notes (Optional)', 
                          style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Additional notes about this pay role...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: 'Cancel',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      text: isLoading ? 'Saving...' : 'Save Pay Role',
                      onPressed: isLoading ? () {} : _savePayRole,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPayRateLabel() {
    switch (selectedPayType) {
      case PayType.salary:
        final periodText = selectedPayPeriod == PayPeriod.weekly ? 'Weekly' : 'Monthly';
        return '$periodText Salary';
      case PayType.commission:
        return 'Base Amount';
    }
  }

  String _getPayRateHint() {
    switch (selectedPayType) {
      case PayType.salary:
        final periodText = selectedPayPeriod == PayPeriod.weekly ? 'weekly' : 'monthly';
        return 'Enter $periodText salary amount';
      case PayType.commission:
        return 'Base amount + commission';
    }
  }

  List<Map<String, dynamic>> _getPayDayOptions() {
    if (selectedPayPeriod == PayPeriod.weekly) {
      return [
        {'value': 1, 'label': 'Monday'},
        {'value': 2, 'label': 'Tuesday'},
        {'value': 3, 'label': 'Wednesday'},
        {'value': 4, 'label': 'Thursday'},
        {'value': 5, 'label': 'Friday'},
        {'value': 6, 'label': 'Saturday'},
        {'value': 7, 'label': 'Sunday'},
      ];
    } else {
      // Monthly - days 1-31
      return List.generate(31, (index) {
        final day = index + 1;
        String suffix = 'th';
        if (day % 10 == 1 && day != 11) suffix = 'st';
        else if (day % 10 == 2 && day != 12) suffix = 'nd';
        else if (day % 10 == 3 && day != 13) suffix = 'rd';
        
        return {
          'value': day,
          'label': '$day$suffix of month',
        };
      });
    }
  }
}
