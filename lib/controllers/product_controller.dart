import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product_model.dart';
import '../models/stock_transaction.dart';
import '../services/firestore_db.dart';
import 'business_controller.dart';
//import 'dart:html' as html; // Only for web
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
          transactionType:  'addition',
          transactionOrigin: 'Opening Stock',
          timestamp: Timestamp.now(),
          userId: business,
          price:price
      );

      transactionRef.set(stockTransaction.toMap());

    } catch (e) {
      print('Error updating product count and recording transaction: $e');

    }
  }

  Future<void> updateProductCount(Product product, double count, String type) async {
    // Skip quantity update for services
    if (product.itemType == 'service') return;
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

      final currentQuantity = product.quantity ?? 0.0;

      // Await the product quantity update
      productRef.update({'quantity': count});

      // After updating quantity, log the stock transaction
      final transactionRef = firestore
          .collection('transactions')
          .doc(business)
          .collection('usersTransactions')
          .doc();

      final stockTransaction = StockTransaction(
          transactionId: transactionRef.id,
          productId: product.id,
          quantity: count,
          previousQuantity: currentQuantity,
          transactionType: count < currentQuantity ? 'removal' : 'addition',
          transactionOrigin: type,
          timestamp: Timestamp.now(),
          userId: business,
          price: product.price
      );

      // Await the transaction logging
      transactionRef.set(stockTransaction.toMap());

      // After transaction is logged, search for the updated product
      search(searchText.value);
    } catch (e) {
      print('Error updating product count and recording transaction: $e');
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
      "Name", "Quantity", "Category", "Manufacturer", "Location", "Price", "Buying Price"
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
      double quantity = product.quantity ?? 0;
      sheetObject.appendRow([
        product.name,
        quantity,
        product.category,
        product.manufacturer,
        product.location,
        product.price,
        product.buyingPrice,
      ]);
    }

    double totalValue = filteredProducts.fold(0, (sum, product) {
      double quantity = product.quantity ?? 0;
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


    // For mobile: Save the file to the device and share
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/Product_Report.xlsx";
    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

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
      "Name", "Quantity", "Category", "Manufacturer", "Location", "Price", "Buying Price"
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



    // For mobile: Save the file to the device and share
    final fileBytes = excel.encode();
    // For web: Save the file to the browser's download directory
    final blob = html.Blob([fileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Product_Report.xlsx")
      ..click();
    html.Url.revokeObjectUrl(url);

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
  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context as BuildContext).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}
