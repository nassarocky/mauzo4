import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../controllers/business_controller.dart';
import '../controllers/profile_controller.dart';
import '../models/supplier_debt_model.dart';
import '../services/firestore_db.dart';
import '../utils/constants.dart';

class SupplierDebtController extends GetxController {
  final supplierDebts = <SupplierDebt>[].obs;
  final searchSupplierDebts = <SupplierDebt>[].obs;
  final searchText = ''.obs;
  final filteredSupplierDebts = <SupplierDebt>[].obs;
  final filterStatus = <String>[].obs;
  final selectedSupplier = 'No supplier'.obs;
  final selectedStatus = 'No status'.obs;
  final RxBool isLoading = false.obs;

  StreamSubscription<QuerySnapshot>? _supplierDebtSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _supplierDebtSubscription = getSupplierDebts().listen((snapshot) {
        final data = snapshot.docs.map((doc) => SupplierDebt.fromSnapshot(doc)).toList();
        supplierDebts.value = data;
        searchSupplierDebts.value = data;
        filteredSupplierDebts.value = data;
      });
    } catch (e) {
      print("Error initializing SupplierDebtController: $e");
    }
  }

  @override
  void onClose() {
    _supplierDebtSubscription?.cancel();
    super.onClose();
  }

  // Get supplier debts stream from Firestore
  Stream<QuerySnapshot> getSupplierDebts() {
    final businessId = Get.find<BusinessController>().business['id'];
    return firestore
        .collection('supplierDebts')
        .doc(businessId)
        .collection('userSupplierDebts')
        .orderBy('dateIncurred', descending: true)
        .snapshots();
  }

  // Method to get a specific supplier debt by ID
  SupplierDebt getSupplierDebtById(String debtId) {
    return supplierDebts.firstWhere(
      (debt) => debt.id == debtId,
      orElse: () => SupplierDebt(
        supplier: '',
        supplierName: '',
        owner: '',
        id: '',
        initialDebtAmount: 0.0,
        remainingDebtAmount: 0.0,
        paymentRecords: [],
        dateIncurred: Timestamp.now(),
        status: 'pending',
        comment: '',
        employeeId: '',
        employeeName: '',
      ),
    );
  }

  // Create a new supplier debt record
  Future<void> createSupplierDebt({
    required String supplierId,
    required String supplierName,
    required double debtAmount,
    required String comment,
    String? purchaseId,
  }) async {
    try {
      isLoading.value = true;
      final businessId = Get.find<BusinessController>().business['id'];
      
      final supplierDebt = SupplierDebt(
        id: '',
        supplier: supplierId,
        supplierName: supplierName,
        owner: businessId,
        initialDebtAmount: debtAmount,
        remainingDebtAmount: debtAmount,
        paymentRecords: [],
        dateIncurred: Timestamp.now(),
        status: 'pending',
        comment: comment,
        employeeId: Get.find<ProfileController>().user['id'] ?? '',
        employeeName: Get.find<ProfileController>().user['name'] ?? '',
      );

      await firestore
          .collection('supplierDebts')
          .doc(businessId)
          .collection('userSupplierDebts')
          .add(supplierDebt.toMap());

      successSnackbar('Supplier debt recorded successfully');
    } catch (e) {
      errorSnackbar('Error creating supplier debt: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Make a payment towards supplier debt
  Future<void> makePayment({
    required String debtId,
    required double paymentAmount,
    required String paymentMethod,
    String? paymentNote,
  }) async {
    try {
      isLoading.value = true;
      final businessId = Get.find<BusinessController>().business['id'];
      final debt = getSupplierDebtById(debtId);
      
      if (debt.id.isEmpty) {
        errorSnackbar('Supplier debt not found');
        return;
      }

      final newRemainingAmount = debt.remainingDebtAmount - paymentAmount;
      final paymentRecord = {
        'amount': paymentAmount,
        'method': paymentMethod,
        'date': Timestamp.now(),
        'note': paymentNote ?? '',
      };

      final updatedPaymentRecords = List<Map<String, dynamic>>.from(debt.paymentRecords)
        ..add(paymentRecord);

      String newStatus;
      if (newRemainingAmount <= 0) {
        newStatus = 'paid';
      } else if (updatedPaymentRecords.length > 1) {
        newStatus = 'partially_paid';
      } else {
        newStatus = 'pending';
      }

      await firestore
          .collection('supplierDebts')
          .doc(businessId)
          .collection('userSupplierDebts')
          .doc(debtId)
          .update({
        'remainingDebtAmount': newRemainingAmount > 0 ? newRemainingAmount : 0,
        'paymentRecords': updatedPaymentRecords,
        'status': newStatus,
      });

      successSnackbar('Payment recorded successfully');
    } catch (e) {
      errorSnackbar('Error recording payment: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Filter supplier debts by status
  void setFilterStatus(List<String> statuses) {
    filterStatus.value = statuses;
    filterSupplierDebts();
  }

  // Apply filters to supplier debts
  void filterSupplierDebts() {
    List<SupplierDebt> filtered = searchSupplierDebts;

    if (filterStatus.isNotEmpty) {
      filtered = filtered.where((debt) => filterStatus.contains(debt.status.toUpperCase())).toList();
    }

    filteredSupplierDebts.value = filtered;
  }

  // Search supplier debts by supplier name
  void searchSupplierDebtsByName(String query) {
    searchText.value = query;
    if (query.isEmpty) {
      searchSupplierDebts.value = supplierDebts;
    } else {
      searchSupplierDebts.value = supplierDebts
          .where((debt) => debt.supplierName.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
    filterSupplierDebts();
  }

  // Get total debt amount for all suppliers
  double get totalSupplierDebt {
    return supplierDebts.fold(0.0, (sum, debt) => sum + debt.remainingDebtAmount);
  }

  // Get total debt amount for a specific supplier
  double getSupplierTotalDebt(String supplierId) {
    return supplierDebts
        .where((debt) => debt.supplier == supplierId)
        .fold(0.0, (sum, debt) => sum + debt.remainingDebtAmount);
  }
}
