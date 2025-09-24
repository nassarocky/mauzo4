import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/controllers/expence_controller.dart';
import 'package:mauzo/models/payment_record_model.dart';
import 'package:mauzo/models/pay_role_model.dart';
import 'package:mauzo/models/expences.dart';
import '../utils/constants.dart';

class PaymentController extends GetxController {
  final ProfileController _profileController = Get.find();

  final paymentRecords = <PaymentRecord>[].obs;
  final filteredPaymentRecords = <PaymentRecord>[].obs;
  final isLoading = false.obs;
  
  // Filter options
  final selectedBusinessFilter = ''.obs;
  final selectedStatusFilter = ''.obs;
  final searchQuery = ''.obs;

  StreamSubscription<QuerySnapshot>? _paymentSubscription;

  @override
  void onInit() {
    super.onInit();
    _initializePaymentStream();
  }

  @override
  void onClose() {
    _paymentSubscription?.cancel();
    super.onClose();
  }

  /// Initialize real-time stream for payment records
  void _initializePaymentStream() {
    try {
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      if (userBusinesses.isEmpty) return;

      _paymentSubscription = FirebaseFirestore.instance
          .collection('paymentRecords')
          .where('businessId', whereIn: userBusinesses)
          .snapshots()
          .listen((snapshot) {
    print('Payment stream received snapshot with ${snapshot.docs.length} documents.');
        paymentRecords.value = snapshot.docs
            .map((doc) => PaymentRecord.fromSnapshot(doc))
            .toList();
        
        // Sort by creation date (newest first) in memory since we can't use orderBy with whereIn
        paymentRecords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        _updateOverduePayments();
        _applyFilters();
      });
    } catch (e) {
      errorSnackbar('Error loading payment records: $e');
    }
  }

  /// Create payment record for a pay role
  Future<bool> createPaymentRecord({
    required PayRoleModel payRole,
    required DateTime payPeriodStart,
    required DateTime payPeriodEnd,
    required DateTime dueDate,
    double? hoursWorked,
    double? commissionEarned,
    double? bonusAmount,
    double? deductions,
    String? notes,
  }) async {
    try {
      isLoading.value = true;

      final currentUserId = _profileController.user['id'] ?? '';
      // Compute gross salary first (before deductions)
      double grossSalary = payRole.payRate;
      if (payRole.payType == PayType.commission && commissionEarned != null) {
        grossSalary += commissionEarned;
      }
      if (bonusAmount != null) {
        grossSalary += bonusAmount;
      }

      // Get breakdown using PayRoleController (with fallback)
      double advanceDeductions = 0.0;
      double lossDeductions = 0.0;
      double totalDeductions = 0.0;
      double netAmount = grossSalary;
      List<dynamic> undeductedAdvances = const [];
      List<dynamic> pendingLosses = const [];
      List<Map<String, dynamic>> appliedEarlyPaymentDetails = const [];
      List<Map<String, dynamic>> appliedLossDetails = const [];
      double carryoverDeductions = 0.0;
      try {
        final payRoleController = Get.find<PayRoleController>();
        final breakdown = payRoleController.getSalaryBreakdown(
          employeeId: payRole.employeeId,
          businessId: payRole.businessId,
          grossSalary: grossSalary,
        );
        advanceDeductions = (breakdown['advanceDeductions'] ?? 0.0) as double;
        lossDeductions = (breakdown['lossDeductions'] ?? 0.0) as double;
        totalDeductions = (breakdown['totalDeductions'] ?? 0.0) as double;
        netAmount = (breakdown['netSalary'] ?? grossSalary) as double;
        undeductedAdvances = (breakdown['undeductedAdvances'] as List?)?.cast<dynamic>() ?? [];
        pendingLosses = (breakdown['pendingLosses'] as List?)?.cast<dynamic>() ?? [];
        appliedEarlyPaymentDetails = (breakdown['appliedEarlyPayments'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        appliedLossDetails = (breakdown['appliedLosses'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        carryoverDeductions = (breakdown['carryoverDeductions'] ?? 0.0) as double;
      } catch (e) {
        print('[Payment] Breakdown fallback due to error: $e');
      }
      // IDs applied this period
      final deductedEarlyPaymentIds = appliedEarlyPaymentDetails.map<String>((e) => e['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
      final deductedLossIds = appliedLossDetails.map<String>((e) => e['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();

      // Construct breakdown note for clarity
      final bGross = grossSalary.toStringAsFixed(0);
      final bAdv = advanceDeductions.toStringAsFixed(0);
      final bLoss = lossDeductions.toStringAsFixed(0);
      final bNet = netAmount.toStringAsFixed(0);
      final breakdownNote = 'Gross: TZS $bGross - Early: TZS $bAdv - Loss: TZS $bLoss = Net: TZS $bNet';

      final paymentData = {
        'payRoleId': payRole.id,
        'employeeId': payRole.employeeId,
        'employeeName': payRole.employeeName,
        'businessId': payRole.businessId,
        'businessName': payRole.businessName,
        // Store NET amount to be paid
        'amount': netAmount,
        'currency': payRole.currency,
        'status': PaymentStatus.pending.toString().split('.').last,
        'payPeriodStart': Timestamp.fromDate(payPeriodStart),
        'payPeriodEnd': Timestamp.fromDate(payPeriodEnd),
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserId,
        'hoursWorked': hoursWorked,
        'commissionEarned': commissionEarned,
        'bonusAmount': bonusAmount,
        // Persist breakdown fields
        'deductions': (deductions ?? 0) + totalDeductions,
        'payType': payRole.payType.toString().split('.').last,
        'payPeriod': payRole.payPeriod.toString().split('.').last,
        'grossSalary': grossSalary,
        'advanceDeductions': advanceDeductions,
        'lossDeductions': lossDeductions,
        'deductedEarlyPaymentIds': deductedEarlyPaymentIds,
        'deductedLossIds': deductedLossIds,
        'appliedEarlyPaymentDetails': appliedEarlyPaymentDetails,
        'appliedLossDetails': appliedLossDetails,
        'carryoverDeductions': carryoverDeductions,
        'notes': (() {
          final n = (notes ?? '').trim();
          return n.isNotEmpty ? '$n | $breakdownNote' : breakdownNote;
        })(),
      };

      await FirebaseFirestore.instance
          .collection('paymentRecords')
          .add(paymentData);

      successSnackbar('Payment record created successfully');
      return true;
    } catch (e) {
      errorSnackbar('Failed to create payment record: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mark payment as paid with auto-generated transaction ID
  Future<bool> markPaymentAsPaidDirect(String paymentId) async {
    try {
      isLoading.value = true;

      final currentUserId = _profileController.user['id'] ?? '';
      if (currentUserId.isEmpty) {
        errorSnackbar('Could not identify current user. Please log in again.');
        return false;
      }

      // Get the payment record to check if it's commission-based
      final paymentSnap = await FirebaseFirestore.instance
          .collection('paymentRecords')
          .doc(paymentId)
          .get();
      
      if (!paymentSnap.exists) {
        errorSnackbar('Payment record not found');
        return false;
      }

      final paymentData = paymentSnap.data()!;
      final payType = paymentData['payType'] as String?;
      
      // Auto-generate transaction ID
      final transactionId = 'TXN${DateTime.now().millisecondsSinceEpoch}';
      
      final updateData = {
        'status': 'paid',
        'paymentMethod': 'cash', // Default to cash
        'referenceNumber': transactionId,
        'paidDate': FieldValue.serverTimestamp(),
        'paidBy': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // For commission payments, recalculate commission based on actual sales
      if (payType == 'commission') {
        print('[Commission] Recalculating commission for payment $paymentId before marking as paid');
        
        final payRoleId = paymentData['payRoleId'] as String?;
        final employeeId = paymentData['employeeId'] as String?;
        final businessId = paymentData['businessId'] as String?;
        final periodStart = (paymentData['payPeriodStart'] as Timestamp?)?.toDate();
        final periodEnd = (paymentData['payPeriodEnd'] as Timestamp?)?.toDate();
        
        if (payRoleId != null && employeeId != null && businessId != null && 
            periodStart != null && periodEnd != null) {
          
          // Get the pay role to get commission rate and base pay
          final payRoleSnap = await FirebaseFirestore.instance
              .collection('payRoles')
              .doc(payRoleId)
              .get();
          
          if (payRoleSnap.exists) {
            final payRoleData = payRoleSnap.data()!;
            final basePayRate = (payRoleData['payRate'] ?? 0).toDouble();
            final commissionRate = (payRoleData['commissionRate'] ?? 0).toDouble();
            
            // Calculate commission from actual sales in the period
            final salesSnap = await FirebaseFirestore.instance
                .collection('sales')
                .doc(businessId)
                .collection('userSales')
                .where('employeeId', isEqualTo: employeeId)
                .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
                .where('date', isLessThanOrEqualTo: Timestamp.fromDate(periodEnd))
                .get();

            double totalSales = 0.0;
            for (final d in salesSnap.docs) {
              final data = d.data();
              final price = (data['price'] ?? 0).toDouble();
              totalSales += price;
            }

            // Note: Fallback by employeeName removed to avoid Firestore composite index requirement
            if (salesSnap.docs.isEmpty) {
              print('[Commission Mark Paid] No sales found by employeeId. Ensure sales records have correct employeeId.');
            }

            final commission = totalSales * (commissionRate / 100.0);
            final newAmount = basePayRate + commission;
            
            print('[Commission] Recalculated: totalSales=$totalSales, commission=$commission, newAmount=$newAmount');
            
            // Update the payment amount and commission earned
            updateData['amount'] = newAmount;
            updateData['commissionEarned'] = commission;
            updateData['totalSalesInPeriod'] = totalSales;
          }
        }
      }
      
      await FirebaseFirestore.instance
          .collection('paymentRecords')
          .doc(paymentId)
          .update(updateData);

      // After marking as paid, mark applied early payments and losses with partial amounts,
      // create expense record and update pay role counters
      try {
        final paymentSnap = await FirebaseFirestore.instance
            .collection('paymentRecords')
            .doc(paymentId)
            .get();
        
        if (paymentSnap.exists) {
          final paymentData = paymentSnap.data()!;

          // Mark deductions as applied (partial-aware)
          final payRoleController = Get.find<PayRoleController>();
          final appliedEP = (paymentData['appliedEarlyPaymentDetails'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];
          final appliedLoss = (paymentData['appliedLossDetails'] as List?)
                  ?.map((e) => Map<String, dynamic>.from(e as Map))
                  .toList() ??
              [];

          if (appliedEP.isNotEmpty || appliedLoss.isNotEmpty) {
            for (final m in appliedEP) {
              final id = (m['id'] ?? '').toString();
              final amount = (m['amount'] ?? 0).toDouble();
              if (id.isEmpty || amount <= 0) continue;
              try { await payRoleController.updateEarlyPaymentDeductionPartial(id, amount, payrollId: paymentId); } catch (_) {}
            }
            for (final m in appliedLoss) {
              final id = (m['id'] ?? '').toString();
              final amount = (m['amount'] ?? 0).toDouble();
              if (id.isEmpty || amount <= 0) continue;
              try { await payRoleController.updateLossDeductionPartial(id, amount, payrollId: paymentId); } catch (_) {}
            }
          } else {
            // Fallback: mark fully deducted
            final earlyIds = (paymentData['deductedEarlyPaymentIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
            final lossIds = (paymentData['deductedLossIds'] as List?)?.map((e) => e.toString()).toList() ?? [];
            for (final id in earlyIds) {
              try { await payRoleController.updateEarlyPaymentDeduction(id, payrollId: paymentId); } catch (_) {}
            }
            for (final id in lossIds) {
              try { await payRoleController.updateLossStatus(id, 'deducted', payrollId: paymentId); } catch (_) {}
            }
          }
          
          // Create expense record for the payment (use paymentId as expenseId)
          await _createExpenseForPayment(paymentId, paymentData, updateData['amount'] ?? paymentData['amount']);
          
          // Update pay role counters
          final payRoleId = paymentData['payRoleId'] as String?;
          if (payRoleId != null && payRoleId.isNotEmpty) {
            await _updatePayRoleCountersOnPaid(payRoleId);
          }
        }
      } catch (e) {
        print('Error in post-payment processing: $e');
        // Do not block the main flow if these operations fail
      }

      successSnackbar('Payment marked as paid successfully');
      return true;
    } catch (e) {
      errorSnackbar('Failed to mark payment as paid: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Generate automatic payments for all active pay roles
  Future<bool> generateMonthlyPayments({
    required DateTime payPeriodStart,
    required DateTime payPeriodEnd,
    required DateTime dueDate,
  }) async {
    try {
      isLoading.value = true;

      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      if (userBusinesses.isEmpty) return false;

      // Get all active pay roles for owner's businesses
      final payRolesSnapshot = await FirebaseFirestore.instance
          .collection('payRoles')
          .where('businessId', whereIn: userBusinesses)
          .where('isActive', isEqualTo: true)
          .get();

      int createdCount = 0;
      
      for (var doc in payRolesSnapshot.docs) {
        final payRole = PayRoleModel.fromSnapshot(doc);
        
        // Check if payment already exists for this period
        final existingPayment = await _checkExistingPayment(
          payRole.id, 
          payPeriodStart, 
          payPeriodEnd
        );
        
        if (!existingPayment) {
          double? commissionEarned;
          if (payRole.payType == PayType.commission) {
            commissionEarned = await _computeCommissionForPeriod(
              payRole: payRole,
              periodStart: payPeriodStart,
              periodEnd: payPeriodEnd,
            );
          }

          await createPaymentRecord(
            payRole: payRole,
            payPeriodStart: payPeriodStart,
            payPeriodEnd: payPeriodEnd,
            dueDate: dueDate,
            commissionEarned: commissionEarned,
          );
          createdCount++;
        }
      }

      successSnackbar('Generated $createdCount payment records');
      return true;
    } catch (e) {
      errorSnackbar('Failed to generate payments: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Check if payment already exists for the period
  Future<bool> _checkExistingPayment(
    String payRoleId, 
    DateTime periodStart, 
    DateTime periodEnd
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('paymentRecords')
        .where('payRoleId', isEqualTo: payRoleId)
        .where('payPeriodStart', isEqualTo: Timestamp.fromDate(periodStart))
        .where('payPeriodEnd', isEqualTo: Timestamp.fromDate(periodEnd))
        .get();
    
    return snapshot.docs.isNotEmpty;
  }

  /// Compute commission for a commission-based pay role from sales in the period
  Future<double> _computeCommissionForPeriod({
    required PayRoleModel payRole,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    try {
      print('[Commission] Computing for ${payRole.employeeName} (${payRole.employeeId}) | business ${payRole.businessId}');
      print('[Commission] Period: ${periodStart.toIso8601String()} -> ${periodEnd.toIso8601String()} | rate: ${payRole.commissionRate ?? 0}%');
      // Commission is based on total sales price made by the employee within the period
      final salesSnap = await FirebaseFirestore.instance
          .collection('sales')
          .doc(payRole.businessId)
          .collection('userSales')
          .where('employeeId', isEqualTo: payRole.employeeId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(periodEnd))
          .get();

      double totalSales = 0.0;
      for (final d in salesSnap.docs) {
        final data = d.data();
        final dynamic rawPrice = data['price'] ?? 0;
        final double price = rawPrice is num ? rawPrice.toDouble() : 0.0;
        totalSales += price;
      }

      final rate = (payRole.commissionRate ?? 0) / 100.0;
      double commission = totalSales * rate;
      print('[Commission] Sales by employeeId -> count: ${salesSnap.docs.length}, totalSales: $totalSales, commission: $commission');

      // Note: Fallback by employeeName removed to avoid Firestore composite index requirement
      if (salesSnap.docs.isEmpty || totalSales == 0.0) {
        print('[Commission] No sales found by employeeId for ${payRole.employeeName}. Commission will be 0.');
        print('[Commission] Tip: Ensure sales records have correct employeeId field matching pay role.');
      }

      return commission;
    } catch (e) {
      // On any failure, do not block payment generation; return 0 commission
      print('[Commission][ERROR] $e');
      return 0.0;
    }
  }

  /// Calculate payment amount based on pay role and additional factors
  double _calculatePaymentAmount({
    required PayRoleModel payRole,
    double? hoursWorked,
    double? commissionEarned,
    double? bonusAmount,
  }) {
    double baseAmount = payRole.payRate;
    
    // For commission, add commission earned
    if (payRole.payType == PayType.commission && commissionEarned != null) {
      baseAmount += commissionEarned;
    }
    
    // Add bonus if provided
    if (bonusAmount != null) {
      baseAmount += bonusAmount;
    }
    
    // Apply early payment and loss deductions using PayRoleController
    try {
      final payRoleController = Get.find<PayRoleController>();
      final netAmount = payRoleController.calculateNetSalary(
        employeeId: payRole.employeeId,
        businessId: payRole.businessId,
        grossSalary: baseAmount,
      );
      
      print('[Payment Calculation] Employee: ${payRole.employeeName}');
      print('[Payment Calculation] Gross: $baseAmount, Net after deductions: $netAmount');
      
      return netAmount;
    } catch (e) {
      print('[Payment Calculation] Error applying deductions: $e');
      // Fallback to base amount if PayRoleController is not available
      return baseAmount;
    }
  }

  /// Update overdue payments
  void _updateOverduePayments() {
    final now = DateTime.now();
    for (var payment in paymentRecords) {
      if (payment.status == PaymentStatus.pending && 
          now.isAfter(payment.dueDate)) {
        _markAsOverdue(payment.id);
      }
    }
  }

  /// Mark payment as overdue
  Future<void> _markAsOverdue(String paymentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('paymentRecords')
          .doc(paymentId)
          .update({
        'status': PaymentStatus.overdue.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent fail for overdue updates
    }
  }

  /// Apply filters to payment records
  void _applyFilters() {
    List<PaymentRecord> filtered = List.from(paymentRecords);

    // Business filter
    if (selectedBusinessFilter.value.isNotEmpty) {
      filtered = filtered.where((payment) => 
          payment.businessId == selectedBusinessFilter.value).toList();
    }

    // Status filter
    if (selectedStatusFilter.value.isNotEmpty) {
      filtered = filtered.where((payment) => 
          payment.status.toString().split('.').last == selectedStatusFilter.value).toList();
    }

    // Search filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((payment) =>
          payment.employeeName.toLowerCase().contains(query) ||
          payment.businessName.toLowerCase().contains(query) ||
          payment.referenceNumber?.toLowerCase().contains(query) == true).toList();
    }

    filteredPaymentRecords.value = filtered;
  }

  /// Get payment statistics
  Map<String, dynamic> getPaymentStatistics() {
    final totalPayments = paymentRecords.length;
    final paidPayments = paymentRecords.where((p) => p.status == PaymentStatus.paid).length;
    final pendingPayments = paymentRecords.where((p) => p.status == PaymentStatus.pending).length;
    final overduePayments = paymentRecords.where((p) => p.isOverdue).length;
    
    final totalAmount = paymentRecords.fold<double>(0, (sum, payment) => sum + payment.amount);
    final paidAmount = paymentRecords
        .where((p) => p.status == PaymentStatus.paid)
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final pendingAmount = paymentRecords
        .where((p) => p.status == PaymentStatus.pending || p.isOverdue)
        .fold<double>(0, (sum, payment) => sum + payment.amount);
    final overdueAmount = paymentRecords
        .where((p) => p.isOverdue)
        .fold<double>(0, (sum, payment) => sum + payment.amount);

    return {
      'totalPayments': totalPayments,
      'paidPayments': paidPayments,
      'pendingPayments': pendingPayments,
      'overduePayments': overduePayments,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'overdueAmount': overdueAmount,
    };
  }

  /// Get total amount owed by employee
  double getTotalAmountOwedByEmployee(String employeeId) {
    return paymentRecords
        .where((p) => p.employeeId == employeeId && p.status != PaymentStatus.paid)
        .fold<double>(0, (sum, payment) => sum + payment.amount);
  }

  /// Get overdue payments for employee
  List<PaymentRecord> getOverduePaymentsForEmployee(String employeeId) {
    return paymentRecords
        .where((p) => p.employeeId == employeeId && p.isOverdue)
        .toList();
  }

  /// Get payments for specific employee
  List<PaymentRecord> getEmployeePayments(String employeeId) {
    return paymentRecords
        .where((payment) => payment.employeeId == employeeId)
        .toList();
  }

  /// Filter methods
  void setBusinessFilter(String businessId) {
    selectedBusinessFilter.value = businessId;
    _applyFilters();
  }

  void setStatusFilter(String status) {
    selectedStatusFilter.value = status;
    _applyFilters();
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  void clearFilters() {
    selectedBusinessFilter.value = '';
    selectedStatusFilter.value = '';
    searchQuery.value = '';
    _applyFilters();
  }

  /// Refresh payment records
  Future<void> refreshPayments() async {
    _paymentSubscription?.cancel();
    _initializePaymentStream();
  }

  // Generate automatic payments for all active pay roles
  Future<void> generateAutomaticPayments() async {
    print('Starting automatic payment generation...');
    try {
      isLoading.value = true;
      
      final payRoleController = Get.find<PayRoleController>();
      final activePayRoles = payRoleController.payRoles.where((pr) => pr.isActive).toList();
      
      int generatedCount = 0;
      
      for (final payRole in activePayRoles) {
        final shouldGenerate = await _shouldGeneratePaymentForPayRole(payRole);
        if (shouldGenerate) {
          await _generatePaymentForPayRole(payRole);
          generatedCount++;
        }
      }
      
      if (generatedCount > 0) {
        successSnackbar('Generated $generatedCount automatic payments');
        print('Generated $generatedCount automatic payments');
      } else {
        print('No new payments needed to be generated');
      }
      
    } catch (e) {
      print('Error generating automatic payments: $e');
      errorSnackbar('Failed to generate automatic payments: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Check if payment should be generated for a pay role
  Future<bool> _shouldGeneratePaymentForPayRole(PayRoleModel payRole) async {
    try {
      final currentPeriod = payRole.getCurrentPayPeriod();
      final periodStart = currentPeriod['start']!;
      final periodEnd = currentPeriod['end']!;
      
      // Check if payment already exists for this period
      final existingPayments = await FirebaseFirestore.instance
          .collection('paymentRecords')
          .where('employeeId', isEqualTo: payRole.employeeId)
          .where('payRoleId', isEqualTo: payRole.id)
          .where('payPeriodStart', isEqualTo: Timestamp.fromDate(periodStart))
          .where('payPeriodEnd', isEqualTo: Timestamp.fromDate(periodEnd))
          .get();
      
      return existingPayments.docs.isEmpty;
    } catch (e) {
      print('Error checking if payment should be generated for ${payRole.employeeName}: $e');
      return false;
    }
  }

  // Generate payment record for a pay role
  Future<void> _generatePaymentForPayRole(PayRoleModel payRole) async {
    try {
      final currentUserId = _profileController.user['id'] ?? '';
      if (currentUserId.isEmpty) return;
      
      final currentPeriod = payRole.getCurrentPayPeriod();
      final periodStart = currentPeriod['start']!;
      final periodEnd = currentPeriod['end']!;
      final dueDate = payRole.getNextPaymentDate();
      
      // Calculate gross and breakdown (includes deductions)
      double? commissionEarned;
      if (payRole.payType == PayType.commission) {
        print('[Commission] Generating commission payment for ${payRole.employeeName}');
        commissionEarned = await _computeCommissionForPeriod(
          payRole: payRole,
          periodStart: periodStart,
          periodEnd: periodEnd,
        );
        print('[Commission] Computed commission: $commissionEarned, base: ${payRole.payRate}');
      }

      // Gross salary first
      double grossSalary = payRole.payRate + (commissionEarned ?? 0);
      final payRoleController = Get.find<PayRoleController>();
      final breakdown = payRoleController.getSalaryBreakdown(
        employeeId: payRole.employeeId,
        businessId: payRole.businessId,
        grossSalary: grossSalary,
      );
      final advanceDeductions = (breakdown['advanceDeductions'] ?? 0.0) as double;
      final lossDeductions = (breakdown['lossDeductions'] ?? 0.0) as double;
      final netAmount = (breakdown['netSalary'] ?? grossSalary) as double;
      final undeductedAdvances = (breakdown['undeductedAdvances'] as List?)?.cast<dynamic>() ?? [];
      final pendingLosses = (breakdown['pendingLosses'] as List?)?.cast<dynamic>() ?? [];
      final deductedEarlyPaymentIds = undeductedAdvances.map<String>((e) => e.paymentId as String).toList();
      final deductedLossIds = pendingLosses.map<String>((e) => e.lossId as String).toList();
      print('[Auto Payment] Final amount for ${payRole.employeeName}: $netAmount');

      final paymentData = {
        'payRoleId': payRole.id,
        'employeeId': payRole.employeeId,
        'employeeName': payRole.employeeName,
        'businessId': payRole.businessId,
        'businessName': payRole.businessName,
        'amount': netAmount,
        'currency': payRole.currency,
        'status': 'pending',
        'payPeriodStart': Timestamp.fromDate(periodStart),
        'payPeriodEnd': Timestamp.fromDate(periodEnd),
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUserId,
        'payType': payRole.payType.toString().split('.').last,
        'payPeriod': payRole.payPeriod.toString().split('.').last,
        'hoursWorked': payRole.hoursPerWeek,
        'notes': 'Auto-generated payment for ${payRole.getPayPeriodDescription()} | payDay:${payRole.payDay}',
        'commissionEarned': commissionEarned,
        // Breakdown
        'grossSalary': grossSalary,
        'advanceDeductions': advanceDeductions,
        'lossDeductions': lossDeductions,
        'deductedEarlyPaymentIds': deductedEarlyPaymentIds,
        'deductedLossIds': deductedLossIds,
      };
      
      await FirebaseFirestore.instance
          .collection('paymentRecords')
          .add(paymentData);
      
      print('Generated payment for ${payRole.employeeName} - ${payRole.getPayPeriodDescription()}');
      
    } catch (e) {
      print('Error generating payment for ${payRole.employeeName}: $e');
      throw e;
    }
  }

  // Initialize automatic payment generation (call this on app start)
  Future<void> initializeAutomaticPayments() async {
    // Generate payments for current period if needed
    await generateAutomaticPayments();
    
    // Set up periodic check (could be enhanced with background service)
    Timer.periodic(const Duration(hours: 1), (timer) {
      generateAutomaticPayments();
    });
  }

  // Update pay role counters when a payment is marked as paid
  Future<void> _updatePayRoleCountersOnPaid(String payRoleId) async {
    try {
      final payRoleRef = FirebaseFirestore.instance.collection('payRoles').doc(payRoleId);
      final snap = await payRoleRef.get();
      if (!snap.exists) return;

      // Safely parse to model (optional) to compute nextPayDate
      PayRoleModel? model;
      try {
        model = PayRoleModel.fromSnapshot(snap);
      } catch (_) {}

      final now = DateTime.now();
      final updates = <String, dynamic>{
        'lastPayDate': Timestamp.fromDate(now),
        'totalPaymentsMade': FieldValue.increment(1),
      };

      // Set paymentCountStartDate only once
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null || data['paymentCountStartDate'] == null) {
        updates['paymentCountStartDate'] = Timestamp.fromDate(now);
      }

      // Compute and set nextPayDate if we can
      if (model != null) {
        final next = model.getNextPaymentDate();
        updates['nextPayDate'] = Timestamp.fromDate(next);
      }

      await payRoleRef.update(updates);
    } catch (e) {
      // Silent fail; counters are non-critical
    }
  }

  /// Create expense record when payment is marked as paid
  /// Uses the same document ID as the paymentId so we can easily delete both together later
  Future<void> _createExpenseForPayment(String paymentId, Map<String, dynamic> paymentData, double finalAmount) async {
    try {
      final currentUserId = _profileController.user['id'] ?? '';
      final currentUserName = _profileController.user['name'] ?? 'System';
      
      final employeeName = paymentData['employeeName'] ?? 'Unknown Employee';
      final businessId = paymentData['businessId'] as String?;
      final businessName = paymentData['businessName'] ?? 'Unknown Business';
      final payType = paymentData['payType'] ?? 'salary';
      final payPeriodStart = (paymentData['payPeriodStart'] as Timestamp?)?.toDate();
      final payPeriodEnd = (paymentData['payPeriodEnd'] as Timestamp?)?.toDate();
      final grossSalary = (paymentData['grossSalary'] is num) ? (paymentData['grossSalary'] as num).toDouble() : null;
      final advanceDeductions = (paymentData['advanceDeductions'] is num) ? (paymentData['advanceDeductions'] as num).toDouble() : 0.0;
      final lossDeductions = (paymentData['lossDeductions'] is num) ? (paymentData['lossDeductions'] as num).toDouble() : 0.0;
      
      if (businessId == null || businessId.isEmpty) {
        print('[Payment-Expense] Error: No business ID found in payment data');
        return;
      }
      
      // Create detailed expense title with key information
      String expenseTitle = 'Salary: $employeeName';
      
      // Add period info to title if available
      if (payPeriodStart != null && payPeriodEnd != null) {
        final startStr = '${payPeriodStart.day}/${payPeriodStart.month}';
        final endStr = '${payPeriodEnd.day}/${payPeriodEnd.month}';
        expenseTitle += ' ($startStr-$endStr)';
      }
      
      // Add pay type info for commission
      if (payType == 'commission') {
        expenseTitle += ' [Commission]';
      }
      
      // Append breakdown if available
      if (grossSalary != null) {
        expenseTitle += ' | Gross: ${grossSalary.toStringAsFixed(0)}';
        if (advanceDeductions > 0) expenseTitle += ' - Early: ${advanceDeductions.toStringAsFixed(0)}';
        if (lossDeductions > 0) expenseTitle += ' - Loss: ${lossDeductions.toStringAsFixed(0)}';
        expenseTitle += ' = Net: ${finalAmount.toStringAsFixed(0)}';
      }
      
      // Create expense record
      final expense = Expense(
        id: paymentId, // Use paymentId as expenseId
        title: expenseTitle,
        amount: finalAmount,
        date: Timestamp.now(),
        category: 'Employee Payments',
        addedBy: currentUserId,
        addedByName: currentUserName,
      );
      
      // Create or update expense directly in the employee's business with fixed ID = paymentId
      final expenseRef = FirebaseFirestore.instance
          .collection('expenses')
          .doc(businessId)
          .collection('userExpenses')
          .doc(paymentId);

      final existing = await expenseRef.get();
      if (existing.exists) {
        await expenseRef.update(expense.toMap());
      } else {
        await expenseRef.set(expense.toMap());
      }
      
      print('[Payment-Expense] Created expense record in business $businessName ($businessId) for payment to $employeeName: ${finalAmount.toStringAsFixed(2)}');
      
    } catch (e) {
      print('[Payment-Expense] Error creating expense record: $e');
      // Don't throw - this shouldn't block the payment process
    }
  }

  /// Delete a payment record and its corresponding expense (if exists)
  /// Only owners can access PaymentManagementScreen, but rules also enforce permissions
  Future<bool> deletePayment(String paymentId) async {
    try {
      isLoading.value = true;

      final paymentRef = FirebaseFirestore.instance.collection('paymentRecords').doc(paymentId);
      final paymentSnap = await paymentRef.get();
      if (!paymentSnap.exists) {
        errorSnackbar('Payment not found');
        return false;
      }

      final data = paymentSnap.data() as Map<String, dynamic>;
      final String? businessId = data['businessId'] as String?;

      final batch = FirebaseFirestore.instance.batch();
      // Delete the payment record
      batch.delete(paymentRef);

      // Also delete the linked expense which uses the same document ID as the payment
      if (businessId != null && businessId.isNotEmpty) {
        final expenseRef = FirebaseFirestore.instance
            .collection('expenses')
            .doc(businessId)
            .collection('userExpenses')
            .doc(paymentId);
        batch.delete(expenseRef);
      }

      await batch.commit();
      successSnackbar('Payment deleted successfully');
      return true;
    } catch (e) {
      errorSnackbar('Failed to delete payment: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Calculate commission details for a payment without marking it as paid
  Future<Map<String, dynamic>?> calculateCommissionPreview(String paymentId) async {
    try {
      final paymentSnap = await FirebaseFirestore.instance
          .collection('paymentRecords')
          .doc(paymentId)
          .get();
      
      if (!paymentSnap.exists) return null;

      final paymentData = paymentSnap.data()!;
      final payType = paymentData['payType'] as String?;
      
      if (payType != 'commission') {
        return {
          'isCommission': false,
          'message': 'This is not a commission-based payment'
        };
      }

      final payRoleId = paymentData['payRoleId'] as String?;
      final employeeId = paymentData['employeeId'] as String?;
      final businessId = paymentData['businessId'] as String?;
      final periodStart = (paymentData['payPeriodStart'] as Timestamp?)?.toDate();
      final periodEnd = (paymentData['payPeriodEnd'] as Timestamp?)?.toDate();
      
      if (payRoleId == null || employeeId == null || businessId == null || 
          periodStart == null || periodEnd == null) {
        return {
          'isCommission': true,
          'error': 'Missing payment data for commission calculation'
        };
      }
      
      // Get the pay role to get commission rate and base pay
      final payRoleSnap = await FirebaseFirestore.instance
          .collection('payRoles')
          .doc(payRoleId)
          .get();
      
      if (!payRoleSnap.exists) {
        return {
          'isCommission': true,
          'error': 'Pay role not found'
        };
      }

      final payRoleData = payRoleSnap.data()!;
      final basePayRate = (payRoleData['payRate'] ?? 0).toDouble();
      final commissionRate = (payRoleData['commissionRate'] ?? 0).toDouble();
      
      // Calculate commission from actual sales in the period
      final salesSnap = await FirebaseFirestore.instance
          .collection('sales')
          .doc(businessId)
          .collection('userSales')
          .where('employeeId', isEqualTo: employeeId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(periodStart))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(periodEnd))
          .get();

      double totalSales = 0.0;
      int salesCount = salesSnap.docs.length;
      
      for (final d in salesSnap.docs) {
        final data = d.data();
        final price = (data['price'] ?? 0).toDouble();
        totalSales += price;
      }

      // Note: Fallback by employeeName removed to avoid Firestore composite index requirement
      if (salesSnap.docs.isEmpty) {
        print('[Commission Preview] No sales found by employeeId. Ensure sales records have correct employeeId.');
      }

      final commission = totalSales * (commissionRate / 100.0);
      final newAmount = basePayRate + commission;
      final currentAmount = (paymentData['amount'] ?? 0).toDouble();
      
      return {
        'isCommission': true,
        'basePayRate': basePayRate,
        'commissionRate': commissionRate,
        'totalSales': totalSales,
        'salesCount': salesCount,
        'commission': commission,
        'newAmount': newAmount,
        'currentAmount': currentAmount,
        'periodStart': periodStart,
        'periodEnd': periodEnd,
        'employeeName': paymentData['employeeName'],
        'businessName': paymentData['businessName'],
        'currency': paymentData['currency'] ?? 'USD',
      };
    } catch (e) {
      return {
        'isCommission': true,
        'error': 'Error calculating commission: $e'
      };
    }
  }

  // Backfill counters for all pay roles in user's businesses
  Future<void> backfillPayRoleCounters() async {
    try {
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      if (userBusinesses.isEmpty) return;

      final payRolesSnapshot = await FirebaseFirestore.instance
          .collection('payRoles')
          .where('businessId', whereIn: userBusinesses)
          .get();

      for (final prDoc in payRolesSnapshot.docs) {
        final prId = prDoc.id;

        final paidPaymentsSnap = await FirebaseFirestore.instance
            .collection('paymentRecords')
            .where('payRoleId', isEqualTo: prId)
            .where('status', isEqualTo: 'paid')
            .get();

        if (paidPaymentsSnap.docs.isEmpty) continue;

        // Compute earliest paidDate and total count
        DateTime? earliest;
        for (final d in paidPaymentsSnap.docs) {
          final ts = d.data()['paidDate'];
          final dt = (ts is Timestamp) ? ts.toDate() : null;
          if (dt != null) {
            if (earliest == null || dt.isBefore(earliest)) earliest = dt;
          }
        }

        final updates = <String, dynamic>{
          'totalPaymentsMade': paidPaymentsSnap.docs.length,
        };
        if (earliest != null) {
          updates['paymentCountStartDate'] = Timestamp.fromDate(earliest);
        }

        await FirebaseFirestore.instance.collection('payRoles').doc(prId).update(updates);
      }
    } catch (e) {
      // Do not surface errors to user; this is a maintenance helper
    }
  }
}
