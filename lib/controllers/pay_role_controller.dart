import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/pay_role_model.dart';
import 'package:mauzo/models/profile_model.dart';
import 'package:mauzo/models/employee_loss_model.dart';
import 'package:mauzo/models/early_payment_model.dart';
import 'package:mauzo/models/expences.dart';
import '../utils/constants.dart';

class PayRoleController extends GetxController {
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  final payRoles = <PayRoleModel>[].obs;
  final filteredPayRoles = <PayRoleModel>[].obs;
  final employeeLosses = <EmployeeLossModel>[].obs;
  final earlyPayments = <EarlyPaymentModel>[].obs;
  final isLoading = false.obs;
  
  // Filter options
  final selectedBusinessFilter = ''.obs;
  final selectedPayTypeFilter = ''.obs;
  final searchQuery = ''.obs;

  StreamSubscription<QuerySnapshot>? _payRoleSubscription;
  StreamSubscription<QuerySnapshot>? _employeeLossesSubscription;
  StreamSubscription<QuerySnapshot>? _earlyPaymentsSubscription;

  @override
  void onInit() {
    super.onInit();
    _initializePayRoleStream();
    _initializeLossesStream();
    _initializeEarlyPaymentsStream();
  }

  @override
  void onClose() {
    _payRoleSubscription?.cancel();
    _employeeLossesSubscription?.cancel();
    _earlyPaymentsSubscription?.cancel();
    super.onClose();
  }

  /// Initialize real-time stream for pay roles (owner sees all their businesses)
  void _initializePayRoleStream() {
    try {
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      if (userBusinesses.isEmpty) {
        payRoles.value = [];
        _applyFilters();
        return;
      }

      // Stream pay roles for all businesses owned by current user
      // Remove orderBy to avoid composite index requirement
      _payRoleSubscription = FirebaseFirestore.instance
          .collection('payRoles')
          .where('businessId', whereIn: userBusinesses)
          .snapshots()
          .listen(
            (snapshot) {
              final payRolesList = snapshot.docs
                  .map((doc) => PayRoleModel.fromSnapshot(doc))
                  .toList();
              
              // Sort in memory instead of using Firestore orderBy
              payRolesList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
              
              payRoles.value = payRolesList;
              _applyFilters();
            },
            onError: (error) {
              print('PayRole stream error: $error');
              errorSnackbar('Error loading pay roles: $error');
              // Set empty list on error to prevent infinite loading
              payRoles.value = [];
              _applyFilters();
            },
          );
    } catch (e) {
      print('PayRole initialization error: $e');
      errorSnackbar('Error initializing pay roles: $e');
      payRoles.value = [];
      _applyFilters();
    }
  }

  /// Create or update pay role for an employee
  Future<bool> createOrUpdatePayRole({
    required String employeeId,
    required String employeeName,
    required String businessId,
    required String businessName,
    required PayType payType,
    required double payRate,
    double? commissionRate,
    required String currency,
    int? hoursPerWeek,
    String? notes,
    required PayPeriod payPeriod,
    required int payDay,
    String? existingPayRoleId,
  }) async {
    try {
      isLoading.value = true;

      final currentUserId = _profileController.user['id'] ?? '';
      final now = DateTime.now();

      final payRoleData = {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'businessId': businessId,
        'businessName': businessName,
        'payType': payType.toString().split('.').last,
        'payRate': payRate,
        'commissionRate': commissionRate,
        'currency': currency,
        'isActive': true,
        'createdBy': currentUserId,
        'hoursPerWeek': hoursPerWeek,
        'notes': notes,
        'payPeriod': payPeriod.toString().split('.').last,
        'payDay': payDay,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingPayRoleId != null) {
        // Update existing pay role
        await FirebaseFirestore.instance
            .collection('payRoles')
            .doc(existingPayRoleId)
            .update(payRoleData);
        
        successSnackbar('Pay role updated successfully');
      } else {
        // Create new pay role
        payRoleData['createdAt'] = FieldValue.serverTimestamp();
        
        await FirebaseFirestore.instance
            .collection('payRoles')
            .add(payRoleData);
        
        successSnackbar('Pay role created successfully');
      }

      return true;
    } catch (e) {
      errorSnackbar('Failed to save pay role: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get pay roles for a specific employee across all businesses
  List<PayRoleModel> getEmployeePayRoles(String employeeId) {
    return payRoles.where((payRole) => payRole.employeeId == employeeId).toList();
  }

  /// Get pay role for specific employee in specific business
  PayRoleModel? getEmployeePayRoleInBusiness(String employeeId, String businessId) {
    try {
      return payRoles.firstWhere(
        (payRole) => payRole.employeeId == employeeId && payRole.businessId == businessId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Delete pay role
  Future<bool> deletePayRole(String payRoleId) async {
    try {
      isLoading.value = true;

      await FirebaseFirestore.instance
          .collection('payRoles')
          .doc(payRoleId)
          .delete();

      successSnackbar('Pay role deleted successfully');
      return true;
    } catch (e) {
      errorSnackbar('Failed to delete pay role: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Deactivate pay role (soft delete)
  Future<bool> deactivatePayRole(String payRoleId) async {
    try {
      isLoading.value = true;

      await FirebaseFirestore.instance
          .collection('payRoles')
          .doc(payRoleId)
          .update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      successSnackbar('Pay role deactivated successfully');
      return true;
    } catch (e) {
      errorSnackbar('Failed to deactivate pay role: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Get all employees across owner's businesses with their pay roles
  Future<List<Map<String, dynamic>>> getEmployeesWithPayRoles() async {
    try {
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      if (userBusinesses.isEmpty) return [];

      List<Map<String, dynamic>> employeesWithPay = [];
      
      // Get employees from each business
      for (String businessId in userBusinesses) {
        final employeesSnapshot = await FirebaseFirestore.instance
            .collection('employees')
            .doc(businessId)
            .collection('userEmployees')
            .get();

        for (var employeeDoc in employeesSnapshot.docs) {
          final employeeData = employeeDoc.data();
          final employeeId = employeeDoc.id;
          
          // Get business name
          final businessDoc = await FirebaseFirestore.instance
              .collection('businesses')
              .doc(businessId)
              .get();
          final businessName = businessDoc.data()?['name'] ?? 'Unknown Business';

          // Get pay role for this employee in this business
          final payRole = getEmployeePayRoleInBusiness(employeeId, businessId);

          employeesWithPay.add({
            'employee': ProfileModel.fromSnapshot(employeeDoc),
            'businessId': businessId,
            'businessName': businessName,
            'payRole': payRole,
            'hasPayRole': payRole != null,
          });
        }
      }

      return employeesWithPay;
    } catch (e) {
      errorSnackbar('Error loading employees: $e');
      return [];
    }
  }

  /// Apply filters to pay roles
  void _applyFilters() {
    List<PayRoleModel> filtered = List.from(payRoles);

    // Business filter
    if (selectedBusinessFilter.value.isNotEmpty) {
      filtered = filtered.where((payRole) => 
          payRole.businessId == selectedBusinessFilter.value).toList();
    }

    // Pay type filter
    if (selectedPayTypeFilter.value.isNotEmpty) {
      filtered = filtered.where((payRole) => 
          payRole.payType.toString().split('.').last == selectedPayTypeFilter.value).toList();
    }

    // Search filter
    if (searchQuery.value.isNotEmpty) {
      final query = searchQuery.value.toLowerCase();
      filtered = filtered.where((payRole) =>
          payRole.employeeName.toLowerCase().contains(query) ||
          payRole.businessName.toLowerCase().contains(query) ||
          payRole.notes?.toLowerCase().contains(query) == true).toList();
    }

    filteredPayRoles.value = filtered;
  }

  /// Set business filter
  void setBusinessFilter(String businessId) {
    selectedBusinessFilter.value = businessId;
    _applyFilters();
  }

  /// Set pay type filter
  void setPayTypeFilter(String payType) {
    selectedPayTypeFilter.value = payType;
    _applyFilters();
  }

  /// Set search query
  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applyFilters();
  }

  /// Clear all filters
  void clearFilters() {
    selectedBusinessFilter.value = '';
    selectedPayTypeFilter.value = '';
    searchQuery.value = '';
    _applyFilters();
  }

  /// Get total monthly payroll for a business
  double getTotalMonthlyPayroll(String businessId) {
    return payRoles
        .where((payRole) => payRole.businessId == businessId && payRole.isActive)
        .fold(0.0, (total, payRole) => total + payRole.getMonthlyEquivalent());
  }

  /// Get total monthly payroll across all businesses
  double getTotalMonthlyPayrollAllBusinesses() {
    return payRoles
        .where((payRole) => payRole.isActive)
        .fold(0.0, (total, payRole) => total + payRole.getMonthlyEquivalent());
  }

  /// Get pay types statistics
  Map<String, int> getPayTypeStatistics() {
    Map<String, int> stats = {};
    for (var payRole in payRoles.where((pr) => pr.isActive)) {
      final payTypeString = payRole.payType.toString().split('.').last;
      stats[payTypeString] = (stats[payTypeString] ?? 0) + 1;
    }
    return stats;
  }

  /// Get available pay schedules
  List<String> getAvailablePaySchedules() {
    return ['weekly', 'biweekly', 'monthly'];
  }

  /// Initialize real-time stream for employee losses
  void _initializeLossesStream() {
    try {
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      if (userBusinesses.isEmpty) return;

      // Create a stream that combines all businesses
      final List<Stream<QuerySnapshot>> businessStreams = userBusinesses.map((businessId) {
        return FirebaseFirestore.instance
            .collection('employeeLosses')
            .doc(businessId)
            .collection('userLosses')
            .orderBy('dateRecorded', descending: true)
            .snapshots();
      }).toList();

      // Combine all streams and listen
      if (businessStreams.isNotEmpty) {
        _employeeLossesSubscription = businessStreams.first.listen((snapshot) {
          List<EmployeeLossModel> allLosses = [];
          
          // Process first business
          allLosses.addAll(snapshot.docs
              .map((doc) => EmployeeLossModel.fromSnapshot(doc))
              .toList());
          
          // Add other businesses if they exist
          for (int i = 1; i < businessStreams.length; i++) {
            businessStreams[i].listen((otherSnapshot) {
              final otherLosses = otherSnapshot.docs
                  .map((doc) => EmployeeLossModel.fromSnapshot(doc))
                  .toList();
              allLosses.addAll(otherLosses);
              
              // Sort by date and update
              allLosses.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));
              employeeLosses.value = List.from(allLosses);
            });
          }
          
          // Sort by date and update
          allLosses.sort((a, b) => b.dateRecorded.compareTo(a.dateRecorded));
          employeeLosses.value = List.from(allLosses);
        });
      }
    } catch (e) {
      errorSnackbar('Error loading employee losses: $e');
    }
  }

  /// Initialize real-time stream for early payments
  void _initializeEarlyPaymentsStream() {
    try {
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      if (userBusinesses.isEmpty) return;

      // Create a stream that combines all businesses
      final List<Stream<QuerySnapshot>> businessStreams = userBusinesses.map((businessId) {
        return FirebaseFirestore.instance
            .collection('earlyPayments')
            .doc(businessId)
            .collection('userPayments')
            .orderBy('dateRequested', descending: true)
            .snapshots();
      }).toList();

      // Combine all streams and listen
      if (businessStreams.isNotEmpty) {
        _earlyPaymentsSubscription = businessStreams.first.listen((snapshot) {
          List<EarlyPaymentModel> allPayments = [];
          
          // Process first business
          allPayments.addAll(snapshot.docs
              .map((doc) => EarlyPaymentModel.fromSnapshot(doc))
              .toList());
          
          // Add other businesses if they exist
          for (int i = 1; i < businessStreams.length; i++) {
            businessStreams[i].listen((otherSnapshot) {
              final otherPayments = otherSnapshot.docs
                  .map((doc) => EarlyPaymentModel.fromSnapshot(doc))
                  .toList();
              allPayments.addAll(otherPayments);
              
              // Sort by date and update
              allPayments.sort((a, b) => b.dateRequested.compareTo(a.dateRequested));
              earlyPayments.value = List.from(allPayments);
            });
          }
          
          // Sort by date and update
          allPayments.sort((a, b) => b.dateRequested.compareTo(a.dateRequested));
          earlyPayments.value = List.from(allPayments);
        });
      }
    } catch (e) {
      errorSnackbar('Error loading early payments: $e');
    }
  }

  /// Add employee loss
  Future<bool> addEmployeeLoss({
    required String employeeId,
    required String employeeName,
    required String businessId,
    required String businessName,
    required double amount,
    required String description,
    required String category,
    required DateTime dateOccurred,
    String? notes,
  }) async {
    try {
      isLoading.value = true;

      final currentUserId = _profileController.user['id'] ?? '';
      final currentUserName = _profileController.user['name'] ?? '';
      final now = DateTime.now();

      final lossData = {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'businessId': businessId,
        'businessName': businessName,
        'amount': amount,
        'description': description,
        'category': category,
        'dateOccurred': Timestamp.fromDate(dateOccurred),
        'dateRecorded': Timestamp.fromDate(now),
        'recordedBy': currentUserId,
        'recordedByName': currentUserName,
        'isDeducted': false,
        'status': 'pending',
        'notes': notes,
      };

      await FirebaseFirestore.instance
          .collection('employeeLosses')
          .doc(businessId)
          .collection('userLosses')
          .add(lossData);

      successSnackbar('Employee loss recorded successfully');
      return true;
    } catch (e) {
      errorSnackbar('Failed to record employee loss: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update employee loss status
  Future<bool> updateLossStatus(String lossId, String status, {String? payrollId}) async {
    try {
      isLoading.value = true;

      final updateData = {
        'status': status,
        'isDeducted': status == 'deducted',
      };

      if (status == 'deducted' && payrollId != null) {
        updateData['deductedInPayrollId'] = payrollId;
        updateData['dateDeducted'] = FieldValue.serverTimestamp();
      }

      // Find the loss document across all businesses
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      for (String businessId in userBusinesses) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('employeeLosses')
              .doc(businessId)
              .collection('userLosses')
              .doc(lossId);
          
          final docSnapshot = await docRef.get();
          if (docSnapshot.exists) {
            await docRef.update(updateData);
            break;
          }
        } catch (e) {
          // Continue to next business if this one fails
          continue;
        }
      }

      successSnackbar('Loss status updated successfully');
      return true;
    } catch (e) {
      errorSnackbar('Failed to update loss status: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Request early payment
  Future<bool> requestEarlyPayment({
    required String employeeId,
    required String employeeName,
    required String businessId,
    required String businessName,
    required double amount,
    required String reason,
    String? notes,
  }) async {
    try {
      isLoading.value = true;

      final currentUserId = _profileController.user['id'] ?? '';
      final currentUserName = _profileController.user['name'] ?? '';
      final now = DateTime.now();

      final paymentData = {
        'employeeId': employeeId,
        'employeeName': employeeName,
        'businessId': businessId,
        'businessName': businessName,
        'amount': amount,
        'reason': reason,
        'dateRequested': Timestamp.fromDate(now),
        'dateApproved': Timestamp.fromDate(now),
        'approvedBy': currentUserId,
        'approvedByName': currentUserName,
        'paymentMethod': 'cash',
        'status': 'approved',
        'isDeductedFromSalary': false,
        'notes': notes,
      };

      final newDocRef = await FirebaseFirestore.instance
          .collection('earlyPayments')
          .doc(businessId)
          .collection('userPayments')
          .add(paymentData);

      // Create an expense immediately on approval
      try {
        final expense = Expense(
          id: '',
          title: 'Early Payment Approved: $employeeName - $reason',
          amount: amount,
          date: Timestamp.now(),
          category: 'Early Payments',
          addedBy: currentUserId,
          addedByName: currentUserName,
        );

        final newExpenseRef = FirebaseFirestore.instance
            .collection('expenses')
            .doc(businessId)
            .collection('userExpenses')
            .doc();

        await newExpenseRef.set(expense.toMap());
        print('[EarlyPayment Approval] Expense created for early payment ${newDocRef.id}: ${newExpenseRef.id}');
      } catch (e) {
        print('[EarlyPayment Approval] Failed to create expense: $e');
      }

      successSnackbar('Early payment request approved and expense created');
      return true;
    } catch (e) {
      errorSnackbar('Failed to create early payment request: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Mark early payment as paid
  Future<bool> markEarlyPaymentAsPaid(String paymentId, String paymentMethod) async {
    try {
      isLoading.value = true;

      final currentUserId = _profileController.user['id'] ?? '';
      final currentUserName = _profileController.user['name'] ?? '';

      // Find the payment document across all businesses
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      String? foundBusinessId;
      Map<String, dynamic>? earlyPaymentData;
      
      for (String businessId in userBusinesses) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('earlyPayments')
              .doc(businessId)
              .collection('userPayments')
              .doc(paymentId);
          
          final docSnapshot = await docRef.get();
          if (docSnapshot.exists) {
            earlyPaymentData = docSnapshot.data() as Map<String, dynamic>?;
            foundBusinessId = businessId;
            await docRef.update({
              'status': 'paid',
              'datePaid': FieldValue.serverTimestamp(),
              'paidBy': currentUserId,
              'paidByName': currentUserName,
              'paymentMethod': paymentMethod,
            });
            break;
          }
        } catch (e) {
          // Continue to next business if this one fails
          continue;
        }
      }

      // Note: Expense is now created at approval time to reflect cash outflow immediately.

      successSnackbar('Early payment marked as paid');
      return true;
    } catch (e) {
      errorSnackbar('Failed to mark payment as paid: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Update early payment deduction status
  Future<bool> updateEarlyPaymentDeduction(String paymentId, {String? payrollId}) async {
    try {
      final updateData = {
        'isDeductedFromSalary': true,
        'dateDeducted': FieldValue.serverTimestamp(),
      };

      if (payrollId != null) {
        updateData['deductedInPayrollId'] = payrollId;
      }

      // Find the payment document across all businesses
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      for (String businessId in userBusinesses) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('earlyPayments')
              .doc(businessId)
              .collection('userPayments')
              .doc(paymentId);
          
          final docSnapshot = await docRef.get();
          if (docSnapshot.exists) {
            await docRef.update(updateData);
            break;
          }
        } catch (e) {
          // Continue to next business if this one fails
          continue;
        }
      }

      return true;
    } catch (e) {
      errorSnackbar('Failed to update early payment deduction: $e');
      return false;
    }
  }

  /// Get pending losses for an employee
  List<EmployeeLossModel> getPendingLossesForEmployee(String employeeId, String businessId) {
    return employeeLosses
        .where((loss) => 
            loss.employeeId == employeeId && 
            loss.businessId == businessId && 
            loss.status == 'pending')
        .toList();
  }

  /// Get paid early payments for an employee that need deduction
  List<EarlyPaymentModel> getUndeductedEarlyPayments(String employeeId, String businessId) {
    final result = earlyPayments
        .where((payment) => 
            payment.employeeId == employeeId && 
            payment.businessId == businessId && 
            (payment.status == 'paid' || payment.status == 'approved') && 
            !payment.isDeductedFromSalary)
        .toList();
    
    print('[PayRoleController] Found ${result.length} undeducted early payments for employee $employeeId');
    for (final payment in result) {
      print('[PayRoleController] - EarlyPayment to deduct: ${payment.amount} (${payment.paymentId}) status=${payment.status}');
    }
    
    return result;
  }

  /// Calculate net salary after deductions and advances
  double calculateNetSalary({
    required String employeeId,
    required String businessId,
    required double grossSalary,
  }) {
    final pendingLosses = getPendingLossesForEmployee(employeeId, businessId);
    final undeductedAdvances = getUndeductedEarlyPayments(employeeId, businessId);

    final totalLossDeductions = pendingLosses.fold<double>(0.0, (sum, loss) => sum + loss.amount);
    final totalAdvanceDeductions = undeductedAdvances.fold<double>(0.0, (sum, payment) => sum + payment.amount);

    print('[PayRoleController] Calculating salary for employee $employeeId in business $businessId');
    print('[PayRoleController] Gross salary: $grossSalary');
    print('[PayRoleController] Pending losses: ${pendingLosses.length} items, total: $totalLossDeductions');
    print('[PayRoleController] Undeducted advances: ${undeductedAdvances.length} items, total: $totalAdvanceDeductions');
    print('[PayRoleController] Net salary: ${grossSalary - totalLossDeductions - totalAdvanceDeductions}');

    return grossSalary - totalLossDeductions - totalAdvanceDeductions;
  }

  /// Get salary breakdown for an employee
  Map<String, dynamic> getSalaryBreakdown({
    required String employeeId,
    required String businessId,
    required double grossSalary,
  }) {
    final pendingLosses = getPendingLossesForEmployee(employeeId, businessId)
        .where((l) => l.outstandingAmount > 0)
        .toList()
      ..sort((a, b) => a.dateRecorded.compareTo(b.dateRecorded));

    final undeductedAdvances = getUndeductedEarlyPayments(employeeId, businessId)
        .where((e) => e.outstandingAmount > 0)
        .toList()
      ..sort((a, b) => a.dateApproved.compareTo(b.dateApproved));

    double capacity = grossSalary;
    double appliedAdvances = 0.0;
    double appliedLosses = 0.0;
    final List<Map<String, dynamic>> appliedEarlyPayments = [];
    final List<Map<String, dynamic>> appliedLossItems = [];

    // Strategy: deduct early payments first (oldest first), then losses (oldest first)
    for (final ep in undeductedAdvances) {
      if (capacity <= 0) break;
      final outstanding = ep.outstandingAmount;
      if (outstanding <= 0) continue;
      final apply = outstanding <= capacity ? outstanding : capacity;
      if (apply > 0) {
        appliedEarlyPayments.add({'id': ep.paymentId, 'amount': apply, 'type': 'early'});
        appliedAdvances += apply;
        capacity -= apply;
      }
    }

    for (final loss in pendingLosses) {
      if (capacity <= 0) break;
      final outstanding = loss.outstandingAmount;
      if (outstanding <= 0) continue;
      final apply = outstanding <= capacity ? outstanding : capacity;
      if (apply > 0) {
        appliedLossItems.add({'id': loss.lossId, 'amount': apply, 'type': 'loss'});
        appliedLosses += apply;
        capacity -= apply;
      }
    }

    final totalRequestedDeductions =
        undeductedAdvances.fold<double>(0.0, (s, e) => s + e.outstandingAmount) +
        pendingLosses.fold<double>(0.0, (s, l) => s + l.outstandingAmount);
    final totalApplied = appliedAdvances + appliedLosses;
    final carryover = totalRequestedDeductions - totalApplied;
    final netSalary = capacity < 0 ? 0.0 : capacity; // never negative

    return {
      'grossSalary': grossSalary,
      'lossDeductions': appliedLosses,
      'advanceDeductions': appliedAdvances,
      'totalDeductions': totalApplied,
      'netSalary': netSalary,
      'pendingLosses': pendingLosses,
      'undeductedAdvances': undeductedAdvances,
      'appliedEarlyPayments': appliedEarlyPayments,
      'appliedLosses': appliedLossItems,
      'carryoverDeductions': carryover > 0 ? carryover : 0.0,
    };
  }

  /// Partially update early payment deduction by amount
  Future<bool> updateEarlyPaymentDeductionPartial(String paymentId, double amount, {String? payrollId}) async {
    try {
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      for (final businessId in userBusinesses) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('earlyPayments')
              .doc(businessId)
              .collection('userPayments')
              .doc(paymentId);
          final snap = await docRef.get();
          if (!snap.exists) continue;
          final data = snap.data() as Map<String, dynamic>;
          final total = (data['amount'] ?? 0).toDouble();
          final already = (data['amountDeductedFromSalary'] ?? 0).toDouble();
          final newTotal = (already + amount);
          final updates = <String, dynamic>{
            'amountDeductedFromSalary': newTotal,
          };
          if (payrollId != null) updates['deductedInPayrollId'] = payrollId;
          if (newTotal >= total - 0.0001) {
            updates['isDeductedFromSalary'] = true;
            updates['dateDeducted'] = FieldValue.serverTimestamp();
          }
          await docRef.update(updates);
          break;
        } catch (_) { continue; }
      }
      return true;
    } catch (e) {
      errorSnackbar('Failed to update early payment partial deduction: $e');
      return false;
    }
  }

  /// Partially update employee loss deduction by amount
  Future<bool> updateLossDeductionPartial(String lossId, double amount, {String? payrollId}) async {
    try {
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      for (final businessId in userBusinesses) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('employeeLosses')
              .doc(businessId)
              .collection('userLosses')
              .doc(lossId);
          final snap = await docRef.get();
          if (!snap.exists) continue;
          final data = snap.data() as Map<String, dynamic>;
          final total = (data['amount'] ?? 0).toDouble();
          final already = (data['amountDeductedFromSalary'] ?? 0).toDouble();
          final newTotal = (already + amount);
          final updates = <String, dynamic>{
            'amountDeductedFromSalary': newTotal,
          };
          if (payrollId != null) updates['deductedInPayrollId'] = payrollId;
          if (newTotal >= total - 0.0001) {
            updates['status'] = 'deducted';
            updates['isDeducted'] = true;
            updates['dateDeducted'] = FieldValue.serverTimestamp();
          }
          await docRef.update(updates);
          break;
        } catch (_) { continue; }
      }
      return true;
    } catch (e) {
      errorSnackbar('Failed to update loss partial deduction: $e');
      return false;
    }
  }

  /// Delete employee loss
  Future<bool> deleteEmployeeLoss(String lossId) async {
    try {
      isLoading.value = true;

      // Find and delete the loss document across all businesses
      final currentUser = _profileController.user;
      final userBusinesses = List<String>.from(currentUser['business'] ?? []);
      
      for (String businessId in userBusinesses) {
        try {
          final docRef = FirebaseFirestore.instance
              .collection('employeeLosses')
              .doc(businessId)
              .collection('userLosses')
              .doc(lossId);
          
          final docSnapshot = await docRef.get();
          if (docSnapshot.exists) {
            await docRef.delete();
            break;
          }
        } catch (e) {
          // Continue to next business if this one fails
          continue;
        }
      }

      successSnackbar('Employee loss deleted successfully');
      return true;
    } catch (e) {
      errorSnackbar('Failed to delete employee loss: $e');
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  /// Refresh all data
  Future<void> refreshPayRoles() async {
    _payRoleSubscription?.cancel();
    _employeeLossesSubscription?.cancel();
    _earlyPaymentsSubscription?.cancel();
    _initializePayRoleStream();
    _initializeLossesStream();
    _initializeEarlyPaymentsStream();
  }
}
