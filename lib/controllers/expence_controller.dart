import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import '../controllers/business_controller.dart';
import '../models/expences.dart';
import '../services/firestore_db.dart';
import '../services/ledger_service.dart';

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
  StreamSubscription<List<Expense>>? _filteredExpenseSubscription;

  @override
  void onInit() {
    super.onInit();
    
    final ProfileController _profileController = Get.find();
    final String userRole = _profileController.user['role'] ?? '';
    
    // Load expenses for all roles except agents (cashiers and sales persons need to see expenses)
    if (userRole != 'agent') {
      try {
        _expenseSubscription = FirestoreDb().getExpenses().listen((data) {
          expenses.value = data;
          filteredExpenses.value = data;
        });
      } catch (e) {
        print("Error initializing ExpenseController: $e");
      }
    } else {
      // Set empty data for agents (no error)
      expenses.value = [];
      filteredExpenses.value = [];
      print('ExpenseController: Agents cannot view expenses, skipping data initialization');
    }
  }

  @override
  void onClose() {
    _expenseSubscription?.cancel();
    _filteredExpenseSubscription?.cancel();
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
  void filterExpenses() async {
    // If date range is selected, query database for that range
    if (selectedDateRange != null) {
      // Cancel previous filtered subscription if exists
      await _filteredExpenseSubscription?.cancel();
      
      // Query database for the selected date range
      _filteredExpenseSubscription = FirestoreDb()
          .getExpensesByDateRange(selectedDateRange!.start, selectedDateRange!.end)
          .listen((data) {
        filteredExpenses.value = data;
        setExpencesByDate();
      });
    } else {
      // No date range selected, use in-memory filtering
      await _filteredExpenseSubscription?.cancel();
      filteredExpenses.value = expenses;
      setExpencesByDate();
    }
  }

  void setSelectedDateRange(DateTimeRange dateRange) {
    selectedDateRange = dateRange;
    filterExpenses();
  }

  void clearSelectedDateRange() async {
    selectedDateRange = null;
    await _filteredExpenseSubscription?.cancel();
    _filteredExpenseSubscription = null;
    filterExpenses();
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
    newExpenseRef.set(expense.toMap()).then((_) async {
      print('✅ EXPENSE CONTROLLER: Firestore set operation completed successfully');
      // Post ledger OUT entry for this expense using the actual Firestore doc ID for consistency
      try {
        final expenseWithSavedId = Expense(
          id: newExpenseRef.id,
          title: expense.title,
          amount: expense.amount,
          date: expense.date,
          category: expense.category,
          addedBy: expense.addedBy,
          addedByName: expense.addedByName,
          fundSource: expense.fundSource,
          fundSourceNote: expense.fundSource == 'other' ? (expense.fundSourceNote) : '',
        );
        await LedgerService().postExpenseOut(expenseWithSavedId);
        print('✅ EXPENSE CONTROLLER: Ledger OUT entry posted for expense ${newExpenseRef.id}');
      } catch (e) {
        print('⚠️ EXPENSE CONTROLLER: Failed to post ledger entry for expense ${newExpenseRef.id}: $e');
      }
    }).catchError((error) {
      print('❌ EXPENSE CONTROLLER: Firestore set operation failed: $error');
      print('❌ EXPENSE CONTROLLER: Error type: ${error.runtimeType}');
    });
    
    print('🔵 EXPENSE CONTROLLER: Firestore operation initiated (non-blocking)');
    
    // Return immediately resolved future (like client screen)
    return Future.value();
  }

  Future<void> updateExpense(Expense expense) async {
    print('🔵 EXPENSE CONTROLLER: updateExpense called');
    
    final String? business = _businessController.business['id'];
    print('🔵 EXPENSE CONTROLLER: Business ID = $business');

    if (business == null) {
      print('❌ EXPENSE CONTROLLER: Business ID is null, cannot update expense.');
      return Future.value();
    }

    print('✅ EXPENSE CONTROLLER: Business ID validation passed');
    
    // Get the old expense to compare fundSource changes
    try {
      final oldExpenseDoc = await _firestore
          .collection('expenses')
          .doc(business)
          .collection('userExpenses')
          .doc(expense.id)
          .get();
      
      final oldFundSource = oldExpenseDoc.data()?['fundSource'] ?? 'cash';
      
      // Delete old ledger entry if fundSource changed
      if (oldFundSource != expense.fundSource) {
        print('🔄 EXPENSE CONTROLLER: Fund source changed from $oldFundSource to ${expense.fundSource}');
        await _deleteLedgerEntry(business, expense.id, oldFundSource);
      } else {
        // Same fund source, delete the existing entry to update it
        await _deleteLedgerEntry(business, expense.id, expense.fundSource);
      }
    } catch (e) {
      print('⚠️ EXPENSE CONTROLLER: Failed to delete old ledger entry: $e');
    }
    
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
    expenseRef.update(expense.toMap()).then((_) async {
      print('✅ EXPENSE CONTROLLER: Firestore update operation completed successfully');
      
      // Post new ledger entry with updated data
      try {
        await LedgerService().postExpenseOut(expense);
        print('✅ EXPENSE CONTROLLER: New ledger OUT entry posted for updated expense ${expense.id}');
      } catch (e) {
        print('⚠️ EXPENSE CONTROLLER: Failed to post new ledger entry for updated expense ${expense.id}: $e');
      }
    }).catchError((error) {
      print('❌ EXPENSE CONTROLLER: Firestore update operation failed: $error');
      print('❌ EXPENSE CONTROLLER: Error type: ${error.runtimeType}');
    });
    
    print('🔵 EXPENSE CONTROLLER: Firestore operation initiated (non-blocking)');
    
    // Return immediately resolved future for offline UX (like addExpense and client screen)
    return Future.value();
  }

  Future<void> deleteExpense(String expenseId) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('business ID is null, cannot delete expense.');
      return Future.value();
    }

    try {
      // Get expense data to find fundSource before deleting
      final expenseDoc = await _firestore
          .collection('expenses')
          .doc(business)
          .collection('userExpenses')
          .doc(expenseId)
          .get();
      
      if (expenseDoc.exists) {
        final fundSource = expenseDoc.data()?['fundSource'] ?? 'cash';
        
        // Delete the expense document
        await _firestore
            .collection('expenses')
            .doc(business)
            .collection('userExpenses')
            .doc(expenseId)
            .delete();
        
        print('✅ EXPENSE CONTROLLER: Expense $expenseId deleted from Firestore');
        
        // Delete corresponding ledger entry
        await _deleteLedgerEntry(business, expenseId, fundSource);
        print('✅ EXPENSE CONTROLLER: Ledger entry deleted for expense $expenseId');
      }
    } catch (e) {
      print('❌ EXPENSE CONTROLLER: Error deleting expense $expenseId: $e');
      rethrow;
    }
  }
  
  // Helper method to delete ledger entry for an expense
  Future<void> _deleteLedgerEntry(String businessId, String expenseId, String fundSource) async {
    try {
      // Build the ledger document ID using same pattern as LedgerService.postExpenseOut
      final String lineIndex = '0';
      final String idempotencyKey = 'expense:$expenseId:$lineIndex:$fundSource';
      final String docId = idempotencyKey.replaceAll(':', '__');
      
      final ledgerRef = _firestore
          .collection('ledger')
          .doc(businessId)
          .collection('entries')
          .doc(docId);
      
      // Check if ledger entry exists before deleting
      final ledgerDoc = await ledgerRef.get();
      if (ledgerDoc.exists) {
        await ledgerRef.delete();
        print('✅ EXPENSE CONTROLLER: Ledger entry $docId deleted');
      } else {
        print('ℹ️ EXPENSE CONTROLLER: Ledger entry $docId does not exist, skipping');
      }
    } catch (e) {
      print('❌ EXPENSE CONTROLLER: Error deleting ledger entry for expense $expenseId: $e');
      throw e;
    }
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
