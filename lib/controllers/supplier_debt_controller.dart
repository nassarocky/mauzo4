import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../controllers/business_controller.dart';
import '../controllers/profile_controller.dart';
import '../models/supplier_debt_model.dart';
import '../services/firestore_db.dart';
import '../utils/constants.dart';
import 'package:mauzo/services/ledger_service.dart';

class SupplierDebtController extends GetxController {
  final supplierDebts = <SupplierDebt>[].obs;
  final searchSupplierDebts = <SupplierDebt>[].obs;
  final searchText = ''.obs;
  final filteredSupplierDebts = <SupplierDebt>[].obs;
  final filterStatus = <String>[].obs;
  final selectedSupplier = 'No supplier'.obs;
  final selectedStatus = 'No status'.obs;
  final RxBool isLoading = false.obs;
  
  // Current status being viewed (default: pending for optimization)
  final currentStatus = 'pending'.obs;

  StreamSubscription<QuerySnapshot>? _supplierDebtSubscription;

  @override
  void onInit() {
    super.onInit();
    print('[DEBUG SupplierDebtController] onInit called');
    
    final ProfileController _profileController = Get.find();
    final String userRole = _profileController.user['role'] ?? '';
    
    // Load supplier debts for all roles except agents (sales persons do purchases and need to track supplier debts)
    if (userRole != 'agent') {
      // Load pending debts by default (optimized)
      loadDebtsByStatus('pending');
    } else {
      // Set empty data for agents (no error)
      supplierDebts.value = [];
      filteredSupplierDebts.value = [];
      print('SupplierDebtController: Agents cannot view supplier debts, skipping data initialization');
    }
  }

  @override
  void onClose() {
    _supplierDebtSubscription?.cancel();
    super.onClose();
  }

  // Switch to different status (queries database) - optimized to reduce reads
  void loadDebtsByStatus(String status) async {
    currentStatus.value = status;
    
    try {
      // Cancel previous subscription
      await _supplierDebtSubscription?.cancel();
      
      // Query database for specific status only
      _supplierDebtSubscription = getSupplierDebts(status: status).listen((snapshot) {
        print('[DEBUG SupplierDebtController] Received snapshot with ${snapshot.docs.length} documents for status: $status');
        final data = snapshot.docs.map((doc) {
          return SupplierDebt.fromSnapshot(doc);
        }).toList();
        
        // Sort by date in memory after fetching
        data.sort((a, b) => b.dateIncurred.compareTo(a.dateIncurred));
        
        supplierDebts.value = data;
        searchSupplierDebts.value = data;
        filteredSupplierDebts.value = data;
        print('[DEBUG SupplierDebtController] Updated lists with ${data.length} debts');
      }, onError: (error) {
        print('[ERROR SupplierDebtController] Stream error: $error');
      });
    } catch (e) {
      print("[ERROR SupplierDebtController] Error loading debts by status: $e");
    }
  }

  // Get supplier debts stream from Firestore by status
  Stream<QuerySnapshot> getSupplierDebts({String status = 'pending'}) {
    final bc = Get.find<BusinessController>();
    final String businessId = (bc.business['id'] ?? '').toString().isNotEmpty
        ? bc.business['id']
        : (bc.businessId.value);
    print('[DEBUG SupplierDebtController] Getting supplier debts for business: $businessId with status: $status');
    
    if (businessId.isEmpty) {
      print('[WARN SupplierDebtController] businessId is empty in getSupplierDebts()');
    }

    final stream = firestore
        .collection('supplierDebts')
        .doc(businessId)
        .collection('userSupplierDebts')
        .where('status', isEqualTo: status)
        .snapshots();
    
    print('[DEBUG SupplierDebtController] Stream created for path: supplierDebts/$businessId/userSupplierDebts with status filter');
    return stream;
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
    List<Map<String, dynamic>>? products,
  }) async {
    try {
      print('[DEBUG] Creating supplier debt: supplierId=$supplierId, amount=$debtAmount');
      isLoading.value = true;
      final bc = Get.find<BusinessController>();
      final String businessId = (bc.business['id'] ?? '').toString().isNotEmpty
          ? bc.business['id']
          : (bc.businessId.value);
      print('[DEBUG] Business ID: $businessId');
      if (businessId.isEmpty) {
        print('[ERROR] Business ID is empty. Aborting createSupplierDebt');
        errorSnackbar('Business not ready. Please try again');
        return;
      }
      
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
        purchaseId: purchaseId,
        products: products,
      );

      // Add debt record to supplierDebts collection
      print('[DEBUG] Adding debt record to Firestore');
      final debtRef = await firestore
          .collection('supplierDebts')
          .doc(businessId)
          .collection('userSupplierDebts')
          .add(supplierDebt.toMap());
      
      print('[DEBUG] Debt record added with ID: ${debtRef.id}');
      
      // Update the debt ID in the document
      await debtRef.update({'id': debtRef.id});
      
      // Note: Supplier's debt field is now updated in Buy_Product_cart_screen.dart
      // using SupplierController.updateDebt() for consistency with client debt handling

      successSnackbar('Supplier debt recorded successfully');
      print('[DEBUG] Supplier debt creation completed successfully');
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
      final bc = Get.find<BusinessController>();
      final String businessId = (bc.business['id'] ?? '').toString().isNotEmpty
          ? bc.business['id']
          : (bc.businessId.value);
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
      
      // Update supplier's debt field using SupplierController
      // Note: We need to get the supplier first, then update using SupplierController
      final supplierRef = firestore
          .collection('suppliers')
          .doc(businessId)
          .collection('userSuppliers')
          .doc(debt.supplier);
          
      final supplierDoc = await supplierRef.get();
      if (supplierDoc.exists) {
        final currentDebt = (supplierDoc.data()?['debt'] ?? 0.0) as num;
        final newDebt = currentDebt - paymentAmount;
        // Direct update since we don't have the full Supplier object
        await supplierRef.update({
          'debt': newDebt > 0 ? newDebt : 0,
        });
      }

      // Also update the related purchase (recovered) document so Bought screen reflects the new debt
      if (debt.purchaseId != null && debt.purchaseId!.isNotEmpty) {
        try {
          final purchaseRef = firestore
              .collection('recovered')
              .doc(businessId)
              .collection('userRecovered')
              .doc(debt.purchaseId);

          final purchaseSnap = await purchaseRef.get();
          if (purchaseSnap.exists) {
            final data = purchaseSnap.data() as Map<String, dynamic>;

            // Extract price/payment safely (handle int/double)
            double price = 0.0;
            final rawPrice = data['price'];
            if (rawPrice is int) price = rawPrice.toDouble();
            else if (rawPrice is double) price = rawPrice;

            double currentPayment = 0.0;
            final rawPayment = data['payment'];
            if (rawPayment is int) currentPayment = rawPayment.toDouble();
            else if (rawPayment is double) currentPayment = rawPayment;

            // Compute new debt and payment for the purchase
            final double updatedDebt = newRemainingAmount > 0 ? newRemainingAmount : 0.0;
            double updatedPayment;
            if (price > 0) {
              updatedPayment = price - updatedDebt;
              if (updatedPayment < 0) updatedPayment = 0.0;
            } else {
              // Fallback if price missing: increment by this payment
              updatedPayment = currentPayment + paymentAmount;
            }

            // Append a payment record to the purchase's payments array
            final List<dynamic> existingPayments = List<dynamic>.from(data['payments'] ?? []);
            existingPayments.add({
              'amount': paymentAmount,
              'method': paymentMethod,
              'date': Timestamp.now(),
              'note': paymentNote ?? 'Supplier debt payment',
            });

            await purchaseRef.update({
              'debt': updatedDebt,
              'payment': updatedPayment,
              'payments': existingPayments,
            });
          } else {
            print('[WARN] Purchase document not found for purchaseId=${debt.purchaseId}');
          }
        } catch (e) {
          print('[ERROR] Failed to update purchase document for supplier debt payment: $e');
        }
      } else {
        print('[INFO] No purchaseId associated with this supplier debt; skipping purchase update');
      }

      // Post ledger OUT for supplier debt repayment
      try {
        await LedgerService().postSupplierDebtPaymentOut(
          debtId: debtId,
          amount: paymentAmount,
          method: paymentMethod,
          postedAt: Timestamp.now(),
        );
      } catch (e) {
        print('⚠️ Ledger postSupplierDebtPaymentOut failed for debt $debtId: $e');
      }

      successSnackbar('Payment recorded successfully');
    } catch (e) {
      errorSnackbar('Error recording payment: $e');
    } finally {
      isLoading.value = false;
    }
  }

  // Filter supplier debts by status - now switches database query for optimization
  void setFilterStatus(List<String> statuses) {
    filterStatus.value = statuses;
    
    // If a single status is selected, query database for that status (convert to lowercase for DB)
    if (statuses.length == 1) {
      final dbStatus = statuses.first.toLowerCase();
      loadDebtsByStatus(dbStatus);
    } else if (statuses.isEmpty) {
      // Default to pending if no status selected  
      loadDebtsByStatus('pending');
    } else {
      // For multiple statuses, filter in memory
      filterSupplierDebts();
    }
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
