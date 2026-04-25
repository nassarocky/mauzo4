import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentStatus {
  pending,
  paid,
  overdue,
  cancelled,
}

class PaymentRecord {
  final String id;
  final String payRoleId;
  final String employeeId;
  final String employeeName;
  final String businessId;
  final String businessName;
  
  // Payment details
  final double amount;
  final String currency;
  final PaymentStatus status;
  final String? paymentMethod;
  final String? referenceNumber;
  
  // Dates
  final DateTime payPeriodStart;
  final DateTime payPeriodEnd;
  final DateTime dueDate;
  final DateTime? paidDate;
  
  // Audit trail
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String? paidBy;
  final String? notes;
  
  // Additional details
  final double? hoursWorked;
  final double? overtimeHours;
  final double? commissionEarned;
  final double? bonusAmount;
  final double? deductions;
  
  // Pay schedule info
  final String? payPeriod; // 'weekly' or 'monthly'
  final String? payType; // 'hourly', 'salary', 'commission', 'fixed'

  // Breakdown fields
  final double? grossSalary; // pre-deduction amount
  final double? advanceDeductions; // total early payments deducted
  final double? lossDeductions; // total employee losses deducted
  final List<String>? deductedEarlyPaymentIds; // early payment IDs applied in this payroll
  final List<String>? deductedLossIds; // loss IDs applied in this payroll
  // New: partial deduction details and carryover
  final List<Map<String, dynamic>>? appliedEarlyPaymentDetails; // [{id, amount}]
  final List<Map<String, dynamic>>? appliedLossDetails; // [{id, amount}]
  final double? carryoverDeductions; // total amount not covered this period

  PaymentRecord({
    required this.id,
    required this.payRoleId,
    required this.employeeId,
    required this.employeeName,
    required this.businessId,
    required this.businessName,
    required this.amount,
    required this.currency,
    required this.status,
    this.paymentMethod = 'cash',
    this.referenceNumber,
    required this.payPeriodStart,
    required this.payPeriodEnd,
    required this.dueDate,
    this.paidDate,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.paidBy,
    this.notes,
    this.hoursWorked,
    this.overtimeHours,
    this.commissionEarned,
    this.bonusAmount,
    this.deductions,
    this.payPeriod,
    this.payType,
    this.grossSalary,
    this.advanceDeductions,
    this.lossDeductions,
    this.deductedEarlyPaymentIds,
    this.deductedLossIds,
    this.appliedEarlyPaymentDetails,
    this.appliedLossDetails,
    this.carryoverDeductions,
  });

  // Factory method to create PaymentRecord from Firestore snapshot
  static PaymentRecord fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
  print('PaymentRecord.fromSnapshot: Received data with status: ${data?['status']} for doc ${snapshot.id}');
    if (data == null) throw Exception("Payment record document data is null");

    return PaymentRecord(
      id: snapshot.id,
      payRoleId: data['payRoleId'] ?? '',
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
      amount: data['amount']?.toDouble() ?? 0.0,
      currency: data['currency'] ?? 'TZS',
      status: getPaymentStatus(data['status']),
      paymentMethod: data['paymentMethod']?.toString() ?? 'cash',
      referenceNumber: data['referenceNumber'],
      payPeriodStart: (data['payPeriodStart'] as Timestamp).toDate(),
      payPeriodEnd: (data['payPeriodEnd'] as Timestamp).toDate(),
      dueDate: (data['dueDate'] as Timestamp).toDate(),
      paidDate: (data['paidDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      paidBy: data['paidBy'],
      notes: data['notes'],
      hoursWorked: data['hoursWorked']?.toDouble(),
      overtimeHours: data['overtimeHours']?.toDouble(),
      commissionEarned: data['commissionEarned']?.toDouble(),
      bonusAmount: data['bonusAmount']?.toDouble(),
      deductions: data['deductions']?.toDouble(),
      payPeriod: data['payPeriod'],
      payType: data['payType'],
      grossSalary: data['grossSalary'] != null ? (data['grossSalary'] as num).toDouble() : null,
      advanceDeductions: data['advanceDeductions'] != null ? (data['advanceDeductions'] as num).toDouble() : null,
      lossDeductions: data['lossDeductions'] != null ? (data['lossDeductions'] as num).toDouble() : null,
      deductedEarlyPaymentIds: data['deductedEarlyPaymentIds'] != null
          ? List<String>.from((data['deductedEarlyPaymentIds'] as List).map((e) => e.toString()))
          : null,
      deductedLossIds: data['deductedLossIds'] != null
          ? List<String>.from((data['deductedLossIds'] as List).map((e) => e.toString()))
          : null,
      appliedEarlyPaymentDetails: data['appliedEarlyPaymentDetails'] != null
          ? List<Map<String, dynamic>>.from((data['appliedEarlyPaymentDetails'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : null,
      appliedLossDetails: data['appliedLossDetails'] != null
          ? List<Map<String, dynamic>>.from((data['appliedLossDetails'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
          : null,
      carryoverDeductions: data['carryoverDeductions'] != null ? (data['carryoverDeductions'] as num).toDouble() : null,
    );
  }

  static PaymentStatus getPaymentStatus(String? status) {
    switch (status) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'overdue':
        return PaymentStatus.overdue;
      case 'cancelled':
        return PaymentStatus.cancelled;
      default:
        return PaymentStatus.pending;
    }
  }

  // Method to convert PaymentRecord to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'payRoleId': payRoleId,
      'employeeId': employeeId,
      'employeeName': employeeName,
      'businessId': businessId,
      'businessName': businessName,
      'amount': amount,
      'currency': currency,
      'status': status.toString().split('.').last,
      'paymentMethod': paymentMethod ?? 'cash',
      'referenceNumber': referenceNumber,
      'payPeriodStart': Timestamp.fromDate(payPeriodStart),
      'payPeriodEnd': Timestamp.fromDate(payPeriodEnd),
      'dueDate': Timestamp.fromDate(dueDate),
      'paidDate': paidDate != null ? Timestamp.fromDate(paidDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'createdBy': createdBy,
      'paidBy': paidBy,
      'notes': notes,
      'hoursWorked': hoursWorked,
      'overtimeHours': overtimeHours,
      'commissionEarned': commissionEarned,
      'bonusAmount': bonusAmount,
      'deductions': deductions,
      'payPeriod': payPeriod,
      'payType': payType,
      'grossSalary': grossSalary,
      'advanceDeductions': advanceDeductions,
      'lossDeductions': lossDeductions,
      'deductedEarlyPaymentIds': deductedEarlyPaymentIds,
      'deductedLossIds': deductedLossIds,
      'appliedEarlyPaymentDetails': appliedEarlyPaymentDetails,
      'appliedLossDetails': appliedLossDetails,
      'carryoverDeductions': carryoverDeductions,
    };
  }

  // Helper methods
  String getFormattedAmount(String currency) {
    return '${amount.toStringAsFixed(2)} $currency';
  }

  String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  int getOverdueDays() {
    if (status == PaymentStatus.paid) return 0;
    
    final now = DateTime.now();
    final daysDiff = now.difference(dueDate).inDays;
    return daysDiff > 0 ? daysDiff : 0;
  }

  bool get isOverdue {
    return status != PaymentStatus.paid && DateTime.now().isAfter(dueDate);
  }

  String getOverdueStatusText() {
    if (status == PaymentStatus.paid) return 'Paid';
    
    final overdueDays = getOverdueDays();
    if (overdueDays == 0) {
      final daysUntilDue = dueDate.difference(DateTime.now()).inDays;
      if (daysUntilDue == 0) return 'Due today';
      if (daysUntilDue > 0) return 'Due in $daysUntilDue day${daysUntilDue > 1 ? 's' : ''}';
      return 'Due';
    }
    
    return 'Overdue by $overdueDays day${overdueDays > 1 ? 's' : ''}';
  }

  String getFormattedPayPeriod() {
    return '${formatDate(payPeriodStart)} - ${formatDate(payPeriodEnd)}';
  }

  double getNetAmount() {
    return amount - (deductions ?? 0.0);
  }

  // Copy with method for updates
  PaymentRecord copyWith({
    PaymentStatus? status,
    String? paymentMethod,
    String? referenceNumber,
    DateTime? paidDate,
    DateTime? updatedAt,
    String? paidBy,
    String? notes,
    double? hoursWorked,
    double? overtimeHours,
    double? commissionEarned,
    double? bonusAmount,
    double? deductions,
    String? payType,
  }) {
    return PaymentRecord(
      id: id,
      payRoleId: payRoleId,
      employeeId: employeeId,
      employeeName: employeeName,
      businessId: businessId,
      businessName: businessName,
      amount: amount,
      currency: currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      payPeriodStart: payPeriodStart,
      payPeriodEnd: payPeriodEnd,
      dueDate: dueDate,
      paidDate: paidDate ?? this.paidDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      paidBy: paidBy ?? this.paidBy,
      notes: notes ?? this.notes,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      commissionEarned: commissionEarned ?? this.commissionEarned,
      bonusAmount: bonusAmount ?? this.bonusAmount,
      deductions: deductions ?? this.deductions,
      payPeriod: payPeriod,
      payType: payType ?? this.payType,
    );
  }
}
