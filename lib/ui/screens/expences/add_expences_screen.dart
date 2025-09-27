import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../controllers/expence_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../models/expences.dart';

class AddExpenseScreen extends StatefulWidget {
  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food'; // Keep English value internally
  final ExpenseController _expenseController = Get.find();
  final ProfileController _profileController = Get.find();

  bool _isLoading = false; // Variable to track loading state
  // New: Source of Funds state
  String _fundSource = 'cash'; // cash | bank | mobile | other
  String _fundSourceOtherNote = '';

  @override
  void initState() {
    super.initState();

    // CRITICAL SECURITY CHECK: Allow all roles except agent to add expenses
    final String userRole = _profileController.user['role'] ?? '';
    if (userRole == 'agent') {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: Agent tried to access AddExpenseScreen');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to add expenses',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense'.tr),
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
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 48,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'New Expense'.tr,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Track your business expenses'.tr,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Source of Funds field
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
                          DropdownButtonFormField<String>(
                            value: _fundSource,
                            items: const [
                              DropdownMenuItem(value: 'cash', child: Text('Cash')),
                              DropdownMenuItem(value: 'bank', child: Text('Bank')),
                              DropdownMenuItem(value: 'mobile', child: Text('Lipa Namba (Mobile)')),
                              DropdownMenuItem(value: 'other', child: Text('Other Source')),
                            ],
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
                          ),
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
                  // Save button
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
                              'Saving...'.tr,
                              style: TextStyle(
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
                        print('🔵 EXPENSE CREATION: Starting expense creation process');

                        if (_formKey.currentState!.validate()) {
                          print('✅ EXPENSE CREATION: Form validation passed');

                          setState(() {
                            _isLoading = true; // Start loading
                          });

                          final expense = Expense(
                            id: Uuid().v4(),
                            title: _titleController.text,
                            amount: double.parse(_amountController.text),
                            date: Timestamp.now(), // Automatically add the current date and time
                            category: _selectedCategory,
                            addedBy: _profileController.user['id'], // Add user ID who created the expense
                            addedByName: _profileController.user['name'] ?? 'Unknown', // Add user name who created the expense
                            fundSource: _fundSource,
                            fundSourceNote: _fundSource == 'other' ? _fundSourceOtherNote : '',
                          );

                          print('🔵 EXPENSE CREATION: Expense object created: ${expense.toMap()}');
                          print('🔵 EXPENSE CREATION: Calling ExpenseController.addExpense...');

                          _expenseController.addExpense(expense).then((_) {
                            print('✅ EXPENSE CREATION: ExpenseController.addExpense completed successfully');

                            setState(() {
                              _isLoading = false; // Stop loading
                            });
                            Navigator.pop(context); // Go back after adding the expense
                          }).catchError((error) {
                            print('❌ EXPENSE CREATION: ExpenseController.addExpense failed: $error');
                            print('❌ EXPENSE CREATION: Error type: ${error.runtimeType}');

                            setState(() {
                              _isLoading = false; // Stop loading on error
                            });
                            // Show an error message if the expense fails to save
                            Get.snackbar('Error', 'Failed to add expense: $error');
                          });
                        } else {
                          print('❌ EXPENSE CREATION: Form validation failed');
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
                                Icons.save,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Save Expense'.tr,
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