import 'package:cloud_firestore/cloud_firestore.dart';

class DebtHistory {
  final String id; // Unique ID for the debt record
  final String client;
  final String name;// ID or name of the client
  final String owner; // Business or user who owns this debt record
  final double initialDebtAmount; // Total debt when initially recorded
  final double remainingDebtAmount; // Remaining debt after payments
  final List<Map<String, dynamic>> paymentRecords; // List of partial payments made by the client
  final Timestamp dateIncurred; // Date when the debt was incurred
  final Timestamp? dueDate;
  final int? creditDays;
  final String status; // Debt status (pending, partially paid, paid)
  final String comment; // Optional comment or description for the debt record

  DebtHistory({
    required this.id,
    required this.client,
    required this.name,
    required this.owner,
    required this.initialDebtAmount,
    required this.remainingDebtAmount,
    required this.paymentRecords,
    required this.dateIncurred,
    this.dueDate,
    this.creditDays,
    required this.status,
    required this.comment,
  });

  // Factory method to create a DebtHistory from Firestore snapshot
  static DebtHistory fromSnapshot(DocumentSnapshot snapshot) {
    var data = snapshot.data() as Map<String, dynamic>?;

    return DebtHistory(
      id: snapshot.id,
      client: data?['client'] ?? '',
      name: data?['name'] ?? '',
      owner: data?['owner'] ?? '',
      initialDebtAmount: (data?['initialDebtAmount'] ?? 0.0).toDouble(),
      remainingDebtAmount: (data?['remainingDebtAmount'] ?? 0.0).toDouble(),
      paymentRecords: List<Map<String, dynamic>>.from(data?['paymentRecords'] ?? []),
      dateIncurred: data?['dateIncurred'] ?? Timestamp.now(),
      dueDate: data?['dueDate'] is Timestamp ? data!['dueDate'] as Timestamp : null,
      creditDays: (data?['creditDays'] as num?)?.toInt(),
      status: data?['status'] ?? 'pending',
      comment: data?['comment'] ?? '',
    );
  }

  // Convert the DebtHistory object to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'client': client,
      'name': name,
      'owner': owner,
      'initialDebtAmount': initialDebtAmount,
      'remainingDebtAmount': remainingDebtAmount,
      'paymentRecords': paymentRecords,
      'dateIncurred': dateIncurred,
      if (dueDate != null) 'dueDate': dueDate,
      if (creditDays != null) 'creditDays': creditDays,
      'status': status,
      'comment': comment,
    };
  }
}
