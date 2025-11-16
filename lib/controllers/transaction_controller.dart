import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
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
  
  // NEW: Cache for per-product transaction streams
  final Map<String, StreamSubscription<List<StockTransaction>>> _productStreams = {};
  final Map<String, RxList<StockTransaction>> _productTransactions = {};

  @override
  void onInit() {
    super.onInit();

    try {
      // Check if required controllers are available
      final BusinessController businessController = Get.find<BusinessController>();
      final ProfileController profileController = Get.find<ProfileController>();
      
      if (businessController.businessId.value.isEmpty) {
        print("BusinessController not ready, skipping transaction stream initialization");
        return;
      }

      // OPTION 1: Keep loading all transactions (current behavior)
      // Uncomment this if you want to keep the old behavior
      // _transactionSubscription = FirestoreDb().getTransactions().listen((data)
      // {
      //   transactions.value = data;
      //   searchTransactions.value = data;
      //   filteredtransactions.value = data;
      // });
      
      // OPTION 2: Use lazy loading (recommended for better performance)
      // Transactions are now loaded per-product using loadProductTransactions()
      print("TransactionController initialized with lazy loading mode");
    } catch (e) {
      print("Error binding transaction stream: $e");
      // Don't throw the error, just log it
    }
  }

  @override
  void onClose() {
    _transactionSubscription?.cancel();
    
    // Cancel all per-product streams
    for (var subscription in _productStreams.values) {
      subscription.cancel();
    }
    _productStreams.clear();
    _productTransactions.clear();
    
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
        newQuantity: 0,  // Include new field with default
        transactionType: '',
        transactionOrigin: '',
        timestamp: Timestamp.now(),
        userId: '',
        price: 0.0,
        // New optional fields can be null by default
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

  /// Get transactions for a specific product
  /// If lazy loading is enabled, this will return cached transactions
  List<StockTransaction> getTransactionsByProductId(String productId) {
    // If we have lazy-loaded transactions for this product, use them
    if (_productTransactions.containsKey(productId)) {
      return _productTransactions[productId]!.toList();
    }
    
    // Otherwise, filter from all transactions (fallback for old behavior)
    return transactions
        .where((transaction) => transaction.productId == productId)
        .toList();
  }
  
  /// NEW: Lazy load transactions for a specific product
  /// Call this when user opens transaction screen for a product
  void loadProductTransactions(String productId) {
    // If already loading this product, don't start another stream
    if (_productStreams.containsKey(productId)) {
      print('Transactions for product $productId already loaded');
      return;
    }
    
    print('🔄 Lazy loading transactions for product: $productId');
    
    try {
      final BusinessController businessController = Get.find<BusinessController>();
      final String? businessId = businessController.businessId.value;
      
      if (businessId == null || businessId.isEmpty) {
        print('❌ Cannot load transactions: businessId is empty');
        return;
      }
      
      // Create observable list for this product
      _productTransactions[productId] = <StockTransaction>[].obs;
      
      // Subscribe to Firestore stream for this specific product
      _productStreams[productId] = FirestoreDb()
          .getTransactionsByProduct(productId)
          .listen((data) {
        print('✅ Loaded ${data.length} transactions for product $productId');
        _productTransactions[productId]!.value = data;
      }, onError: (error) {
        print('❌ Error loading transactions for product $productId: $error');
      });
    } catch (e) {
      print('❌ Error setting up transaction stream for product $productId: $e');
    }
  }
  
  /// NEW: Unload transactions for a product to free memory
  /// Call this when user leaves transaction screen
  void unloadProductTransactions(String productId) {
    if (_productStreams.containsKey(productId)) {
      print('🗑️ Unloading transactions for product: $productId');
      _productStreams[productId]?.cancel();
      _productStreams.remove(productId);
      _productTransactions.remove(productId);
    }
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
  
  /// Verify if a product's transaction history matches its current quantity
  /// Returns a map with verification results
  Future<Map<String, dynamic>> verifyProductTransactions(String productId, double currentQuantity) async {
    try {
      // Get all transactions for this product
      final productTransactions = transactions
          .where((txn) => txn.productId == productId)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      if (productTransactions.isEmpty) {
        return {
          'isValid': false,
          'error': 'No transactions found for this product',
          'currentQuantity': currentQuantity,
          'calculatedQuantity': 0.0,
          'difference': currentQuantity,
        };
      }

      // Calculate expected quantity from transactions
      double calculatedQty = 0.0;
      
      for (var txn in productTransactions) {
        if (txn.transactionOrigin == 'Opening Stock') {
          // Opening stock sets the initial quantity
          calculatedQty = txn.quantity;
        } else if (txn.transactionType == 'addition') {
          calculatedQty += txn.quantity;
        } else if (txn.transactionType == 'removal') {
          calculatedQty -= txn.quantity;
        }
      }

      final difference = currentQuantity - calculatedQty;
      final isValid = difference.abs() < 0.01; // Allow small floating point differences

      return {
        'isValid': isValid,
        'currentQuantity': currentQuantity,
        'calculatedQuantity': calculatedQty,
        'difference': difference,
        'transactionCount': productTransactions.length,
        'lastTransaction': productTransactions.last.timestamp.toDate(),
      };
    } catch (e) {
      print('Error verifying transactions: $e');
      return {
        'isValid': false,
        'error': 'Error during verification: $e',
      };
    }
  }
  
  /// Get detailed transaction summary for a product
  Map<String, dynamic> getProductTransactionSummary(String productId) {
    final productTransactions = transactions
        .where((txn) => txn.productId == productId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (productTransactions.isEmpty) {
      return {
        'totalTransactions': 0,
        'totalAdditions': 0.0,
        'totalRemovals': 0.0,
        'netChange': 0.0,
      };
    }

    double totalAdditions = 0.0;
    double totalRemovals = 0.0;

    for (var txn in productTransactions) {
      if (txn.transactionType == 'addition') {
        totalAdditions += txn.quantity;
      } else if (txn.transactionType == 'removal') {
        totalRemovals += txn.quantity;
      }
    }

    return {
      'totalTransactions': productTransactions.length,
      'totalAdditions': totalAdditions,
      'totalRemovals': totalRemovals,
      'netChange': totalAdditions - totalRemovals,
      'firstTransaction': productTransactions.first.timestamp.toDate(),
      'lastTransaction': productTransactions.last.timestamp.toDate(),
    };
  }
}
