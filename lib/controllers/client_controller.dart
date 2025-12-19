import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import '../models/client_model.dart';
import '../services/firestore_db.dart';
import '../utils/constants.dart';

class ClientController extends GetxController {
  final BusinessController _businessController = Get.find();

  final clients = <Client>[].obs;
  final searchClients = <Client>[].obs;
  final sortCategory = 'name'.obs;
  final filterType = 'all'.obs;

  StreamSubscription<List<Client>>? _clientSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _clientSubscription = FirestoreDb().getClients().listen((data) {
        clients.value = data;
        searchClients.value = data;
      });
    } catch (e) {
      print("Error binding client stream: $e");
    }
  }

  @override
  void onClose() {
    _clientSubscription?.cancel();
    super.onClose();
  }

  Client getClient(String clientId) {
    return clients.firstWhere((client) => client.id == clientId,
        orElse: () => Client(
          owner: '',
          id: '',
          name: '',
          phone: '',
          date: Timestamp.now(),
        ));
  }

  Future<void> updateAdvance(Client client, double amount) async {
    final String? business = _businessController.businessId.value;
    if (business == null) {
      print('Owner ID is null, cannot update client advance.');
      return;
    }
    try {
      print('Updating advance for client: ${client.id}');
      // Create a transaction record for the addition.
      Map<String, dynamic> transactionRecord = {
        'amount': amount, // Positive amount for an addition.
        'time': Timestamp.now(), // Use client timestamp
      };

      await firestore
          .collection('clients')
          .doc(business)
          .collection('userClients')
          .doc(client.id)
          .update({
        'advance': client.advance + amount,
        'advanceTransactions': FieldValue.arrayUnion([transactionRecord]),
      });

      print('Advance updated successfully for client: ${client.id}');
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

  Future<void> reduceAdvance(Client client, double amount) async {
    final String? business = _businessController.businessId.value;
    if (business == null) {
      print('Owner ID is null, cannot update client advance.');
      return;
    }
    try {
      // Create a transaction record for the reduction (negative amount).
      Map<String, dynamic> transactionRecord = {
        'amount': -amount, // Negative value for a reduction.
        'time': Timestamp.now(), // Use client timestamp
      };

      await firestore
          .collection('clients')
          .doc(business)
          .collection('userClients')
          .doc(client.id)
          .update({
        'advance': client.advance - amount,
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

  Future<void> updateDebt(Client client, double debt) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot update client debt.');
      return;
    }

    try {
      firestore
          .collection('clients')
          .doc(business)
          .collection('userClients')
          .doc(client.id)
          .update({
        'debt': debt,
      });
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  void deleteClient(String clientId) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot delete client.');
      return;
    }

    try {
      await firestore
          .collection('clients')
          .doc(business)
          .collection('userClients')
          .doc(clientId)
          .delete();
      successSnackbar('${'client'.tr} ${'deleted'.tr}');
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  void clearClients(){
    clients.value.clear();
    searchClients.value.clear();
  }

  void search(String searchText) {
    searchClients.value = clients
        .where((client) =>
        client.name.toLowerCase().contains(searchText.toLowerCase()))
        .toList();
  }

  void sort(String category) {
    sortCategory.value = category;
    switch (category) {
      case 'name':
        searchClients.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'debt':
        searchClients.sort((a, b) => b.debt.compareTo(a.debt));
        break;
      case 'date':
        searchClients.sort((a, b) => b.date.compareTo(a.date));
        break;
      default:
        searchClients.sort((a, b) => a.name.compareTo(b.name));
    }
  }

  void setSortCategoryValue(String value) {
    sortCategory.value = value;
  }

  void applyFilter(String filter) {
    filterType.value = filter;
    
    switch (filter) {
      case 'all':
        searchClients.value = clients;
        break;
      case 'with_debt':
        searchClients.value = clients.where((client) => client.debt > 0).toList();
        break;
      case 'with_advance':
        searchClients.value = clients.where((client) => client.advance > 0).toList();
        break;
      case 'no_balance':
        searchClients.value = clients.where((client) => client.debt == 0 && client.advance == 0).toList();
        break;
      default:
        searchClients.value = clients;
    }
    
    // Re-apply current sort after filtering
    sort(sortCategory.value);
  }
}
