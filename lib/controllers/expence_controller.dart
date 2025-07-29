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
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('business ID is null, cannot update expense.');
      return Future.value();
    }

    return _firestore
        .collection('expenses')
        .doc(business)
        .collection('userExpenses')
        .doc(expense.id)
        .update(expense.toMap());
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
  void clearExpense(){
    expenses.value.clear();
    filterClients.value.clear();
    filteredExpenses.value.clear();
  }
}
