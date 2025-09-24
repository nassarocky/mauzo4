import 'package:cloud_firestore/cloud_firestore.dart';

enum PayType {
  salary,
  commission,
}

enum PayPeriod {
  weekly,
  monthly,
}

class PayRoleModel {
  final String id;
  final String employeeId;
  final String employeeName;
  final String businessId;
  final String businessName;
  final PayType payType;
  final double payRate; 
  final double? commissionRate; 
  final String currency; 
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy; 
  
  // Additional pay details
  final int? hoursPerWeek; 
  final String? notes; 
  
  // Pay schedule
  final PayPeriod payPeriod; // weekly or monthly
  final int payDay; // Day of week (1-7) for weekly, day of month (1-31) for monthly
  final DateTime? lastPayDate;
  final DateTime? nextPayDate;
  
  // Payment tracking
  final DateTime? paymentCountStartDate; // When payment counting began
  final int totalPaymentsMade; // Total payments made since start

  PayRoleModel({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.businessId,
    required this.businessName,
    required this.payType,
    required this.payRate,
    this.commissionRate,
    required this.currency,
    required this.isActive,
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.hoursPerWeek,
    this.notes,
    required this.payPeriod,
    required this.payDay,
    this.lastPayDate,
    this.nextPayDate,
    this.paymentCountStartDate,
    this.totalPaymentsMade = 0,
  });

  // Factory method to create PayRoleModel from Firestore snapshot
  static PayRoleModel fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) throw Exception("Pay role document data is null");

    return PayRoleModel(
      id: snapshot.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      businessId: data['businessId'] ?? '',
      businessName: data['businessName'] ?? '',
      payType: getPayType(data['payType']),
      payRate: data['payRate']?.toDouble() ?? 0.0,
      commissionRate: data['commissionRate']?.toDouble(),
      currency: data['currency'] ?? 'TZS',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      createdBy: data['createdBy'] ?? '',
      hoursPerWeek: data['hoursPerWeek']?.toInt(),
      notes: data['notes'],
      payPeriod: getPayPeriod(data['payPeriod'] ?? data['paySchedule']),
      payDay: data['payDay']?.toInt() ?? 1,
      lastPayDate: (data['lastPayDate'] as Timestamp?)?.toDate(),
      nextPayDate: (data['nextPayDate'] as Timestamp?)?.toDate(),
      paymentCountStartDate: (data['paymentCountStartDate'] as Timestamp?)?.toDate(),
      totalPaymentsMade: data['totalPaymentsMade']?.toInt() ?? 0,
    );
  }

  static PayType getPayType(String? payType) {
    switch (payType) {
      case 'salary':
        return PayType.salary;
      case 'commission':
        return PayType.commission;
      case 'hourly':
      case 'fixed':
        // Convert legacy 'hourly' and 'fixed' pay types to 'salary' for backward compatibility
        return PayType.salary;
      default:
        // Default to salary for any unknown pay types
        return PayType.salary;
    }
  }

  static PayPeriod getPayPeriod(String? payPeriod) {
    switch (payPeriod) {
      case 'weekly':
        return PayPeriod.weekly;
      case 'monthly':
      default:
        return PayPeriod.monthly;
    }
  }

  // Method to convert PayRoleModel to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'businessId': businessId,
      'businessName': businessName,
      'payType': payType.toString().split('.').last,
      'payRate': payRate,
      'commissionRate': commissionRate,
      'currency': currency,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'hoursPerWeek': hoursPerWeek,
      'notes': notes,
      'payPeriod': payPeriod.toString().split('.').last,
      'payDay': payDay,
      'lastPayDate': lastPayDate,
      'nextPayDate': nextPayDate,
      'paymentCountStartDate': paymentCountStartDate,
      'totalPaymentsMade': totalPaymentsMade,
    };
  }

  // Helper method to get formatted pay rate display
  String getFormattedPayRate() {
    switch (payType) {
      case PayType.salary:
        final periodText = payPeriod == PayPeriod.weekly ? 'week' : 'month';
        return '$currency ${payRate.toStringAsFixed(0)}/$periodText';
      case PayType.commission:
        return '${commissionRate?.toStringAsFixed(1) ?? 0}% commission';
    }
  }

  // Get next payment due date based on pay period and pay day
  DateTime getNextPaymentDate() {
    final now = DateTime.now();
    
    if (payPeriod == PayPeriod.weekly) {
      // Find next occurrence of payDay (1=Monday, 7=Sunday)
      int daysUntilPayDay = payDay - now.weekday;
      if (daysUntilPayDay <= 0) daysUntilPayDay += 7;
      return now.add(Duration(days: daysUntilPayDay));
    } else {
      // Monthly payment
      DateTime nextPayDate = DateTime(now.year, now.month, payDay);
      if (nextPayDate.isBefore(now) || nextPayDate.isAtSameMomentAs(now)) {
        // Move to next month
        nextPayDate = DateTime(now.year, now.month + 1, payDay);
      }
      return nextPayDate;
    }
  }

  // Get current pay period start and end dates
  Map<String, DateTime> getCurrentPayPeriod() {
    final now = DateTime.now();
    
    if (payPeriod == PayPeriod.weekly) {
      // Find start of current week (Monday)
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return {
        'start': DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        'end': DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59),
      };
    } else {
      // Monthly period
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      return {
        'start': startOfMonth,
        'end': endOfMonth,
      };
    }
  }

  // Get pay period description
  String getPayPeriodDescription() {
    if (payPeriod == PayPeriod.weekly) {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return 'Weekly (${weekdays[payDay - 1]})';
    } else {
      return 'Monthly (${payDay}${_getOrdinalSuffix(payDay)})';
    }
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  // Helper method to calculate monthly equivalent
  double getMonthlyEquivalent() {
    switch (payType) {
      case PayType.salary:
        return payRate;
      case PayType.commission:
        return 0.0; // Commission varies based on sales
    }
  }

  // Copy with method for updates
  PayRoleModel copyWith({
    String? employeeName,
    String? businessName,
    PayType? payType,
    double? payRate,
    double? commissionRate,
    String? currency,
    bool? isActive,
    DateTime? updatedAt,
    int? hoursPerWeek,
    String? notes,
    PayPeriod? payPeriod,
    int? payDay,
    DateTime? lastPayDate,
    DateTime? nextPayDate,
    DateTime? paymentCountStartDate,
    int? totalPaymentsMade,
  }) {
    return PayRoleModel(
      id: id,
      employeeId: employeeId,
      employeeName: employeeName ?? this.employeeName,
      businessId: businessId,
      businessName: businessName ?? this.businessName,
      payType: payType ?? this.payType,
      payRate: payRate ?? this.payRate,
      commissionRate: commissionRate ?? this.commissionRate,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      hoursPerWeek: hoursPerWeek ?? this.hoursPerWeek,
      notes: notes ?? this.notes,
      payPeriod: payPeriod ?? this.payPeriod,
      payDay: payDay ?? this.payDay,
      lastPayDate: lastPayDate ?? this.lastPayDate,
      nextPayDate: nextPayDate ?? this.nextPayDate,
      paymentCountStartDate: paymentCountStartDate ?? this.paymentCountStartDate,
      totalPaymentsMade: totalPaymentsMade ?? this.totalPaymentsMade,
    );
  }

  // Helper method to get payment count duration
  String getPaymentCountDuration() {
    if (paymentCountStartDate == null) return 'Not started';
    
    final now = DateTime.now();
    final duration = now.difference(paymentCountStartDate!);
    
    if (duration.inDays < 30) {
      return '${duration.inDays} days';
    } else if (duration.inDays < 365) {
      final months = (duration.inDays / 30).floor();
      return '$months month${months > 1 ? 's' : ''}';
    } else {
      final years = (duration.inDays / 365).floor();
      final remainingMonths = ((duration.inDays % 365) / 30).floor();
      return '$years year${years > 1 ? 's' : ''} ${remainingMonths > 0 ? '$remainingMonths month${remainingMonths > 1 ? 's' : ''}' : ''}';
    }
  }

  // Helper method to get payment frequency info
  String getPaymentFrequencyInfo() {
    if (paymentCountStartDate == null || totalPaymentsMade == 0) {
      return 'No payments made yet';
    }
    
    final duration = DateTime.now().difference(paymentCountStartDate!);
    final months = duration.inDays / 30;
    
    if (months < 1) {
      return '$totalPaymentsMade payment${totalPaymentsMade > 1 ? 's' : ''} this month';
    }
    
    final avgPerMonth = (totalPaymentsMade / months).toStringAsFixed(1);
    return '$totalPaymentsMade total payments (avg $avgPerMonth/month)';
  }
}
