import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product_model.dart';
import '../models/stock_transaction.dart';
import '../services/firestore_db.dart';
import 'business_controller.dart';
//import 'dart:html' as html; // Only for web
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
        filteredProducts.value = data;
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

  int getProductQuantity(Product product) {
    return products.where((p) => p.id == product.id).length;
  }

  Future<void> moveStockToShop(Product storeProduct, double quantity) async {
    final String? businessOwner = _businessController.business['owner'];
    final String? businessshop = _businessController.businessId.value;
    if (businessOwner == null) {
      print('Business ID is null, cannot move stock.');
      Get.snackbar(
        'Error',
        'Business ID is null',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
      return;
    }

    if (quantity > 0.0 && storeProduct.quantity >= quantity) {
      try {
        // Reference to the corresponding product in the 'products' collection
        final productRef = firestore
            .collection('products')
            .doc(businessshop)
            .collection('userProducts')
            .doc(storeProduct.id);

        // Get current product data from 'products' collection
        final productSnapshot = await productRef.get();
        if (!productSnapshot.exists) {
          print('Product does not exist in products collection.');
          Get.snackbar(
            'Error',
            'Product not in ${_businessController.business['name']}',
            snackPosition: SnackPosition.BOTTOM,
            colorText: Colors.red,
            duration: Duration(seconds: 8), // Set duration to 8 seconds
          );

          return;
        }

        // Calculate new quantities
        final double currentShopQuantity = (productSnapshot['quantity'] ?? 0.0).toDouble();
        final double newShopQuantity = currentShopQuantity + quantity;
        final double newStoreQuantity = storeProduct.quantity - quantity;

        // Update the product's quantity in the 'products' collection
        await productRef.update({'quantity': newShopQuantity});

        // Update the store product's storeQuantity in the 'store' collection
        final storeProductRef = firestore
            .collection('store')
            .doc(businessOwner)
            .collection('userStore')
            .doc(storeProduct.id);
        await storeProductRef.update({'quantity': newStoreQuantity});

        // Log the transaction
        final transactionRef = firestore
            .collection('transactions')
            .doc(businessshop)
            .collection('usersTransactions')
            .doc();

        final stockTransaction = StockTransaction(
            transactionId: transactionRef.id,
            productId: storeProduct.id,
            quantity: quantity,
            previousQuantity: currentShopQuantity,
            transactionType: 'addition',
            transactionOrigin: 'Added From Store',
            timestamp: Timestamp.now(),
            userId: businessOwner,
            price: storeProduct.price
        );

        await transactionRef.set(stockTransaction.toMap());

        Get.snackbar(
          'Stock Moved',
          '$quantity items moved from store to shop.',
          snackPosition: SnackPosition.BOTTOM,
        );
      } catch (e) {
        print('Error moving stock and recording transaction: $e');
        Get.snackbar(
          'Error',
          'Error moving stock: $e',
          snackPosition: SnackPosition.BOTTOM,
          colorText: Colors.red,
        );
      }
    } else {
      Get.snackbar(
        'Error',
        'Insufficient store stock to move.',
        snackPosition: SnackPosition.BOTTOM,
        colorText: Colors.red,
      );
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
      if (product.total != null  && product.price != null) {
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

  void filterProducts() {
    filteredProducts.value = products;
    if (searchText.value.isNotEmpty) {
      filteredProducts.value = products
          .where((product) => product.name
          .toLowerCase()
          .contains(searchText.value.toLowerCase()))
          .toList();
    }
    if (filterCategories.isNotEmpty) {
      filteredProducts.value = filteredProducts.where((product) {
        return filterCategories.contains(product.category);
      }).toList();
    }
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
  //for mobile

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

    // Define header row with background color
    final headerRow = [
      "Name", "Quantity", "Category", "Manufacturer", "Location", "Price", "Buying Price"
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
      double quantity = product.quantity ?? 0;

      // Add a row to the sheet with product details
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

    // Optionally, calculate the total value of all products and add it at the bottom
    double totalValue = filteredProducts.fold(0, (sum, product) {
      double quantity = product.quantity ?? 0;
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

    // Save the file to the user's device
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/Product_Report.xlsx";
    final fileBytes = excel.encode();


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

    // Define header row with background color
    final headerRow = [
      "Name", "Quantity", "Category", "Manufacturer", "Location", "Price", "Buying Price"
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

      // Add a row to the sheet with product details
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



    // For mobile: Save the file to the device and share
    final fileBytes = excel.encode();
    // For web: Save the file to the browser's download directory
    final blob = html.Blob([fileBytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute("download", "Store_Report.xlsx")
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
  void clearStore(){
    products.value.clear();
    filteredProducts.value.clear();
  }
}
