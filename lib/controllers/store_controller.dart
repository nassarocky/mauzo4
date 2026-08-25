import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/operation_error_message.dart';
import 'package:mauzo/utils/download_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product_model.dart';
import '../models/stock_transaction.dart';
import '../services/firestore_db.dart';
import 'business_controller.dart';

class StoreController extends GetxController {
  final BusinessController _businessController = Get.find();

  final products = <Product>[].obs;
  final searchProducts = <Product>[].obs;
  final filteredProducts = <Product>[].obs;
  final searchText = ''.obs;

  StreamSubscription<List<Product>>? _productSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _productSubscription = FirestoreDb().getProductInStore().listen((data) {
        products.value = data;
        searchProducts.value = data;
        filterProducts();
      });
    } catch (e) {
      print("Error initializing StoreController: $e");
    }
  }

  @override
  void onClose() {
    _productSubscription?.cancel();
    super.onClose();
  }

  Future<void> updateProductCount(Product product, double count) async {
    final String? business = _businessController.business['owner'];

    if (business == null) {
      print('Owner ID is null, cannot update product count.');
      errorSnackbar("Owner ID is null");
      return; // Return early if business ID is null
    }

    try {
      // Update product quantity
      final productRef = firestore
          .collection('store')
          .doc(business)
          .collection('userStore')
          .doc(product.id);

      // Await the product quantity update
      await productRef.update({'quantity': count});

      // Search for the updated product to reflect changes
      search(searchText.value);
    } catch (e) {
      print('Error updating product count: $e');
    }
  }

  Future<bool> updateStoreProductCount(Product product, double count) async {
    final String? business = _businessController.business['owner'];
    final String? businessshop = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot update store product count.');
      errorSnackbar("Owner ID is null");
      return false;
    }
    if (businessshop == null) {
      errorSnackbar("Business ID is null");
      return false;
    }

    try {
      final productRef = firestore
          .collection('store')
          .doc(business)
          .collection('userStore')
          .doc(product.id);
      final intendedDelta = count - product.quantity;
      final operationId = firestore.collection('transactions').doc().id;
      final transactionRef = firestore
            .collection('transactions')
            .doc(businessshop)
            .collection('usersTransactions')
            .doc(operationId);
      await firestore.runTransaction((fireTx) async {
        final snapshot = await fireTx.get(productRef);
        if (!snapshot.exists) {
          throw Exception('Store product no longer exists.');
        }
        final live = _quantityFrom(snapshot.data());
        final next = live + intendedDelta;
        if (next < 0) {
          throw Exception('Insufficient store stock.');
        }
        fireTx.update(productRef, {'quantity': next});
        if (intendedDelta == 0) return;
        final stockTransaction = StockTransaction(
          transactionId: transactionRef.id,
          productId: product.id,
          quantity: intendedDelta.abs(),
          delta: intendedDelta,
          previousQuantity: live,
          newQuantity: next,
          transactionType: intendedDelta >= 0 ? 'addition' : 'removal',
          transactionOrigin: intendedDelta >= 0
              ? 'Store Stock Added'
              : 'Store Stock Reduced',
          timestamp: Timestamp.now(),
          userId: businessshop,
          price: product.price,
          referenceId: product.id,
          referenceType: 'adjustment',
          operationId: operationId,
          inventoryLocation: 'store',
        );
        final history = stockTransaction.toMap();
        history['serverTimestamp'] = FieldValue.serverTimestamp();
        fireTx.set(transactionRef, history);
      });

      search(searchText.value);
      Get.snackbar(
        'Success',
        'Store product quantity updated.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      print('Error updating store product count: $e');
      errorSnackbar(operationErrorMessage(e));
      return false;
    }
  }

  int getProductQuantity(Product product) {
    return products.where((p) => p.id == product.id).length;
  }

  double _quantityFrom(Map<String, dynamic>? data) {
    final value = data?['quantity'];
    return value is num ? value.toDouble() : 0.0;
  }

  Map<String, dynamic> _transferHistory(
    StockTransaction stockTransaction, {
    required double delta,
  }) {
    return stockTransaction.toMap()..addAll({
      'delta': delta,
      'referenceId': stockTransaction.referenceId,
      'referenceType': 'transfer',
      'inventoryLocation': 'shop',
      'operationId': stockTransaction.transactionId,
      'serverTimestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> moveStockToShop(Product storeProduct, double quantity) async {
    final String? businessOwner = _businessController.business['owner'];
    final String? businessShop = _businessController.businessId.value;
    if (businessOwner == null || businessShop == null) {
      Get.snackbar(
        'Error',
        'Business ID is null',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return false;
    }
    if (quantity <= 0.0) {
      Get.snackbar(
        'Error',
        'Insufficient store stock to move.',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return false;
    }

    try {
      final shopRef = firestore
          .collection('products')
          .doc(businessShop)
          .collection('userProducts')
          .doc(storeProduct.id);
      final storeRef = firestore
          .collection('store')
          .doc(businessOwner)
          .collection('userStore')
          .doc(storeProduct.id);
      final historyRef = firestore
          .collection('transactions')
          .doc(businessShop)
          .collection('usersTransactions')
          .doc();
      final timestamp = Timestamp.now();

      await firestore.runTransaction((fireTx) async {
        final snapshots = await Future.wait([
          fireTx.get(shopRef),
          fireTx.get(storeRef),
        ]);
        final shopSnapshot = snapshots[0];
        final storeSnapshot = snapshots[1];
        if (!shopSnapshot.exists) {
          throw Exception(
            'Product not in ${_businessController.business['name']}',
          );
        }
        if (!storeSnapshot.exists) {
          throw Exception('Product does not exist in store.');
        }
        final shopQuantity = _quantityFrom(shopSnapshot.data());
        final storeQuantity = _quantityFrom(storeSnapshot.data());
        if (storeQuantity < quantity) {
          throw Exception('Insufficient store stock to move.');
        }
        final nextShopQuantity = shopQuantity + quantity;
        final nextStoreQuantity = storeQuantity - quantity;
        fireTx.update(shopRef, {'quantity': nextShopQuantity});
        fireTx.update(storeRef, {'quantity': nextStoreQuantity});
        final history = StockTransaction(
          transactionId: historyRef.id,
          productId: storeProduct.id,
          quantity: quantity,
          previousQuantity: shopQuantity,
          newQuantity: nextShopQuantity,
          transactionType: 'addition',
          transactionOrigin: 'Added From Store',
          timestamp: timestamp,
          userId: businessOwner,
          price: storeProduct.price,
          referenceId: historyRef.id,
          referenceType: 'transfer',
          totalValue: quantity * storeProduct.price,
        );
        fireTx.set(historyRef, _transferHistory(history, delta: quantity));
      });

      Get.snackbar(
        'Stock Moved',
        '$quantity items moved from store to shop.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      print('Error moving stock and recording transaction: $e');
      Get.snackbar(
        'Error',
        operationErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return false;
    }
  }

  Future<bool> moveStockToStore(Product shopProduct, double quantity) async {
    final String? businessOwner = _businessController.business['owner'];
    final String? businessShop = _businessController.businessId.value;
    if (businessOwner == null || businessShop == null) {
      Get.snackbar(
        'Error',
        'Business ID is null',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return false;
    }
    if (quantity <= 0.0) {
      Get.snackbar(
        'Error',
        'Insufficient shop stock to move.',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return false;
    }

    try {
      final shopRef = firestore
          .collection('products')
          .doc(businessShop)
          .collection('userProducts')
          .doc(shopProduct.id);
      final storeRef = firestore
          .collection('store')
          .doc(businessOwner)
          .collection('userStore')
          .doc(shopProduct.id);
      final historyRef = firestore
          .collection('transactions')
          .doc(businessShop)
          .collection('usersTransactions')
          .doc();
      final timestamp = Timestamp.now();

      await firestore.runTransaction((fireTx) async {
        final snapshots = await Future.wait([
          fireTx.get(shopRef),
          fireTx.get(storeRef),
        ]);
        final shopSnapshot = snapshots[0];
        final storeSnapshot = snapshots[1];
        if (!shopSnapshot.exists) {
          throw Exception('Product does not exist in shop.');
        }
        final shopQuantity = _quantityFrom(shopSnapshot.data());
        if (shopQuantity < quantity) {
          throw Exception('Insufficient shop stock to move.');
        }
        final storeQuantity = _quantityFrom(storeSnapshot.data());
        final nextShopQuantity = shopQuantity - quantity;
        final nextStoreQuantity = storeQuantity + quantity;
        fireTx.update(shopRef, {'quantity': nextShopQuantity});
        if (storeSnapshot.exists) {
          fireTx.update(storeRef, {'quantity': nextStoreQuantity});
        } else {
          final storeData = Map<String, dynamic>.from(shopSnapshot.data()!);
          storeData['quantity'] = nextStoreQuantity;
          fireTx.set(storeRef, storeData);
        }
        final history = StockTransaction(
          transactionId: historyRef.id,
          productId: shopProduct.id,
          quantity: quantity,
          previousQuantity: shopQuantity,
          newQuantity: nextShopQuantity,
          transactionType: 'removal',
          transactionOrigin: 'Moved To Store',
          timestamp: timestamp,
          userId: businessOwner,
          price: shopProduct.price,
          referenceId: historyRef.id,
          referenceType: 'transfer',
          totalValue: quantity * shopProduct.price,
        );
        fireTx.set(historyRef, _transferHistory(history, delta: -quantity));
      });

      Get.snackbar(
        'Stock Moved',
        '$quantity items moved from shop to store.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return true;
    } catch (e) {
      print('Error moving stock to store: $e');
      Get.snackbar(
        'Error',
        operationErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return false;
    }
  }

  Product getProduct(String productId) {
    return products.firstWhere(
      (product) => product.id == productId,
      orElse: () => Product(
        owner: '',
        id: '',
        name: '',
        price: 0,
        quantity: 0,
        discount: 0,
        total: 0,
        code: '',
        image: '',
      ),
    );
  }

  double calculateTotalSales() {
    double total = 0;
    for (Product product in products) {
      if (product.total != null &&
          product.quantity != null &&
          product.price != null) {
        // Only process products with all necessary fields (A, B, and C)
        double result = (product.total! - product.quantity!) * product.price!;
        total += result;
      } else {
        // Handle products with missing fields (optional)
        // You can throw an exception, log a warning, or assign a default value here
      }
    }
    return total;
  }

  double calculateTotalStock() {
    double total = 0;
    for (Product product in products) {
      if (product.total != null && product.price != null) {
        // Only process products with all necessary fields (A, B, and C)
        double result = (product.quantity!) * product.price!;
        total += result;
      } else {
        // Handle products with missing fields (optional)
        // You can throw an exception, log a warning, or assign a default value here
      }
    }
    return total;
  }

  double calculateTotalStockBuying() {
    double total = 0;
    for (Product product in products) {
      if (product.quantity != null && product.buyingPrice != null) {
        // Only process products with all necessary fields (A, B, and C)
        double result = (product.quantity!) * product.buyingPrice!;
        total += result;
      } else {
        // Handle products with missing fields (optional)
        // You can throw an exception, log a warning, or assign a default value here
      }
    }
    return total;
  }

  Product getProductByCode(String code) {
    return products.firstWhere(
      (product) => product.code == code,
      orElse: () => Product(
        owner: '',
        id: '',
        name: '',
        price: 0,
        discount: 0,
        quantity: 0,
        total: 0,
        code: '',
        image: '',
      ),
    );
  }

  final filterCategories = <String>[].obs;

  /// Same pattern as [ProductController]: search text → expire date → categories.
  DateTime? selectedDate;

  void resetProducts() {
    filteredProducts.value = products;
  }

  void filterProducts() {
    filteredProducts.value = products;

    if (searchText.value.isNotEmpty) {
      filteredProducts.value = products
          .where(
            (product) => product.name.toLowerCase().contains(
              searchText.value.toLowerCase(),
            ),
          )
          .toList();
    }

    if (selectedDate != null) {
      filteredProducts.value = filteredProducts.where((product) {
        return product.expireDate?.isBefore(selectedDate!) ?? false;
      }).toList();
    }

    if (filterCategories.isNotEmpty) {
      filteredProducts.value = filteredProducts.where((product) {
        return filterCategories.contains(product.category);
      }).toList();
    }
  }

  void filterProductsByExpireDate(DateTime filterDate) {
    selectedDate = filterDate;
  }

  void clearSelectedDateRange() {
    selectedDate = null;
  }

  void setFilterCategories(List<String> categories) {
    filterCategories.value = categories;
    filterProducts();
  }

  void search(String searchValue) {
    searchText.value = searchValue;
    searchProducts.value = products
        .where(
          (product) =>
              product.name.toLowerCase().contains(searchValue.toLowerCase()),
        )
        .toList();
    filterProducts();
  }

  final selectedCategory = 'No category'.obs;
  void setCategory(String updatedCategory) {
    selectedCategory.value = updatedCategory;
  }

  final selectedUnit = 'No unit'.obs;
  void setUnit(String updatedUnit) {
    selectedUnit.value = updatedUnit;
  }

  final selectedManufacturer = 'No manufacturer'.obs;
  void setManufacturer(String updatedManufacturer) {
    selectedManufacturer.value = updatedManufacturer;
  }

  final selectedLocation = 'No location'.obs;
  void setLocation(String updatedLocation) {
    selectedLocation.value = updatedLocation;
  }

  //for mobile
  Future<void> generateExcelFromProductsInstore() async {
    // Create a new Excel document
    var excel = Excel.createExcel();

    // Get the default sheet
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheetObject = excel[defaultSheet];

    // Add the business name and report title as the first row (heading)
    String businessName =
        _businessController.business['name'] ?? 'Business Name';
    String reportTitle = "Product Report";

    sheetObject.appendRow([businessName]);
    sheetObject.appendRow([reportTitle]);

    // Add multiple empty rows for better spacing
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);

    // Define header row with background color (matches import template)
    final headerRow = [
      "Name",
      "Quantity",
      "Category",
      "Manufacturer",
      "Location",
      "Price",
      "Buying Price",
      "Code",
      "Unit",
      "Understock",
      "Item Type",
    ];

    // Apply a background color to the header row
    CellStyle headerStyle = CellStyle(
      backgroundColorHex: '#FFC107', // Amber color for the header
      bold: true,
    );

    // Add header row with styling
    var headerRowIndex = sheetObject.maxRows;
    sheetObject.appendRow(headerRow);
    sheetObject.row(headerRowIndex).forEach((cell) {
      cell?.cellStyle = headerStyle;
    });

    // Iterate through the list of products and add each product as a row in the Excel sheet
    for (Product product in filteredProducts) {
      // Ensure quantity is non-null and default to 0 if it's null
      double quantity = product.quantity ?? 0.0;

      // Add a row to the sheet with product details (matches import template)
      sheetObject.appendRow([
        product.name,
        quantity,
        product.category,
        product.manufacturer,
        product.location,
        product.price,
        product.buyingPrice,
        product.code ?? '',
        product.reserveString1.isNotEmpty ? product.reserveString1 : 'unit',
        product.understock ?? 0,
        product.itemType ?? 'product',
      ]);
    }

    // Optionally, calculate the total value of all products and add it at the bottom
    double totalValue = filteredProducts.fold(0, (sum, product) {
      double quantity = product.quantity ?? 0.0;
      return sum + (product.price * quantity);
    });

    // Add an empty row for spacing before the Total Value row
    sheetObject.appendRow([]);

    // Add the Total Value row at the bottom of the Price column
    sheetObject.appendRow(['', '', 'Total Value:', totalValue, '']);

    // Apply a bold style to the Total Value row
    var totalValueRowIndex = sheetObject.maxRows - 1;
    sheetObject.row(totalValueRowIndex).forEach((cell) {
      cell?.cellStyle = CellStyle(bold: true);
    });

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      errorSnackbar('Failed to generate Excel file'.tr);
      return;
    }

    final fileName = 'Store_Report.xlsx';

    if (DownloadHelper.isWeb) {
      // Web: Direct download using blob
      DownloadHelper.downloadFileWeb(Uint8List.fromList(fileBytes), fileName);
      successSnackbar('Report downloaded successfully!');
    } else {
      // Mobile: Save and share the file
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/$fileName";
      final file = File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      final result = await Share.shareXFiles([
        XFile(filePath),
      ], text: 'Store Report');

      if (result.status == ShareResultStatus.success) {
        print('Thank you for sharing the report!');
      } else if (result.status == ShareResultStatus.dismissed) {
        print('Share dismissed');
      }
    }
  }

  //for web
  /*
  Future<void> generateExcelFromProductsInstore() async {
    // Create a new Excel document
    var excel = Excel.createExcel();

    // Get the default sheet
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheetObject = excel[defaultSheet];

    // Add the business name and report title as the first row (heading)
    String businessName = _businessController.business['name'] ?? 'Business Name';
    String reportTitle = "Product Report";

    sheetObject.appendRow([businessName]);
    sheetObject.appendRow([reportTitle]);

    // Add multiple empty rows for better spacing
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);

    // Define header row with background color (matches import template)
    final headerRow = [
      "Name", "Quantity", "Category", "Manufacturer", "Location", "Price", "Buying Price", "Code", "Unit", "Understock", "Item Type"
    ];

    // Apply a background color to the header row
    CellStyle headerStyle = CellStyle(
      backgroundColorHex: '#FFC107', // Amber color for the header
      bold: true,
    );

    // Add header row with styling
    var headerRowIndex = sheetObject.maxRows;
    sheetObject.appendRow(headerRow);
    sheetObject.row(headerRowIndex).forEach((cell) {
      cell?.cellStyle = headerStyle;
    });

    // Iterate through the list of products and add each product as a row in the Excel sheet
    for (Product product in filteredProducts) {
      // Ensure quantity is non-null and default to 0 if it's null
      double quantity = product.quantity ?? 0.0;

      // Add a row to the sheet with product details (matches import template)
      sheetObject.appendRow([
        product.name,
        quantity,
        product.category,
        product.manufacturer,
        product.location,
        product.price,
        product.buyingPrice,
        product.code ?? '',
        product.reserveString1.isNotEmpty ? product.reserveString1 : 'unit',
        product.understock ?? 0,
        product.itemType ?? 'product',
      ]);
    }

    // Optionally, calculate the total value of all products and add it at the bottom
    double totalValue = filteredProducts.fold(0, (sum, product) {
      double quantity = product.quantity ?? 0.0;
      return sum + (product.price * quantity);
    });

    // Add an empty row for spacing before the Total Value row
    sheetObject.appendRow([]);

    // Add the Total Value row at the bottom of the Price column
    sheetObject.appendRow([
      '', '', 'Total Value:', totalValue, ''
    ]);

    // Apply a bold style to the Total Value row
    var totalValueRowIndex = sheetObject.maxRows - 1;
    sheetObject.row(totalValueRowIndex).forEach((cell) {
      cell?.cellStyle = CellStyle(
        bold: true,
      );
    });

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      // Download the file
      DownloadHelper.downloadFileWeb(Uint8List.fromList(fileBytes), 'Store_Report.xlsx');
    }
  }
*/

  var isUnderstockFilterActive = false.obs; // Tracking the filter state

  // Method to toggle understock filtering
  void toggleUnderstockFilter() {
    // Find products that are understocked
    var understockedProducts = products
        .where(
          (product) =>
              product.quantity != null &&
              product.quantity! < product.understock!,
        )
        .toList();

    if (understockedProducts.isEmpty) {
      // If there are no understocked products, display a notification
      Get.snackbar(
        'No Understock Products'.tr,
        'There are no products that are currently understock.'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 3),
        backgroundColor: Colors.black, // Set the background color to black
        colorText: Colors.white, // Set the text color to white
        snackStyle: SnackStyle
            .FLOATING, // Optional: makes the snackbar float above the content
        margin: EdgeInsets.all(16), // Optional: adds margin around the snackbar
      );
    } else {
      if (isUnderstockFilterActive.value) {
        // If the filter is active, reset to show all products
        filteredProducts.value = products;
      } else {
        // If the filter is inactive, apply the understock filter
        filteredProducts.value = understockedProducts;
      }

      // Toggle the state
      isUnderstockFilterActive.value = !isUnderstockFilterActive.value;
    }
  }

  void clearStore() {
    products.value.clear();
    filteredProducts.value.clear();
  }

  // Bulk movement methods
  Future<void> moveAllStockToStore() async {
    final String? businessOwner = _businessController.business['owner'];
    final String? businessShop = _businessController.businessId.value;
    if (businessOwner == null || businessShop == null) {
      Get.snackbar(
        'Error',
        'Business ID is null',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return;
    }

    try {
      final query = firestore
          .collection('products')
          .doc(businessShop)
          .collection('userProducts')
          .where('quantity', isGreaterThan: 0)
          .limit(100);
      int movedProducts = 0;

      while (true) {
        final page = await query.get();
        if (page.docs.isEmpty) break;
        for (final doc in page.docs) {
          final storeRef = firestore
              .collection('store')
              .doc(businessOwner)
              .collection('userStore')
              .doc(doc.id);
          final historyRef = firestore
              .collection('transactions')
              .doc(businessShop)
              .collection('usersTransactions')
              .doc();
          final timestamp = Timestamp.now();
          final moved = await firestore.runTransaction((fireTx) async {
            final snapshots = await Future.wait([
              fireTx.get(doc.reference),
              fireTx.get(storeRef),
            ]);
            final shopSnapshot = snapshots[0];
            final storeSnapshot = snapshots[1];
            if (!shopSnapshot.exists) return false;
            final quantity = _quantityFrom(shopSnapshot.data());
            if (quantity <= 0) return false;
            final storeQuantity = _quantityFrom(storeSnapshot.data());
            final nextStoreQuantity = storeQuantity + quantity;
            fireTx.update(doc.reference, {'quantity': 0.0});
            if (storeSnapshot.exists) {
              fireTx.update(storeRef, {'quantity': nextStoreQuantity});
            } else {
              final storeData = Map<String, dynamic>.from(shopSnapshot.data()!);
              storeData['quantity'] = nextStoreQuantity;
              fireTx.set(storeRef, storeData);
            }
            final rawPrice = shopSnapshot.data()?['price'];
            final price = rawPrice is num ? rawPrice.toDouble() : 0.0;
            final history = StockTransaction(
              transactionId: historyRef.id,
              productId: doc.id,
              quantity: quantity,
              previousQuantity: quantity,
              newQuantity: 0.0,
              transactionType: 'removal',
              transactionOrigin: 'Bulk Move To Store',
              timestamp: timestamp,
              userId: businessOwner,
              price: price,
              referenceId: historyRef.id,
              referenceType: 'transfer',
              totalValue: quantity * price,
            );
            fireTx.set(historyRef, _transferHistory(history, delta: -quantity));
            return true;
          });
          if (moved) movedProducts++;
        }
      }

      Get.snackbar(
        'Bulk Move Complete',
        '$movedProducts products moved to store.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error in bulk move to store: $e');
      Get.snackbar(
        'Error',
        operationErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
    }
  }

  Future<void> moveAllStockToShop() async {
    final String? businessOwner = _businessController.business['owner'];
    final String? businessShop = _businessController.businessId.value;
    if (businessOwner == null || businessShop == null) {
      Get.snackbar(
        'Error',
        'Business ID is null',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return;
    }

    try {
      final query = firestore
          .collection('store')
          .doc(businessOwner)
          .collection('userStore')
          .where('quantity', isGreaterThan: 0)
          .limit(100);
      int movedProducts = 0;

      while (true) {
        final page = await query.get();
        if (page.docs.isEmpty) break;
        for (final doc in page.docs) {
          final shopRef = firestore
              .collection('products')
              .doc(businessShop)
              .collection('userProducts')
              .doc(doc.id);
          final historyRef = firestore
              .collection('transactions')
              .doc(businessShop)
              .collection('usersTransactions')
              .doc();
          final timestamp = Timestamp.now();
          final moved = await firestore.runTransaction((fireTx) async {
            final snapshots = await Future.wait([
              fireTx.get(doc.reference),
              fireTx.get(shopRef),
            ]);
            final storeSnapshot = snapshots[0];
            final shopSnapshot = snapshots[1];
            if (!storeSnapshot.exists) return false;
            final quantity = _quantityFrom(storeSnapshot.data());
            if (quantity <= 0) return false;
            final shopQuantity = _quantityFrom(shopSnapshot.data());
            final nextShopQuantity = shopQuantity + quantity;
            fireTx.update(doc.reference, {'quantity': 0.0});
            if (shopSnapshot.exists) {
              fireTx.update(shopRef, {'quantity': nextShopQuantity});
            } else {
              final shopData = Map<String, dynamic>.from(storeSnapshot.data()!);
              shopData['quantity'] = nextShopQuantity;
              fireTx.set(shopRef, shopData);
            }
            final rawPrice = storeSnapshot.data()?['price'];
            final price = rawPrice is num ? rawPrice.toDouble() : 0.0;
            final history = StockTransaction(
              transactionId: historyRef.id,
              productId: doc.id,
              quantity: quantity,
              previousQuantity: shopQuantity,
              newQuantity: nextShopQuantity,
              transactionType: 'addition',
              transactionOrigin: 'Bulk Move From Store',
              timestamp: timestamp,
              userId: businessOwner,
              price: price,
              referenceId: historyRef.id,
              referenceType: 'transfer',
              totalValue: quantity * price,
            );
            fireTx.set(historyRef, _transferHistory(history, delta: quantity));
            return true;
          });
          if (moved) movedProducts++;
        }
      }

      Get.snackbar(
        'Bulk Move Complete',
        '$movedProducts products moved to shop.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      print('Error in bulk move to shop: $e');
      Get.snackbar(
        'Error',
        operationErrorMessage(e),
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
    }
  }
}
