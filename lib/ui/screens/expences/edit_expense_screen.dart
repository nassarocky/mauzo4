import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../controllers/expence_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../controllers/business_controller.dart';
import '../../../models/expences.dart';

class EditExpenseScreen extends StatefulWidget {
  @override
  _EditExpenseScreenState createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food'; // Keep English value internally
  final ExpenseController _expenseController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  bool _isLoading = false;
  Expense? _expense;
  DateTime? _selectedDate;
  // New: Source of Funds state
  String _fundSource = 'cash'; // cash | bank | mobile | other
  String _fundSourceOtherNote = '';

  @override
  void initState() {
    super.initState();

    // CRITICAL SECURITY CHECK: Only allow owners and managers to edit expenses
    final String userRole = _profileController.user['role'] ?? '';
    if (userRole != 'owner' && userRole != 'manager') {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: ${userRole} tried to access EditExpenseScreen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to edit expenses',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }

    // Get the expense from route arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final expense = ModalRoute.of(context)?.settings.arguments as Expense?;
        if (expense != null) {
          setState(() {
            _expense = expense;
            _titleController.text = expense.title;
            _amountController.text = expense.amount?.toString() ?? '';
            
            // Validate that the expense category exists in current categories
            final availableCategories = _expenseController.getAllCategories();
            if (availableCategories.contains(expense.category)) {
              _selectedCategory = expense.category;
            } else {
              // If expense category doesn't exist in current list, use first available category
              _selectedCategory = availableCategories.isNotEmpty ? availableCategories.first : 'Food';
              print('⚠️ EditExpenseScreen: Expense category "${expense.category}" not found in available categories. Using "$_selectedCategory" instead.');
            }
            _selectedDate = expense.date.toDate(); // Fix Timestamp to DateTime conversion errors
            // Initialize fund source from existing expense
            _fundSource = expense.fundSource;
            _fundSourceOtherNote = expense.fundSourceNote;
          });
        } else {
          // No expense provided - show error and go back
          print('❌ EditExpenseScreen: No expense provided in route arguments');
          Navigator.of(context).pop();
          Get.snackbar(
            'Error',
            'No expense data provided for editing',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
          );
        }
      } catch (e) {
        // Error parsing expense argument
        print('❌ EditExpenseScreen: Error parsing expense argument: $e');
        Navigator.of(context).pop();
        Get.snackbar(
          'Error',
          'Invalid expense data provided',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    });
  }

  String _effectiveFundSourceValue() {
    final rows = _businessController.paymentMethodsForDropdown(
        currentValue: _fundSource);
    if (rows.isEmpty) return _fundSource;
    final values = rows
        .map((e) => e['value']?.toString() ?? '')
        .where((v) => v.isNotEmpty)
        .toList();
    if (values.contains(_fundSource)) return _fundSource;
    final first = rows.first['value']?.toString();
    return (first != null && first.isNotEmpty) ? first : _fundSource;
  }

  void _showAddCategoryDialog() {
    final TextEditingController categoryController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Custom Category'.tr),
        content: TextField(
          controller: categoryController,
          decoration: InputDecoration(
            labelText: 'Category Name'.tr,
            hintText: 'Enter category name'.tr,
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          TextButton(
            onPressed: () async {
              final categoryName = categoryController.text.trim();
              if (categoryName.isNotEmpty) {
                try {
                  await _expenseController.addExpenseCategory(categoryName);
                  setState(() {
                    _selectedCategory = categoryName; // Use English value, not translated
                  });
                  Navigator.pop(context);
                  Get.snackbar(
                    'Success'.tr,
                    'Category added successfully'.tr,
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                } catch (e) {
                  Get.snackbar(
                    'Error'.tr,
                    'Failed to add category: $e',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                  );
                }
              }
            },
            child: Text('Add'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_expense == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Edit Expense'.tr),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Expense'.tr),
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).textTheme.titleLarge?.color,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.edit,
                          color: Colors.white,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Edit Expense'.tr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Update your expense details'.tr,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Details field
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.description, color: Colors.blue.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Expense Details'.tr,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              hintText: 'Enter expense details...'.tr,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            maxLines: 3,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter details'.tr;
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                // Source of Funds field
                if (((_businessController.business['multiFundEnabled'] ?? false) == true))
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.grey.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: Colors.purple.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Source of Funds'.tr,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Obx(() {
                          final items = _businessController
                              .paymentMethodsForDropdown(
                                  currentValue: _fundSource)
                              .map((fs) {
                                final v = fs['value']?.toString() ?? '';
                                if (v.isEmpty) return null;
                                return DropdownMenuItem<String>(
                                  value: v,
                                  child: Text(
                                      fs['label']?.toString() ?? v),
                                );
                              })
                              .whereType<DropdownMenuItem<String>>()
                              .toList();
                          if (items.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'Loading fund sources...'.tr,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            );
                          }
                          return DropdownButtonFormField<String>(
                          value: _effectiveFundSourceValue(),
                          items: items,
                          decoration: InputDecoration(
                            hintText: 'Select source of funds...'.tr,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            prefixIcon: Icon(Icons.account_balance, color: Colors.purple.shade600),
                          ),
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _fundSource = val;
                              if (_fundSource != 'other') _fundSourceOtherNote = '';
                            });
                          },
                        );
                        }),
                        if (_fundSource == 'other') ...[
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Describe other source (optional)'.tr,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.purple.shade400, width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (v) => _fundSourceOtherNote = v,
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                  // Amount field
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.attach_money, color: Colors.green.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Amount'.tr,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _amountController,
                            decoration: InputDecoration(
                              hintText: 'Enter amount...'.tr,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.green.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: Icon(Icons.currency_exchange, color: Colors.green.shade600),
                            ),
                            keyboardType: TextInputType.numberWithOptions(decimal: true),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter an amount'.tr;
                              }
                              if (double.tryParse(value) == null) {
                                return 'Please enter a valid number'.tr;
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Date field
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.blue.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Date'.tr,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDate != null
                                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                      : 'Select Date'.tr,
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final DateTime? pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      _selectedDate = pickedDate;
                                    });
                                  }
                                },
                                child: Text('Select Date'.tr),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Category field
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [Colors.white, Colors.grey.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.category, color: Colors.orange.shade600, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Category'.tr,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange.shade600,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () => _showAddCategoryDialog(),
                                icon: Icon(Icons.add, size: 16, color: Colors.orange.shade600),
                                label: Text(
                                  'Add New'.tr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Obx(() => DropdownButtonFormField(
                            value: _selectedCategory,
                            items: _expenseController.getAllCategories().map((label) => DropdownMenuItem(
                              value: label, // Use English value internally
                              child: Text(label.tr), // Display translated text
                            )).toList(),
                            decoration: InputDecoration(
                              hintText: 'Select category...'.tr,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.orange.shade400, width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              prefixIcon: Icon(Icons.label, color: Colors.orange.shade600),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _selectedCategory = value as String;
                              });
                            },
                          )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Update button
                  Container(
                    width: double.infinity,
                    height: 56,
                    child: _isLoading
                        ? Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.grey.shade400, Colors.grey.shade500],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Updating...'.tr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 6,
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          setState(() {
                            _isLoading = true;
                          });

                          final updatedExpense = Expense(
                            id: _expense!.id,
                            title: _titleController.text,
                            amount: double.parse(_amountController.text),
                            date: _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : _expense!.date, // Convert DateTime to Timestamp
                            category: _selectedCategory,
                            addedBy: _expense!.addedBy, // Keep original creator
                            addedByName: _expense!.addedByName, // Keep original creator name
                            fundSource: _fundSource,
                            fundSourceNote: _fundSource == 'other' ? _fundSourceOtherNote : '',
                          );

                          _expenseController.updateExpense(updatedExpense).then((_) {
                            setState(() {
                              _isLoading = false;
                            });
                            Navigator.pop(context);
                            Get.snackbar(
                              'Success'.tr,
                              'Expense updated successfully'.tr,
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );
                          }).catchError((error) {
                            setState(() {
                              _isLoading = false;
                            });
                            Get.snackbar(
                              'Error'.tr,
                              'Failed to update expense: $error',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade600],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.update,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Update Expense'.tr,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
