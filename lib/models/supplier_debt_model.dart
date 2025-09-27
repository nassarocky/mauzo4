import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierDebt {
  final String id; // Unique ID for the debt record
  final String supplier; // ID of the supplier
  final String supplierName; // Name of the supplier
  final String owner; // Business ID who owes this debt
  final double initialDebtAmount; // Total debt when initially recorded
  final double remainingDebtAmount; // Remaining debt after payments
  final List<Map<String, dynamic>> paymentRecords; // List of partial payments made to supplier
  final Timestamp dateIncurred; // Date when the debt was incurred
  final String status; // Debt status (pending, partially_paid, paid)
  final String comment; // Optional comment or description for the debt record
  final String employeeId; // ID of employee who made the purchase
  final String employeeName; // Name of employee who made the purchase
  final String? purchaseId; // ID of the purchase transaction that created this debt
  final List<Map<String, dynamic>>? products; // List of products purchased on debt

  SupplierDebt({
    required this.id,
    required this.supplier,
    required this.supplierName,
    required this.owner,
    required this.initialDebtAmount,
    required this.remainingDebtAmount,
    required this.paymentRecords,
    required this.dateIncurred,
    required this.status,
    required this.comment,
    required this.employeeId,
    required this.employeeName,
    this.purchaseId,
    this.products,
  });

  // Factory method to create a SupplierDebt from Firestore snapshot
  static SupplierDebt fromSnapshot(DocumentSnapshot snapshot) {
    var data = snapshot.data() as Map<String, dynamic>?;

    return SupplierDebt(
      id: snapshot.id,
      supplier: data?['supplier'] ?? '',
      supplierName: data?['supplierName'] ?? '',
      owner: data?['owner'] ?? '',
      initialDebtAmount: (data?['initialDebtAmount'] ?? 0.0).toDouble(),
      remainingDebtAmount: (data?['remainingDebtAmount'] ?? 0.0).toDouble(),
      paymentRecords: List<Map<String, dynamic>>.from(data?['paymentRecords'] ?? []),
      dateIncurred: data?['dateIncurred'] ?? Timestamp.now(),
      status: data?['status'] ?? 'pending',
      comment: data?['comment'] ?? '',
      employeeId: data?['employeeId'] ?? '',
      employeeName: data?['employeeName'] ?? '',
      purchaseId: data?['purchaseId'],
      products: data?['products'] != null 
          ? List<Map<String, dynamic>>.from(data!['products']) 
          : null,
    );
  }

  // Convert the SupplierDebt object to a Map for storing in Firestore
  Map<String, dynamic> toMap() {
    return {
      'supplier': supplier,
      'supplierName': supplierName,
      'owner': owner,
      'initialDebtAmount': initialDebtAmount,
      'remainingDebtAmount': remainingDebtAmount,
      'paymentRecords': paymentRecords,
      'dateIncurred': dateIncurred,
      'status': status,
      'comment': comment,
      'employeeId': employeeId,
      'employeeName': employeeName,
      if (purchaseId != null) 'purchaseId': purchaseId,
      if (products != null) 'products': products,
    };
  }
}
