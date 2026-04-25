import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cross_file/cross_file.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/download_helper.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product_model.dart';
import '../models/stock_transaction.dart';
import '../services/firestore_db.dart';
import '../constants/transaction_constants.dart';
import 'business_controller.dart';
class ProductController extends GetxController {
  final ProfileController _profileController=Get.find();
  final BusinessController _businessController = Get.find();

// Declare a variable to store the number of products
  final productCount = 0.obs;
// Add at the top of your class
  StreamSubscription<List<Product>>? _productSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      // Use .listen instead of .bindStream
      _productSubscription = FirestoreDb().getProducts().listen((data) {
        products.value = data;
        productCount.value = data.length;
        searchProducts.value = data;
        filteredProducts.value = data;
      });
    } catch (e) {
      print("Error initializing ProductController: $e");
    }
  }

  //for mobile app
  // Generate a blank Excel template for bulk import
  Future<void> generateProductTemplate() async {
    var excel = Excel.createExcel();
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheet = excel[defaultSheet];

    // Header row (case-insensitive matching in importer)
    final headers = [
      'Name',
      'Quantity',
      'Category',
      'Manufacturer',
      'Location',
      'Price',
      'Wholesale Price',
      'Buying Price',
      'Code',
      'Unit',
      'Understock',
      'Item Type', // product | service
    ];

    sheet.appendRow(headers);

    // Example row (optional)
    sheet.appendRow([
      'Example Product',
      10,
      'General',
      'Brand X',
      'Shelf A',
      5000,
      4500,
      3500,
      'SKU-001',
      'unit',
      10,
      'product',
    ]);

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      errorSnackbar('Failed to generate Excel file'.tr);
      return;
    }

    final fileName = 'Product_Import_Template.xlsx';

    if (DownloadHelper.isWeb) {
      // Web: Direct download using blob
      DownloadHelper.downloadFileWeb(Uint8List.fromList(fileBytes), fileName);
      successSnackbar('Template downloaded successfully!');
    } else {
      // Mobile: Save the file to the device and share
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/$fileName";
      final file = File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Product Import Template',
      );

      if (result.status == ShareResultStatus.success) {
        print('Template shared successfully!');
      } else if (result.status == ShareResultStatus.dismissed) {
        print('Share dismissed');
      }
    }
  }

  //for web
  /*
  // Generate a blank Excel template for bulk import
  Future<void> generateProductTemplate() async {
    var excel = Excel.createExcel();
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheet = excel[defaultSheet];

    // Header row (case-insensitive matching in importer)
    final headers = [
      'Name',
      'Quantity',
      'Category',
      'Manufacturer',
      'Location',
      'Price',
      'Buying Price',
      'Code',
      'Unit',
      'Understock',
      'Item Type', // product | service
    ];

    sheet.appendRow(headers);

    // Example row (optional)
    sheet.appendRow([
      'Example Product',
      10,
      'General',
      'Brand X',
      'Shelf A',
      5000,
      3500,
      'SKU-001',
      'unit',
      10,
      'product',
    ]);

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      errorSnackbar('Failed to generate Excel file'.tr);
      return;
    }

    if (DownloadHelper.isWeb) {
      // Web: Download using blob
      DownloadHelper.downloadFileWeb(Uint8List.fromList(fileBytes), 'Product_Import_Template.xlsx');
    } else {
      // Mobile: This path won't work on web, needs separate implementation
      errorSnackbar('Download not supported on mobile yet. Please use the app'.tr);
    }
  }
  */

  // Import products from Excel bytes
  // Returns a summary map: {'imported': x, 'skipped': y}
  Future<Map<String, int>> importProductsFromExcelBytes(Uint8List bytes) async {
    final String? businessId = _businessController.business['id'];
    if (businessId == null || businessId.isEmpty) {
      errorSnackbar('Business ID is null');
      return {'imported': 0, 'skipped': 0};
    }

    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      errorSnackbar('Excel file has no sheets');
      return {'imported': 0, 'skipped': 0};
    }

    // Use the first non-empty sheet
    Sheet sheet = excel.tables.values.first;
    if (sheet.maxRows < 2) {
      errorSnackbar('Excel has no data rows');
      return {'imported': 0, 'skipped': 0};
    }

    // Build header map (lowercased)
    final headerRow = sheet.row(0);
    final Map<String, int> colIndex = {};
    for (int i = 0; i < headerRow.length; i++) {
      final v = headerRow[i]?.value?.toString().trim().toLowerCase();
      if (v != null && v.isNotEmpty) colIndex[v] = i;
    }

    // Helper to get cell value by logical name
    String? sVal(List<Data?> row, String name) {
      final idx = colIndex[name];
      if (idx == null) return null;
      final v = row.length > idx ? row[idx]?.value : null;
      return v?.toString().trim();
    }

    double dVal(List<Data?> row, String name, {double def = 0.0}) {
      final idx = colIndex[name];
      if (idx == null) return def;
      final v = row.length > idx ? row[idx]?.value : null;
      if (v == null) return def;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().replaceAll(',', '')) ?? def;
    }

    int iVal(List<Data?> row, String name, {int def = 0}) {
      return dVal(row, name, def: def.toDouble()).toInt();
    }

    final productsCol = firestore
        .collection('products')
        .doc(businessId)
        .collection('userProducts');

    final transactionsCol = firestore
        .collection('transactions')
        .doc(businessId)
        .collection('usersTransactions');

    int imported = 0;
    int skipped = 0;

    // Collect categories and units to add to business once
    final Set<String> categoriesToAdd = {};
    final Set<String> unitsToAdd = {};

    // Batched writes (limit ~400 ops to be safe because we may also add a transaction)
    WriteBatch batch = firestore.batch();
    int ops = 0;

    Future<void> commitIfNeeded() async {
      if (ops >= 400) {
        await batch.commit();
        batch = firestore.batch();
        ops = 0;
      }
    }

    for (int r = 1; r < sheet.maxRows; r++) {
      final row = sheet.row(r);
      final name = sVal(row, 'name');
      if (name == null || name.isEmpty) {
        skipped++;
        continue;
      }

      final price = dVal(row, 'price');
      if (price <= 0) {
        skipped++;
        continue;
      }

      final quantity = dVal(row, 'quantity');
      final buyingPrice = dVal(row, 'buying price');
      final wholesaleRaw = dVal(row, 'wholesale price');
      final wholesalePrice =
          wholesaleRaw > 0 ? wholesaleRaw : price;
      if (wholesalePrice > price) {
        skipped++;
        continue;
      }
      if (buyingPrice >= wholesalePrice) {
        skipped++;
        continue;
      }
      final category = sVal(row, 'category') ?? '';
      final manufacturer = sVal(row, 'manufacturer') ?? '';
      final location = sVal(row, 'location') ?? '';
      final code = sVal(row, 'code') ?? '';
      final unit = (sVal(row, 'unit') ?? 'unit').toLowerCase();
      final understock = iVal(row, 'understock', def: 10);
      final itemType = (sVal(row, 'item type') ?? 'product').toLowerCase();

      final docRef = productsCol.doc();

      final isService = itemType == 'service';
      final double finalQty = isService ? 1.0 : (quantity > 0 ? quantity : 0.0);

      final productData = {
        'id': docRef.id,
        'owner': businessId,
        'businessId': businessId,
        'manufacturer': manufacturer,
        'name': name,
        'details': '',
        'location': location,
        'buyingPrice': buyingPrice,
        'understock': understock,
        'discount': 0.0,
        'code': code,
        'price': price,
        'wholesalePrice': wholesalePrice,
        'quantity': finalQty,
        'category': category,
        'image': '',
        'storeQuantity': 0,
        'reserveString1': unit, // unit
        'reserveString2': '',
        'reserveDouble1': 0.0,
        'reserveDouble2': 0.0,
        'reserveList1': [],
        'reserveList2': [],
        'expireDate': null,
        'itemType': isService ? 'service' : 'product',
      };

      batch.set(docRef, productData);
      ops++;

      // Opening stock transaction for non-services with qty > 0
      if (!isService && finalQty > 0) {
        final tRef = transactionsCol.doc();
        final txn = {
          'transactionId': tRef.id,
          'productId': docRef.id,
          'quantity': finalQty,
          'previousQuantity': 0,
          'transactionType': 'addition',
          'transactionOrigin': 'Opening Stock',
          'timestamp': Timestamp.now(),
          'userId': businessId,
          'price': price,
        };
        batch.set(tRef, txn);
        ops++;
      }

      if (category.isNotEmpty) categoriesToAdd.add(category);
      if (unit.isNotEmpty) unitsToAdd.add(unit);

      imported++;
      await commitIfNeeded();
    }

    // Commit remaining products/transactions
    await batch.commit();

    // Update business categories and units
    if (categoriesToAdd.isNotEmpty || unitsToAdd.isNotEmpty) {
      await firestore.collection('businesses').doc(businessId).update({
        if (categoriesToAdd.isNotEmpty) 'categories': FieldValue.arrayUnion(categoriesToAdd.toList()),
        if (unitsToAdd.isNotEmpty) 'additionalList1': FieldValue.arrayUnion(unitsToAdd.toList()),
      });
    }

    successSnackbar('Imported $imported products. Skipped $skipped rows.');
    return {'imported': imported, 'skipped': skipped};
  }

  @override
  void onClose() {
    _productSubscription?.cancel();
    super.onClose();
  }


// * CRUD
  final products = <Product>[].obs;

  Future<void> updateInitialTransaction(double count, String id,double price) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot update product count.');
      errorSnackbar("Owner ID is null");
      return;
    }
    try {
      // Log stock transaction
      final transactionRef = firestore
          .collection('transactions')
          .doc(business)
          .collection('usersTransactions')
          .doc();

      final stockTransaction = StockTransaction(
          transactionId: transactionRef.id,
          productId: id,
          quantity: count,
          previousQuantity: 0,
          newQuantity: count,  // NEW: Record final quantity
          transactionType: TransactionTypes.addition,
          transactionOrigin: TransactionOrigins.openingStock,
          timestamp: Timestamp.now(),
          userId: business,
          price: price,
          referenceType: TransactionReferenceTypes.manual,  // NEW
          employeeName: _profileController.user['name'],     // NEW
          notes: 'Initial stock entry',                      // NEW
          totalValue: count * price,                         // NEW
      );

      transactionRef.set(stockTransaction.toMap());

    } catch (e) {
      print('Error updating product count and recording transaction: $e');

    }
  }

  Future<void> updateProductCount(
    Product product,
    double count,
    String type, {
    String? referenceId,
    String? referenceType,
    String? notes,
  }) async {
    // Skip quantity update for services
    if (product.itemType == 'service') return;
    final String? business = _businessController.business['id'];

    if (business == null) {
      print('Owner ID is null, cannot update product count.');
      errorSnackbar("Owner ID is null");
      return; // Return early if business ID is null
    }

    try {
      // ✅ USE BATCH for atomic writes (works great offline!)
      final batch = firestore.batch();
      
      final productRef = firestore
          .collection('products')
          .doc(business)
          .collection('userProducts')
          .doc(product.id);

      final currentQuantity = product.quantity ?? 0.0;
      final quantityChange = (count - currentQuantity).abs();

      // Add product quantity update to batch
      batch.update(productRef, {'quantity': count});

      // Create transaction reference
      final transactionRef = firestore
          .collection('transactions')
          .doc(business)
          .collection('usersTransactions')
          .doc();

      final stockTransaction = StockTransaction(
          transactionId: transactionRef.id,
          productId: product.id,
          quantity: quantityChange,
          previousQuantity: currentQuantity,
          newQuantity: count,
          transactionType: count < currentQuantity ? TransactionTypes.removal : TransactionTypes.addition,
          transactionOrigin: type,
          timestamp: Timestamp.now(),
          userId: business,
          price: product.price,
          referenceId: referenceId,
          referenceType: referenceType,
          notes: notes,
          employeeName: _profileController.user['name'],
          totalValue: quantityChange * product.price,
      );

      // Add transaction to batch
      batch.set(transactionRef, stockTransaction.toMap());

      // ✅ Commit batch - single await for both operations
      await batch.commit();

      // Update UI after successful commit
      search(searchText.value);
    } catch (e) {
      print('Error updating product count and recording transaction: $e');
      rethrow;
    }
  }

  Future<void> updateStoreCount(Product product, int count, String type) async {
    final String? business = _businessController.business['id'];

    if (business == null) {
      print('Owner ID is null, cannot update product count.');
      errorSnackbar("Owner ID is null");
      return; // Return early if business ID is null
    }

    try {
      // Update product quantity
      final productRef = firestore
          .collection('products')
          .doc(business)
          .collection('userProducts')
          .doc(product.id);

      productRef.update({'storeQuantity': count});


      search(searchText.value);
    } catch (e) {
      print('Error updating product count and recording transaction: $e');
    }
  }

  void updateTotalCount(Product product, int count) async {
    final String? business = _businessController.business['id'];

    if (business == null) {
      print('Owner ID is null, cannot update total count.');
      return;
    }
    try {
      await firestore
          .collection('products')
          .doc(business)
          .collection('userProducts')
          .doc(product.id)
          .update({
        'total': count,
      });
      search(searchText.value);
      // ignore: empty_catches
    } catch (e) {}
  }

  void deleteProduct(Product product) async {

    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot delete product.');
      return;
    }

    try {
      await firestore
          .collection('products')
          .doc(business)
          .collection('userProducts')
          .doc(product.id)
          .delete();
      successSnackbar('${product.name} ${'deleted'.tr}');
    } catch (e) {
      errorSnackbar('error'.tr);
    }
  }

  Future<void> resetProductQuantities() async {

    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot delete product.');
      return;
    }
    final collection = firestore.collection('products').doc(business).collection('userProducts');

    try {
      // Get all documents in a single request
      final querySnapshot = await collection.get();

      // Loop through documents, but update each individually (avoid batch)
      for (final document in querySnapshot.docs) {
        final data = document.data();

        if (data?.containsKey('quantity') == true) {
          final quantity = data?['quantity'];

          // Update the document directly (no batch)
          await document.reference.update({'total': quantity});
        } else {
          // Handle documents without "quantity" (optional)
        }
      }
      print('Product quantities successfully updated.');
    } on FirebaseException catch (e) {
      // Handle potential Firestore errors (optional)
      print('Error updating product quantities: ${e.message}');
    }
  }

  int getProductQuantity(Product product) {
    return products.where((p) => p.id == product.id).length;
  }


  Product getProduct(String productId) {
    return products.firstWhere(
          (product) => product.id == productId,
      orElse: () => Product(
        owner: '',
        id: '',
        name: '',
        storeId:'',
        price: 0,
        discount: 0,
        quantity: 0,
        total: 0,
        code: '',
        image: '',
      ),
    );
  }

  double calculateTotalProducts() {
    double total = 0;
    for (Product product in products) {
      if (product.total != null && product.quantity != null && product.price != null) {
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
      if (product.quantity != null  && product.price != null) {
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
      if (product.quantity != null  && product.buyingPrice != null) {
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
        storeId:'',
        price: 0,
        discount: 0,
        quantity: 0,
        total: 0,
        code: '',
        image: '',
      ),
    );
  }

  // * FILTERING
  DateTime? selectedDate;
  final searchProducts = <Product>[].obs;
  final searchText = ''.obs;
  final filteredProducts = <Product>[].obs;
  final filterCategories = <String>[].obs;
  void resetProducts(){
    filteredProducts.value = products;
  }
  void filterProducts() {
    // Reset the filteredProducts list to include all products initially
    filteredProducts.value = products;

    // Filter by search text if it's not empty
    if (searchText.value.isNotEmpty) {
      filteredProducts.value = products
          .where((product) => product.name
          .toLowerCase()
          .contains(searchText.value.toLowerCase()))
          .toList();
    }

    // Filter by selected date if it's not null
    if (selectedDate != null) {
      filteredProducts.value = filteredProducts.where((product) {
        return product.expireDate?.isBefore(selectedDate!) ?? false;
      }).toList();
    }

    // Filter by categories if any are selected
    if (filterCategories.isNotEmpty) {
      filteredProducts.value = filteredProducts.where((product) {
        return filterCategories.contains(product.category);
      }).toList();
    }
  }

  void filterProductsByExpireDate(DateTime filterDate) {
    selectedDate= filterDate;
  }

  void clearSelectedDateRange() {
    selectedDate = null;
  }
void clearProducts(){
    products.value.clear();
    filteredProducts.value.clear();
    filterCategories.value.clear();
    searchProducts.value.clear();
}


  void setFilterCategories(List<String> categories) {
    filterCategories.value = categories;
    filterProducts();
  }


  void search(String searchValue) {
    searchText.value = searchValue;
    searchProducts.value = products
        .where((product) =>
        product.name.toLowerCase().contains(searchValue.toLowerCase()))
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


//for mobile app
  Future<void> generateExcelFromProducts() async {
    var excel = Excel.createExcel();
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheetObject = excel[defaultSheet];

    String businessName = _businessController.business['name'] ?? 'Business Name';
    String reportTitle = "Product Report";

    sheetObject.appendRow([businessName]);
    sheetObject.appendRow([reportTitle]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);

    final headerRow = [
      "Name",
      "Quantity",
      "Category",
      "Manufacturer",
      "Location",
      "Price",
      "Wholesale Price",
      "Buying Price",
      "Code",
      "Unit",
      "Understock",
      "Item Type"
    ];

    CellStyle headerStyle = CellStyle(
      backgroundColorHex: '#FFC107',
      bold: true,
    );

    var headerRowIndex = sheetObject.maxRows;
    sheetObject.appendRow(headerRow);
    sheetObject.row(headerRowIndex).forEach((cell) {
      cell?.cellStyle = headerStyle;
    });

    for (Product product in filteredProducts) {
      double quantity = product.quantity ?? 0.0;
      sheetObject.appendRow([
        product.name,
        quantity,
        product.category,
        product.manufacturer,
        product.location,
        product.price,
        product.effectiveWholesalePrice,
        product.buyingPrice,
        product.code ?? '',
        product.reserveString1.isNotEmpty ? product.reserveString1 : 'unit',
        product.understock ?? 0,
        product.itemType ?? 'product',
      ]);
    }

    double totalValue = filteredProducts.fold(0, (sum, product) {
      double quantity = product.quantity ?? 0.0;
      return sum + (product.price * quantity);
    });

    sheetObject.appendRow([]);
    sheetObject.appendRow(['', '', 'Total Value:', totalValue, '']);
    var totalValueRowIndex = sheetObject.maxRows - 1;
    sheetObject.row(totalValueRowIndex).forEach((cell) {
      cell?.cellStyle = CellStyle(
        bold: true,
      );
    });

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      errorSnackbar('Failed to generate Excel file'.tr);
      return;
    }

    final fileName = 'Product_Report.xlsx';

    if (DownloadHelper.isWeb) {
      // Web: Direct download using blob
      DownloadHelper.downloadFileWeb(Uint8List.fromList(fileBytes), fileName);
      successSnackbar('Report downloaded successfully!');
    } else {
      // Mobile: Save the file to the device and share
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/$fileName";
      final file = File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Product Report',
      );

      if (result.status == ShareResultStatus.success) {
        print('Thank you for sharing the report!');
      } else if (result.status == ShareResultStatus.dismissed) {
        print('Share dismissed');
      }
    }
  }

//for web
/*
  Future<void> generateExcelFromProducts() async {
    var excel = Excel.createExcel();
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheetObject = excel[defaultSheet];

    String businessName = _businessController.business['name'] ?? 'Business Name';
    String reportTitle = "Product Report";

    sheetObject.appendRow([businessName]);
    sheetObject.appendRow([reportTitle]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);

    final headerRow = [
      "Name", "Quantity", "Category", "Manufacturer", "Location", "Price", "Buying Price", "Code", "Unit", "Understock", "Item Type"
    ];

    CellStyle headerStyle = CellStyle(
      backgroundColorHex: '#FFC107',
      bold: true,
    );

    var headerRowIndex = sheetObject.maxRows;
    sheetObject.appendRow(headerRow);
    sheetObject.row(headerRowIndex).forEach((cell) {
      cell?.cellStyle = headerStyle;
    });

    for (Product product in filteredProducts) {
      double quantity = product.quantity ?? 0.0;
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

    double totalValue = filteredProducts.fold(0, (sum, product) {
      double quantity = product.quantity ?? 0.0;
      return sum + (product.price * quantity);
    });

    sheetObject.appendRow([]);
    sheetObject.appendRow(['', '', 'Total Value:', totalValue, '']);
    var totalValueRowIndex = sheetObject.maxRows - 1;
    sheetObject.row(totalValueRowIndex).forEach((cell) {
      cell?.cellStyle = CellStyle(
        bold: true,
      );
    });

    final fileBytes = excel.encode();
    if (fileBytes != null) {
      // Download the file
      DownloadHelper.downloadFileWeb(Uint8List.fromList(fileBytes), 'Product_Report.xlsx');
    }
  }
*/




  var isUnderstockFilterActive = false.obs; // Tracking the filter state

  // Method to toggle understock filtering
  void toggleUnderstockFilter() {
    // Find products that are understocked
    var understockedProducts = products.where((product) =>
    product.quantity != null && product.quantity! < product.understock!).toList();

    if (understockedProducts.isEmpty) {
      // If there are no understocked products, display a notification
      Get.snackbar(
        'No Understock Products'.tr,
        'There are no products that are currently understock.'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 3),
        backgroundColor: Colors.black,  // Set the background color to black
        colorText: Colors.white,  // Set the text color to white
        snackStyle: SnackStyle.FLOATING,  // Optional: makes the snackbar float above the content
        margin: EdgeInsets.all(16),  // Optional: adds margin around the snackbar
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


  Future<void> copyProductToStore(String productId) async {
  final  String businessOwner=_businessController.business['owner'];
    try {
      // Firestore instance
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      DocumentReference productDocRef = firestore
        .collection('products')
        .doc(_businessController.businessId.value)
        .collection('userProducts')
          .doc(productId);

      // Retrieve the product document
      DocumentSnapshot productSnapshot = await productDocRef.get();

      if (productSnapshot.exists) {
        // Get the product data
        Map<String, dynamic> productData = productSnapshot.data() as Map<String, dynamic>;

        // Set the quantity field to 0.00 for the store collection
        productData['quantity'] = 0.00;

        // Add store-specific data if needed
        productData['storeId'] = businessOwner;

        // Reference to the same product document in the store collection (same productId)
        DocumentReference storeDocRef = firestore
            .collection('store')
            .doc(businessOwner)
            .collection('userStore')
            .doc(productId);

        // Write the modified product data to the store collection
        await storeDocRef.set(productData);
        _showSnackbar('Product copied successfully!');
        print('Product copied successfully to store collection with quantity set to 0.00.');
      } else {
        print('Product with ID $productId does not exist.');
      }
    } catch (e) {
      print('Error copying product to store collection: $e');
    }

  }
  
  /// Helper method to create enhanced stock transactions with full context
  /// Use this for sales, purchases, and other operations that need reference linking
  Future<void> createStockTransaction({
    required String productId,
    required double quantityChange,
    required double previousQuantity,
    required double newQuantity,
    required String transactionType,
    required String transactionOrigin,
    required double price,
    String? referenceId,
    String? referenceType,
    String? notes,
  }) async {
    final String? business = _businessController.business['id'];
    if (business == null) return;

    try {
      final transactionRef = firestore
          .collection('transactions')
          .doc(business)
          .collection('usersTransactions')
          .doc();

      final stockTransaction = StockTransaction(
        transactionId: transactionRef.id,
        productId: productId,
        quantity: quantityChange,
        previousQuantity: previousQuantity,
        newQuantity: newQuantity,
        transactionType: transactionType,
        transactionOrigin: transactionOrigin,
        timestamp: Timestamp.now(),
        userId: business,
        price: price,
        referenceId: referenceId,
        referenceType: referenceType,
        employeeName: _profileController.user['name'],
        notes: notes,
        totalValue: quantityChange * price,
      );

      await transactionRef.set(stockTransaction.toMap());
    } catch (e) {
      print('Error creating stock transaction: $e');
    }
  }
  
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
