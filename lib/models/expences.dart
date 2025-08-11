// lib/models/expense.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Expense {
  String id;
  String title;
  double amount;
  Timestamp date;
  String category;
  String? addedBy; // User ID of person who added the expense
  String? addedByName; // Display name of person who added the expense

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.addedBy,
    this.addedByName,
  });

  factory Expense.fromMap(Map<String, dynamic> data, String id) {
    return Expense(
      id: id,
      title: data['title'],
      amount: data['amount'] is int ? (data['amount'] as int).toDouble() : (data['amount'] ?? 0.0),
      date: data?['date'] ?? Timestamp.now(),
      category: data['category'],
      addedBy: data['addedBy'], // Backward compatible - null for old expenses
      addedByName: data['addedByName'], // Backward compatible - null for old expenses
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'title': title,
      'amount': amount,
      'date': date,
      'category': category,
    };
    
    // Only add addedBy fields if they are not null
    if (addedBy != null) {
      map['addedBy'] = addedBy!;
    }
    if (addedByName != null) {
      map['addedByName'] = addedByName!;
    }
    
    return map;
  }
}
