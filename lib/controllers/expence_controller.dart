import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import '../controllers/business_controller.dart';
import '../models/expences.dart';
import '../services/firestore_db.dart';

class ExpenseController extends GetxController {
  final BusinessController _businessController = Get.find();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final expenses = <Expense>[].obs;
  final filteredExpenses = <Expense>[].obs;
  final filterClients = <String>[].obs;
  final filterEmployee = <String>[].obs;
  final dates = <DateTime>[].obs;

  DateTimeRange? selectedDateRange;
  StreamSubscription<List<Expense>>? _expenseSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _expenseSubscription = FirestoreDb().getExpenses().listen((data) {
        expenses.value = data;
        filteredExpenses.value = data;
      });
    } catch (e) {
      print("Error initializing ExpenseController: $e");
    }
  }

  @override
  void onClose() {
    _expenseSubscription?.cancel();
    super.onClose();
  }



  void setExpencesByDate() {
    dates.value = [];
    for (var i = 0; i < filteredExpenses.length; i++) {
      DateTime date = filteredExpenses[i].date.toDate();
      date = DateUtils.dateOnly(date);

      if (!dates.contains(date)) {
        dates.add(date);
      }
    }
    dates.sort((a, b) => b.compareTo(a));
  }
  void filterExpenses() {
    filteredExpenses.value = expenses;
    if (selectedDateRange != null) {
      filteredExpenses.value = filteredExpenses.where((expence) {
        return expence.date.toDate().isAfter(selectedDateRange!.start) &&
            expence.date
                .toDate()
                .isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }


    setExpencesByDate();
  }
  // Other methods and variables...

  double getTotalExpensesFromTimestamp(Timestamp startTimestamp,Timestamp endDate) {
    double totalExpenses = 0;
    Timestamp currentTimestamp = Timestamp.now();

    for (var expense in expenses) {
      // Ensure expense.date is of type DateTime and convert to Timestamp
      Timestamp expenseTimestamp = expense.date;

      // Check if the expenseTimestamp is within the specified range
      if (expenseTimestamp.compareTo(startTimestamp) > 0 && expenseTimestamp.compareTo(endDate) < 0) {
        totalExpenses += expense.amount ?? 0;
      }
        }

    return totalExpenses;
  }







  Future<void> addExpense(Expense expense) {
    print('🔵 EXPENSE CONTROLLER: addExpense called');
    
    final String? business = _businessController.business['id'];
    print('🔵 EXPENSE CONTROLLER: Business ID = $business');

    if (business == null) {
      print('❌ EXPENSE CONTROLLER: Business ID is null, cannot add expense.');
      return Future.value();
    }

    print('✅ EXPENSE CONTROLLER: Business ID validation passed');
    
    // Create document reference with auto-generated ID (like sales and clients)
    final newExpenseRef = _firestore
        .collection('expenses')
        .doc(business)
        .collection('userExpenses')
        .doc(); // Auto-generated ID
    
    print('🔵 EXPENSE CONTROLLER: Document reference created: ${newExpenseRef.path}');
    print('🔵 EXPENSE CONTROLLER: Expense data: ${expense.toMap()}');
    print('🔵 EXPENSE CONTROLLER: Attempting Firestore set operation...');

    // Use simple non-blocking pattern like client screen (works offline)
    newExpenseRef.set(expense.toMap()).then((_) {
      print('✅ EXPENSE CONTROLLER: Firestore set operation completed successfully');
    }).catchError((error) {
      print('❌ EXPENSE CONTROLLER: Firestore set operation failed: $error');
      print('❌ EXPENSE CONTROLLER: Error type: ${error.runtimeType}');
    });
    
    print('🔵 EXPENSE CONTROLLER: Firestore operation initiated (non-blocking)');
    
    // Return immediately resolved future (like client screen)
    return Future.value();
  }

  Future<void> updateExpense(Expense expense) {
    print('🔵 EXPENSE CONTROLLER: updateExpense called');
    
    final String? business = _businessController.business['id'];
    print('🔵 EXPENSE CONTROLLER: Business ID = $business');

    if (business == null) {
      print('❌ EXPENSE CONTROLLER: Business ID is null, cannot update expense.');
      return Future.value();
    }

    print('✅ EXPENSE CONTROLLER: Business ID validation passed');
    
    // Create document reference for the existing expense
    final expenseRef = _firestore
        .collection('expenses')
        .doc(business)
        .collection('userExpenses')
        .doc(expense.id);
    
    print('🔵 EXPENSE CONTROLLER: Document reference created: ${expenseRef.path}');
    print('🔵 EXPENSE CONTROLLER: Expense data: ${expense.toMap()}');
    print('🔵 EXPENSE CONTROLLER: Attempting Firestore update operation...');

    // Use simple non-blocking pattern like addExpense and client screen (works offline)
    expenseRef.update(expense.toMap()).then((_) {
      print('✅ EXPENSE CONTROLLER: Firestore update operation completed successfully');
    }).catchError((error) {
      print('❌ EXPENSE CONTROLLER: Firestore update operation failed: $error');
      print('❌ EXPENSE CONTROLLER: Error type: ${error.runtimeType}');
    });
    
    print('🔵 EXPENSE CONTROLLER: Firestore operation initiated (non-blocking)');
    
    // Return immediately resolved future for offline UX (like addExpense and client screen)
    return Future.value();
  }

  Future<void> deleteExpense(String expenseId) {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('business ID is null, cannot delete expense.');
      return Future.value();
    }

    return _firestore
        .collection('expenses')
        .doc(business)
        .collection('userExpenses')
        .doc(expenseId)
        .delete();
  }
  // Business Expense Category Management Methods
  Future<void> addExpenseCategory(String category) async {
    final String? business = _businessController.business['id'];
    if (business == null || category.trim().isEmpty) return;

    final trimmedCategory = category.trim();
    final currentCategories = getExpenseCategories();
    if (currentCategories.contains(trimmedCategory)) return;

    try {
      final updatedCategories = [...currentCategories, trimmedCategory];
      await _firestore
          .collection('businesses')
          .doc(business)
          .update({
        'expenseCategories': updatedCategories,
      });
      
      // Update local business data
      await _businessController.updateBusinessData();
    } catch (e) {
      print('Error adding expense category: $e');
      rethrow;
    }
  }

  Future<void> removeExpenseCategory(String category) async {
    final String? business = _businessController.business['id'];
    if (business == null) return;

    final currentCategories = getExpenseCategories();
    if (!currentCategories.contains(category)) return;

    try {
      final updatedCategories = currentCategories.where((c) => c != category).toList();
      await _firestore
          .collection('businesses')
          .doc(business)
          .update({
        'expenseCategories': updatedCategories,
      });
      
      // Update local business data
      await _businessController.updateBusinessData();
    } catch (e) {
      print('Error removing expense category: $e');
      rethrow;
    }
  }

  /// Get expense categories from business
  List<String> getExpenseCategories() {
    try {
      final businessExpenseCategories = _businessController.business['expenseCategories'];
      if (businessExpenseCategories != null && businessExpenseCategories is List) {
        return List<String>.from(businessExpenseCategories)
            .where((category) => category != null && category.toString().trim().isNotEmpty)
            .map((category) => category.toString().trim())
            .toList();
      }
    } catch (e) {
      print('Error getting expense categories: $e');
    }
    return [];
  }

  List<String> getAllCategories() {
    final defaultCategories = [
      'Food', 'Transport', 'Electricity', 'Water', 'TV bills',
      'Internet', 'Phone', 'Rent', 'Office Supplies', 'Marketing',
      'Maintenance', 'Insurance', 'Fuel', 'Training', 'Legal', 
      'Accounting', 'Bank Charges', 'Taxes', 'Salaries', 'Other'
    ];
    
    // Get business expense categories and put them at the top
    final businessExpenseCategories = getExpenseCategories();
    
    // Combine categories and remove duplicates using Set
    final allCategories = [...businessExpenseCategories, ...defaultCategories];
    
    // Remove duplicates and maintain order (business categories first)
    final uniqueCategories = <String>[];
    final seen = <String>{};
    
    for (final category in allCategories) {
      if (category.isNotEmpty && !seen.contains(category)) {
        uniqueCategories.add(category);
        seen.add(category);
      }
    }
    
    return uniqueCategories;
  }

  void clearExpense(){
    expenses.value.clear();
    filterClients.value.clear();
    filteredExpenses.value.clear();
  }
}
