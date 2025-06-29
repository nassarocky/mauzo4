import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import '../models/stock_transaction.dart';
import '../services/firestore_db.dart';

class TransactionController extends GetxController {
  StreamSubscription<List<StockTransaction>>? _transactionSubscription;

  final transactions = <StockTransaction>[].obs;
  final searchTransactions = <StockTransaction>[].obs;
  final searchText = ''.obs;
  final filteredtransactions = <StockTransaction>[].obs;
  final filterCategories = <String>[].obs;

  final selectedCategory = 'No category'.obs;
  final selectedManufacturer = 'No manufacturer'.obs;

  @override
  void onInit() {
    super.onInit();

    try {
      _transactionSubscription = FirestoreDb().getTransactions().listen((data)
      {

        transactions.value = data;
        searchTransactions.value = data;
        filteredtransactions.value = data;
      });
    } catch (e) {
      print("Error binding transaction stream: $e");
    }
  }

  @override
  void onClose() {
    _transactionSubscription?.cancel();
    super.onClose();
  }

  StockTransaction getTransactions(String transactionId) {
    return transactions.firstWhere(
          (transaction) => transaction.transactionId == transactionId,
      orElse: () => StockTransaction(
        transactionId: '',
        productId: '',
        quantity: 0,
        previousQuantity: 0,
        transactionType: '',
        transactionOrigin: '',
        timestamp: Timestamp.now(),
        userId: '',
        price: 0.0,
      ),
    );
  }

  void filterByTransactionOrigin(String origin) {
    filteredtransactions.value = transactions.where((transaction) {
      return transaction.transactionOrigin == origin;
    }).toList();
  }

  void filteredTransactions() {
    filteredtransactions.value = transactions;
    if (searchText.value.isNotEmpty) {
      filteredtransactions.value = transactions
          .where((transaction) => transaction.transactionType
          .toLowerCase()
          .contains(searchText.value.toLowerCase()))
          .toList();
    }
    if (filterCategories.isNotEmpty) {
      filteredtransactions.value = filteredtransactions.where((transaction) {
        return filterCategories.contains(transaction.transactionOrigin);
      }).toList();
    }
  }

  List<StockTransaction> getTransactionsByProductId(String productId) {
    return transactions
        .where((transaction) => transaction.productId == productId)
        .toList();
  }

  void setFilterCategories(List<String> categories) {
    filterCategories.value = categories;
    filteredTransactions();
  }

  void search(String searchValue) {
    searchText.value = searchValue;
    searchTransactions.value = transactions
        .where((transaction) => transaction.transactionOrigin
        .toLowerCase()
        .contains(searchValue.toLowerCase()))
        .toList();
    filteredTransactions();
  }

  void setCategory(String updatedCategory) {
    selectedCategory.value = updatedCategory;
  }

  void setManufacturer(String updatedManufacturer) {
    selectedManufacturer.value = updatedManufacturer;
  }

  void clearData() {
    transactions.clear();
    filteredtransactions.clear();
  }
}
