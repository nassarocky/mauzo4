import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import '../models/supplier_model.dart';
import '../services/firestore_db.dart';
import '../utils/constants.dart';

class SupplierController extends GetxController {
  final BusinessController _businessController = Get.find();

  final suppliers = <Supplier>[].obs;
  final searchSuppliers = <Supplier>[].obs;
  final sortCategory = 'name'.obs;

  StreamSubscription<List<Supplier>>? _supplierSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _supplierSubscription = FirestoreDb().getSuppliers().listen((data) {
        suppliers.value = data;
        searchSuppliers.value = data;
      });
    } catch (e) {
      print("Error binding supplier stream: $e");
    }
  }

  @override
  void onClose() {
    _supplierSubscription?.cancel();
    super.onClose();
  }

  Supplier getSupplier(String supplierId) {
    return suppliers.firstWhere((supplier) => supplier.id == supplierId,
        orElse: () => Supplier(
          owner: '',
          id: '',
          name: '',
          phone: '',
          date: Timestamp.now(),
        ));
  }

  Future<void> updateAdvance(Supplier supplier, double amount) async {
    final String? business = _businessController.businessId.value;
    if (business == null) {
      print('Business ID is null, cannot update supplier advance.');
      return;
    }
    try {
      print('Updating advance for supplier: ${supplier.id}');
      // Create a transaction record for the addition.
      Map<String, dynamic> transactionRecord = {
        'amount': amount, // Positive amount for an addition.
        'time': Timestamp.now(), // Use current timestamp
      };

      await firestore
          .collection('suppliers')
          .doc(business)
          .collection('userSuppliers')
          .doc(supplier.id)
          .update({
        'advance': supplier.advance + amount,
        'advanceTransactions': FieldValue.arrayUnion([transactionRecord]),
      });

      print('Advance updated successfully for supplier: ${supplier.id}');
      Get.snackbar(
        'Success',
        'Advance added successfully!',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error updating advance: $e');
      errorSnackbar(e.toString());
    }
  }

  Future<void> reduceAdvance(Supplier supplier, double amount) async {
    final String? business = _businessController.businessId.value;
    if (business == null) {
      print('Business ID is null, cannot update supplier advance.');
      return;
    }
    try {
      // Create a transaction record for the reduction (negative amount).
      Map<String, dynamic> transactionRecord = {
        'amount': -amount, // Negative value for a reduction.
        'time': Timestamp.now(), // Use current timestamp
      };

      await firestore
          .collection('suppliers')
          .doc(business)
          .collection('userSuppliers')
          .doc(supplier.id)
          .update({
        'advance': supplier.advance - amount,
        'advanceTransactions': FieldValue.arrayUnion([transactionRecord]),
      });

      Get.snackbar(
        'Success',
        'Advance reduced successfully!',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  Future<void> updateDebt(Supplier supplier, double debt) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Business ID is null, cannot update supplier debt.');
      return;
    }

    try {
      firestore
          .collection('suppliers')
          .doc(business)
          .collection('userSuppliers')
          .doc(supplier.id)
          .update({
        'debt': debt,
      });
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  void deleteSupplier(String supplierId) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Business ID is null, cannot delete supplier.');
      return;
    }

    try {
      await firestore
          .collection('suppliers')
          .doc(business)
          .collection('userSuppliers')
          .doc(supplierId)
          .delete();
      successSnackbar('${'supplier'.tr} ${'deleted'.tr}');
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  void clearSuppliers(){
    suppliers.value.clear();
    searchSuppliers.value.clear();
  }

  void search(String searchText) {
    searchSuppliers.value = suppliers
        .where((supplier) =>
        supplier.name.toLowerCase().contains(searchText.toLowerCase()) ||
        (supplier.company?.toLowerCase().contains(searchText.toLowerCase()) ?? false))
        .toList();
  }

  void sort(String category) {
    sortCategory.value = category;
    switch (category) {
      case 'name':
        searchSuppliers.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'company':
        searchSuppliers.sort((a, b) => (a.company ?? '').compareTo(b.company ?? ''));
        break;
      case 'debt':
        searchSuppliers.sort((a, b) => b.debt.compareTo(a.debt));
        break;
      case 'date':
        searchSuppliers.sort((a, b) => b.date.compareTo(a.date));
        break;
      default:
        searchSuppliers.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  void setSortCategoryValue(String value) {
    sortCategory.value = value;
  }
}
