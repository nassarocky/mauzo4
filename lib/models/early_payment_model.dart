import 'package:cloud_firestore/cloud_firestore.dart';

class EarlyPaymentModel {
  final String paymentId;
  final String employeeId;
  final String employeeName;
  final String businessId;
  final String businessName;
  final double amount;
  final String reason;
  final DateTime dateRequested;
  final DateTime dateApproved;
  final DateTime? datePaid;
  final String approvedBy; // Owner/Manager who approved
  final String approvedByName;
  final String? paidBy; // Who actually made the payment
  final String? paidByName;
  final String paymentMethod; // 'cash', 'bank_transfer', 'mobile_money', 'check'
  final String status; // 'requested', 'approved', 'paid', 'rejected'
  final bool isDeductedFromSalary; // Whether this has been deducted from next salary
  final String? deductedInPayrollId; // Reference to payroll where it was deducted
  final DateTime? dateDeducted;
  final String? notes;
  final String? rejectionReason;
  final double amountDeductedFromSalary;

  EarlyPaymentModel({
    required this.paymentId,
    required this.employeeId,
    required this.employeeName,
    required this.businessId,
    required this.businessName,
    required this.amount,
    required this.reason,
    required this.dateRequested,
    required this.dateApproved,
    this.datePaid,
    required this.approvedBy,
    required this.approvedByName,
    this.paidBy,
    this.paidByName,
    this.paymentMethod = 'cash',
    this.status = 'requested',
    this.isDeductedFromSalary = false,
    this.deductedInPayrollId,
    this.dateDeducted,
    this.notes,
    this.rejectionReason,
    this.amountDeductedFromSalary = 0.0,
  });

  // Convert from Firestore document
  factory EarlyPaymentModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return EarlyPaymentModel(
      paymentId: snapshot.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      reason: data['reason'] ?? '',
      dateRequested: (data['dateRequested'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateApproved: (data['dateApproved'] as Timestamp?)?.toDate() ?? DateTime.now(),
      datePaid: (data['datePaid'] as Timestamp?)?.toDate(),
      approvedBy: data['approvedBy'] ?? '',
      approvedByName: data['approvedByName'] ?? '',
      paidBy: data['paidBy'],
      paidByName: data['paidByName'],
      paymentMethod: data['paymentMethod'] ?? 'cash',
      status: data['status'] ?? 'requested',
      isDeductedFromSalary: data['isDeductedFromSalary'] ?? false,
      deductedInPayrollId: data['deductedInPayrollId'],
      dateDeducted: (data['dateDeducted'] as Timestamp?)?.toDate(),
      notes: data['notes'],
      rejectionReason: data['rejectionReason'],
      amountDeductedFromSalary: (data['amountDeductedFromSalary'] ?? 0.0).toDouble(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'businessId': businessId,
      'businessName': businessName,
      'amount': amount,
      'reason': reason,
      'dateRequested': Timestamp.fromDate(dateRequested),
      'dateApproved': Timestamp.fromDate(dateApproved),
      'datePaid': datePaid != null ? Timestamp.fromDate(datePaid!) : null,
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'paidBy': paidBy,
      'paidByName': paidByName,
      'paymentMethod': paymentMethod,
      'status': status,
      'isDeductedFromSalary': isDeductedFromSalary,
      'deductedInPayrollId': deductedInPayrollId,
      'dateDeducted': dateDeducted != null ? Timestamp.fromDate(dateDeducted!) : null,
      'notes': notes,
      'rejectionReason': rejectionReason,
      'amountDeductedFromSalary': amountDeductedFromSalary,
    };
  }

  // Helper methods
  String get formattedAmount => amount.toStringAsFixed(2);
  
  String get paymentMethodDisplayName {
    switch (paymentMethod) {
      case 'cash':
        return 'Cash';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'mobile_money':
        return 'Mobile Money';
      case 'check':
        return 'Check';
      default:
        return paymentMethod;
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'requested':
        return 'Pending Approval';
      case 'approved':
        return 'Approved - Pending Payment';
      case 'paid':
        return 'Paid';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  bool get isPending => status == 'requested';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';
  bool get isRejected => status == 'rejected';

  double get outstandingAmount {
    final out = amount - amountDeductedFromSalary;
    return out > 0 ? out : 0.0;
  }

  // Copy with method for updates
  EarlyPaymentModel copyWith({
    String? paymentId,
    String? employeeId,
    String? employeeName,
    String? businessId,
    String? businessName,
    double? amount,
    String? reason,
    DateTime? dateRequested,
    DateTime? dateApproved,
    DateTime? datePaid,
    String? approvedBy,
    String? approvedByName,
    String? paidBy,
    String? paidByName,
    String? paymentMethod,
    String? status,
    bool? isDeductedFromSalary,
    String? deductedInPayrollId,
    DateTime? dateDeducted,
    String? notes,
    String? rejectionReason,
    double? amountDeductedFromSalary,
  }) {
    return EarlyPaymentModel(
      paymentId: paymentId ?? this.paymentId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      amount: amount ?? this.amount,
      reason: reason ?? this.reason,
      dateRequested: dateRequested ?? this.dateRequested,
      dateApproved: dateApproved ?? this.dateApproved,
      datePaid: datePaid ?? this.datePaid,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      paidBy: paidBy ?? this.paidBy,
      paidByName: paidByName ?? this.paidByName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      status: status ?? this.status,
      isDeductedFromSalary: isDeductedFromSalary ?? this.isDeductedFromSalary,
      deductedInPayrollId: deductedInPayrollId ?? this.deductedInPayrollId,
      dateDeducted: dateDeducted ?? this.dateDeducted,
      notes: notes ?? this.notes,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      amountDeductedFromSalary: amountDeductedFromSalary ?? this.amountDeductedFromSalary,
    );
  }

  static List<String> get paymentMethods => [
    'cash',
    'bank_transfer',
    'mobile_money',
    'check'
  ];

  static List<String> get paymentStatuses => [
    'requested',
    'approved',
    'paid',
    'rejected'
  ];

  static List<String> get commonReasons => [
    'Emergency medical expenses',
    'Family emergency',
    'School fees',
    'Transport money',
    'Personal emergency',
    'Other urgent need'
  ];
}
