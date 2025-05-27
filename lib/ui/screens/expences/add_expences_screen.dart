import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../controllers/expence_controller.dart';
import '../../../models/expences.dart';

class AddExpenseScreen extends StatefulWidget {
  @override
  _AddExpenseScreenState createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _selectedCategory = 'Food'.tr;
  final ExpenseController _expenseController = Get.find();

  bool _isLoading = false; // Variable to track loading state

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Expense'.tr),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Enter details'.tr,
                      border: InputBorder.none,
                    ),
                    maxLines: null, // Allow multiline input
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter details'.tr;
                      }
                      return null;
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    controller: _amountController,
                    decoration: InputDecoration(
                      labelText: 'Amount'.tr,
                      border: InputBorder.none,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount'.tr;
                      }
                      return null;
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: EdgeInsets.only(bottom: 16.0),
                  child: DropdownButtonFormField(
                    value: _selectedCategory,
                    items: ['Food'.tr, 'Transport'.tr, 'Electricity'.tr, 'Water'.tr, 'TV bills'.tr, 'Other'.tr]
                        .map((label) => DropdownMenuItem(
                      child: Text(label),
                      value: label,
                    ))
                        .toList(),
                    decoration: InputDecoration(
                      labelText: 'Category'.tr,
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value as String;
                      });
                    },
                  ),
                ),
                SizedBox(height: 20),
                _isLoading
                    ? CircularProgressIndicator() // Show loading indicator
                    : ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      setState(() {
                        _isLoading = true; // Start loading
                      });
                      final expense = Expense(
                        id: Uuid().v4(),
                        title: _titleController.text,
                        amount: double.parse(_amountController.text),
                        date: Timestamp.now(), // Automatically add the current date and time
                        category: _selectedCategory,
                      );
                      _expenseController.addExpense(expense).then((_) {
                        setState(() {
                          _isLoading = false; // Stop loading
                        });
                        Navigator.pop(context); // Go back after adding the expense
                      }).catchError((error) {
                        setState(() {
                          _isLoading = false; // Stop loading on error
                        });
                        // Show an error message if the expense fails to save
                        Get.snackbar('Error', 'Failed to add expense: $error');
                      });
                    }
                  },
                  child: Text('Save Expense'.tr),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
