import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeLossModel {
  final String lossId;
  final String employeeId;
  final String employeeName;
  final String businessId;
  final String businessName;
  final double amount;
  final String description;
  final String category; // 'damage', 'theft', 'shortage', 'mistake', 'other'
  final DateTime dateOccurred;
  final DateTime dateRecorded;
  final String recordedBy; // Owner/Manager who recorded the loss
  final String recordedByName;
  final bool isDeducted; // Whether this loss has been deducted from salary
  final String? deductedInPayrollId; // Reference to payroll where it was deducted
  final DateTime? dateDeducted;
  final String status; // 'pending', 'deducted', 'forgiven'
  final String? notes;
  final double amountDeductedFromSalary;

  EmployeeLossModel({
    required this.lossId,
    required this.employeeId,
    required this.employeeName,
    required this.businessId,
    required this.businessName,
    required this.amount,
    required this.description,
    required this.category,
    required this.dateOccurred,
    required this.dateRecorded,
    required this.recordedBy,
    required this.recordedByName,
    this.isDeducted = false,
    this.deductedInPayrollId,
    this.dateDeducted,
    this.status = 'pending',
    this.notes,
    this.amountDeductedFromSalary = 0.0,
  });

  // Convert from Firestore document
  factory EmployeeLossModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return EmployeeLossModel(
      lossId: snapshot.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
      amount: (data['amount'] ?? 0.0).toDouble(),
      description: data['description'] ?? '',
      category: data['category'] ?? 'other',
      dateOccurred: (data['dateOccurred'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dateRecorded: (data['dateRecorded'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recordedBy: data['recordedBy'] ?? '',
      recordedByName: data['recordedByName'] ?? '',
      isDeducted: data['isDeducted'] ?? false,
      deductedInPayrollId: data['deductedInPayrollId'],
      dateDeducted: (data['dateDeducted'] as Timestamp?)?.toDate(),
      status: data['status'] ?? 'pending',
      notes: data['notes'],
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
      'description': description,
      'category': category,
      'dateOccurred': Timestamp.fromDate(dateOccurred),
      'dateRecorded': Timestamp.fromDate(dateRecorded),
      'recordedBy': recordedBy,
      'recordedByName': recordedByName,
      'isDeducted': isDeducted,
      'deductedInPayrollId': deductedInPayrollId,
      'dateDeducted': dateDeducted != null ? Timestamp.fromDate(dateDeducted!) : null,
      'status': status,
      'notes': notes,
      'amountDeductedFromSalary': amountDeductedFromSalary,
    };
  }

  // Helper methods
  String get formattedAmount => amount.toStringAsFixed(2);
  
  String get categoryDisplayName {
    switch (category) {
      case 'damage':
        return 'Property Damage';
      case 'theft':
        return 'Theft/Loss';
      case 'shortage':
        return 'Cash Shortage';
      case 'mistake':
        return 'Costly Mistake';
      case 'other':
        return 'Other Loss';
      default:
        return category;
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'pending':
        return 'Pending Deduction';
      case 'deducted':
        return 'Deducted';
      case 'forgiven':
        return 'Forgiven';
      default:
        return status;
    }
  }

  // Remaining amount to deduct from salary
  double get outstandingAmount {
    final out = amount - amountDeductedFromSalary;
    return out > 0 ? out : 0.0;
  }

  // Copy with method for updates
  EmployeeLossModel copyWith({
    String? lossId,
    String? employeeId,
    String? employeeName,
    String? businessId,
    String? businessName,
    double? amount,
    String? description,
    String? category,
    DateTime? dateOccurred,
    DateTime? dateRecorded,
    String? recordedBy,
    String? recordedByName,
    bool? isDeducted,
    String? deductedInPayrollId,
    DateTime? dateDeducted,
    String? status,
    String? notes,
    double? amountDeductedFromSalary,
  }) {
    return EmployeeLossModel(
      lossId: lossId ?? this.lossId,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      dateOccurred: dateOccurred ?? this.dateOccurred,
      dateRecorded: dateRecorded ?? this.dateRecorded,
      recordedBy: recordedBy ?? this.recordedBy,
      recordedByName: recordedByName ?? this.recordedByName,
      isDeducted: isDeducted ?? this.isDeducted,
      deductedInPayrollId: deductedInPayrollId ?? this.deductedInPayrollId,
      dateDeducted: dateDeducted ?? this.dateDeducted,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      amountDeductedFromSalary: amountDeductedFromSalary ?? this.amountDeductedFromSalary,
    );
  }

  static List<String> get lossCategories => [
    'damage',
    'theft', 
    'shortage',
    'mistake',
    'other'
  ];

  static List<String> get lossStatuses => [
    'pending',
    'deducted',
    'forgiven'
  ];
}
