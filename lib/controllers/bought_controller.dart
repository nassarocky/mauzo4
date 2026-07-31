import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/store_controller.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/models/expences.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/download_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../services/firestore_db.dart';
import '../controllers/profile_controller.dart';
import 'business_controller.dart';
import 'package:mauzo/utils/preferences.dart';
class BoughtController extends GetxController {
  final BusinessController _businessController = Get.find();
  final ClientController clientController = Get.find();
  final ProductController productController = Get.find();
  final StoreController storeController = Get.find();

  final sales = <Sale>[].obs;
  final filteredSales = <Sale>[].obs;

  StreamSubscription<List<Sale>>? _salesSubscription;
  StreamSubscription<List<Sale>>? _filteredSalesSubscription;

  @override
  void onInit() {
    super.onInit();
    bindDefaultPurchasesStream();
  }

  /// Rebind default list to purchases since business [reset_time] (not all history).
  void bindDefaultPurchasesStream() {
    try {
      _salesSubscription?.cancel();
      _salesSubscription = FirestoreDb().getBought().listen((data) {
        sales.value = data;
        // Do not wipe an active custom date-range query.
        if (!hasCustomDateRange) {
          filterSales();
        }
      }, onError: (e) {
        print("Error in purchases stream: $e");
      });
    } catch (e) {
      print("Error binding bought sales stream: $e");
    }
  }

  /// Display range for the date chip: selected range, or reset → today.
  DateTimeRange defaultPeriodRange() {
    final start = DateUtils.dateOnly(
      FirestoreDb().defaultListPeriodStart().toDate(),
    );
    final end = DateUtils.dateOnly(DateTime.now());
    if (end.isBefore(start)) {
      return DateTimeRange(start: end, end: end);
    }
    return DateTimeRange(start: start, end: end);
  }

  DateTimeRange get effectiveDateRange =>
      selectedDateRange ?? defaultPeriodRange();

  bool isDefaultPeriod(DateTimeRange range) {
    final def = defaultPeriodRange();
    return DateUtils.dateOnly(range.start) == def.start &&
        DateUtils.dateOnly(range.end) == def.end;
  }

  bool get hasCustomDateRange =>
      selectedDateRange != null && !isDefaultPeriod(selectedDateRange!);

  String get dateRangeChipLabel {
    final range = effectiveDateRange;
    return '${DateFormat('dd/MM/yyyy').format(range.start)} - ${DateFormat('dd/MM/yyyy').format(range.end)}';
  }

  /// Open Purchases screen: show reset→today on the date chip and load that period.
  /// Keeps supplier filters when [keepClientFilters] is true.
  Future<void> ensureDefaultPeriodOnOpen({bool keepClientFilters = false}) async {
    selectedDateRange = defaultPeriodRange();
    if (!keepClientFilters) {
      filterClients.clear();
      saleType.value = 'All';
    }
    filterEmployee.clear();
    await _filteredSalesSubscription?.cancel();
    _filteredSalesSubscription = null;
    bindDefaultPurchasesStream();
    if (sales.isNotEmpty) {
      filterSales();
    }
  }

  /// After closing books / business switch: full reset to period since [reset_time].
  Future<void> resetToDefaultPeriod({bool keepClientFilters = false}) async {
    await ensureDefaultPeriodOnOpen(keepClientFilters: keepClientFilters);
  }

  @override
  void onClose() {
    _salesSubscription?.cancel();
    _filteredSalesSubscription?.cancel();
    super.onClose();
  }

  final dates = <DateTime>[].obs;
void clearBought(){
  sales.value.clear();
  filteredSales.clear();
}
  void deleteSale(Sale sale) async {
    final String? businessId = _businessController.business['id'];

    if (businessId == null) {
      print('business ID is null, cannot delete sale.');
      return;
    }

    try {
      // Remove the sale from the local list
      sales.remove(sale);
      filteredSales.remove(sale);
      
      // Refresh dates list to remove empty date groups
      setSalesByDate();

      // Fetch the products from the sale
      List products = sale.products;
      
      // Fetch purchase destination from Firestore to determine which inventory to update
      String purchaseDestination = 'shop'; // Default for old purchases without this field
      final purchaseDoc = await firestore
          .collection('recovered')
          .doc(businessId)
          .collection('userRecovered')
          .doc(sale.id)
          .get();
      
      if (purchaseDoc.exists) {
        final purchaseData = purchaseDoc.data();
        purchaseDestination = purchaseData?['purchaseDestination'] ?? 'shop';
      }

      // Batch all product quantity updates for better offline support
      final updates = <Future>[];

      // Reverse the product quantities in inventory (subtract purchased amounts)
      for (var product in products) {
        String productId = product['id'];
        // Handle both int and double types from Firestore
        double quantityToRemove = (product['quantity'] is int)
            ? (product['quantity'] as int).toDouble()
            : (product['quantity'] as num).toDouble();

        if (purchaseDestination == 'store') {
          // Update store inventory
          var productInStore = storeController.products.firstWhere(
            (p) => p.id == productId,
            orElse: () => Product(
              id: '',
              name: '',
              code: '',
              price: 0,
              buyingPrice: 0,
              quantity: 0,
              category: null,
              owner: '',
              image: '',
              itemType: 'product',
            ),
          );
          
          if (productInStore.id.isNotEmpty) {
            double newQuantity = productInStore.quantity! - quantityToRemove;
            updates.add(storeController.updateProductCount(productInStore, newQuantity));
          }
        } else {
          // Update business inventory (default behavior)
          var productInInventory = productController.getProduct(productId);
          
          if (productInInventory.id.isNotEmpty) {
            double newQuantity = productInInventory.quantity - quantityToRemove;
            updates.add(productController.updateProductCount(
              productInInventory,
              newQuantity,
              'Purchase Deleted',
            ));
          }
        }
      }

      // Wait for all product updates together
      await Future.wait(updates);

      // Delete the purchase from Firestore
      await firestore
          .collection('recovered')
          .doc(businessId)
          .collection('userRecovered')
          .doc(sale.id)
          .delete();

      successSnackbar('Purchase ${'deleted'.tr}');
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  int getDatesCount() {
    return dates.length;
  }

  void setSalesByDate() {
    dates.value = [];
    for (var i = 0; i < filteredSales.length; i++) {
      DateTime date = filteredSales[i].date.toDate();
      date = DateUtils.dateOnly(date);

      if (!dates.contains(date)) {
        dates.add(date);
      }
    }
    dates.sort((a, b) => b.compareTo(a));
  }

  double getTodaySales() {
    double todaysSales = 0;
    DateTime date = DateUtils.dateOnly(DateTime.now());
    for (var i = 0; i < sales.length; i++) {
      DateTime saleDate = DateUtils.dateOnly(sales[i].date.toDate());
      if (saleDate == date) {
        todaysSales += sales[i].price;
      }
    }
    return todaysSales;
  }

  double getTotalSales() {
    double totalSales = 0;
    for (var i = 0; i < sales.length; i++) {
      totalSales += sales[i].price;
    }
    return totalSales;
  }

  double getLastWeekSales() {
    double lastWeekSales = 0;
    var date =
    DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 7));
    var weekDay = date.weekday;
    var firstDayOfWeek = date.subtract(Duration(days: weekDay - 1));

    for (var i = 0; i < sales.length; i++) {
      DateTime saleDate = sales[i].date.toDate();
      if (saleDate.isAfter(firstDayOfWeek) &&
          saleDate.isBefore(firstDayOfWeek.add(const Duration(days: 7)))) {
        lastWeekSales += sales[i].price;
      }
    }
    return lastWeekSales;
  }

  double getLastMonthSales() {
    double lastMonthSales = 0;
    var date = DateUtils.dateOnly(DateTime.now());
    var firstDayOfMonth = DateTime(date.year, date.month - 1, 1);
    var lastDayOfMonth = DateTime(date.year, date.month, 1);

    for (var i = 0; i < sales.length; i++) {
      DateTime saleDate = sales[i].date.toDate();
      if (saleDate.isAfter(firstDayOfMonth) &&
          saleDate.isBefore(lastDayOfMonth)) {
        lastMonthSales += sales[i].price;
      }
    }
    return lastMonthSales;
  }

  double getLastYearSales() {
    double lastYearSales = 0;

    var date = DateUtils.dateOnly(DateTime.now());
    var firstDayOfYear = DateTime(date.year - 1, 1, 1);
    var lastDayOfYear = DateTime(date.year, 1, 1);

    for (var i = 0; i < sales.length; i++) {
      DateTime saleDate = sales[i].date.toDate();
      if (saleDate.isAfter(firstDayOfYear) &&
          saleDate.isBefore(lastDayOfYear)) {
        lastYearSales += sales[i].price;
      }
    }
    return lastYearSales;
  }

  List<Sale> getSalesByDate(DateTime date) {
    List<Sale> salesByDate = [];
    date = DateUtils.dateOnly(date);
    for (var i = 0; i < filteredSales.length; i++) {
      DateTime saleDate = DateUtils.dateOnly(filteredSales[i].date.toDate());
      if (saleDate == date) {
        salesByDate.add(filteredSales[i]);
      }
    }
    salesByDate.sort((a, b) => b.date.compareTo(a.date));
    return salesByDate;
  }

  /// Net purchase amount after discount.
  double getPurchaseNet(Sale sale) {
    final double net = sale.price - sale.discount;
    return net > 0 ? net : 0;
  }

  // New: sum of paid values for a specific date (purchases)
  double getTotalPaidByDate(DateTime date) {
    double totalPaidByDate = 0;
    final target = DateUtils.dateOnly(date);
    for (var i = 0; i < filteredSales.length; i++) {
      DateTime saleDate = DateUtils.dateOnly(filteredSales[i].date.toDate());
      if (saleDate == target) {
        totalPaidByDate += filteredSales[i].payment;
      }
    }
    return totalPaidByDate;
  }

  /// Daily header total for purchases — uses [filteredSales] so date-range
  /// filters (e.g. 1 May–1 Jun) show the correct day sum.
  double getTotalSalesByDate(DateTime date) {
    double totalSalesByDate = 0;
    final target = DateUtils.dateOnly(date);
    for (var i = 0; i < filteredSales.length; i++) {
      DateTime saleDate = DateUtils.dateOnly(filteredSales[i].date.toDate());
      if (saleDate == target) {
        totalSalesByDate += getPurchaseNet(filteredSales[i]);
      }
    }
    return totalSalesByDate;
  }

  /// Grand total of the current filtered purchase list (date range / supplier / etc.).
  double getFilteredTotalPurchasesAmount() {
    double total = 0;
    for (final sale in filteredSales) {
      total += getPurchaseNet(sale);
    }
    return total;
  }

  /// Total paid across the current filtered purchase list.
  double getFilteredTotalPaidAmount() {
    double total = 0;
    for (final sale in filteredSales) {
      total += sale.payment;
    }
    return total;
  }


  double getTotalSalesFromTimestamp(Timestamp startTimestamp,Timestamp endDate) {
    double totalSales = 0;
    Timestamp currentTimestamp = Timestamp.now();

    for (var sale in sales) {
      // Ensure sale.date is of type Timestamp
      if (sale.date is Timestamp) {
        Timestamp saleTimestamp = sale.date;

        // Check if the saleTimestamp is within the specified range (INCLUSIVE boundaries)
        if (saleTimestamp.compareTo(startTimestamp) >= 0 && saleTimestamp.compareTo(endDate) <= 0) {
          totalSales += sale.price;
        }
      } else {
        // If the date is not in a recognized format, log an error and skip
        print("Unrecognized date format for sale: ${sale.date}");
        continue;
      }
    }

    return totalSales;
  }


  double getTotalSalesBuyingFromTimestamp(Timestamp startTimestamp) {
    double totalSales = 0;
    Timestamp currentTimestamp = Timestamp.now();

    for (var sale in sales) {
      // Ensure sale.date is of type Timestamp
      if (sale.date is Timestamp) {
        Timestamp saleTimestamp = sale.date;

        // Check if the saleTimestamp is within the specified range (INCLUSIVE boundaries)
        if (saleTimestamp.compareTo(startTimestamp) >= 0 && saleTimestamp.compareTo(currentTimestamp) <= 0) {
          totalSales += sale.buyingPrice;
        }
      } else {
        // If the date is not in a recognized format, log an error and skip
        print("Unrecognized date format for sale: ${sale.date}");
        continue;
      }
    }

    return totalSales;
  }
  double getTotalPaymentFromTimestamp(Timestamp startTimestamp) {
    double totalPayments = 0;
    Timestamp currentTimestamp = Timestamp.now();

    for (var sale in sales) {
      // Ensure sale.date is of type Timestamp
      if (sale.date is Timestamp) {
        Timestamp saleTimestamp = sale.date;

        // Check if the saleTimestamp is within the specified range (INCLUSIVE boundaries)
        if (saleTimestamp.compareTo(startTimestamp) >= 0 && saleTimestamp.compareTo(currentTimestamp) <= 0) {
          totalPayments += sale.payment;
        }
      } else {
        // If the date is not in a recognized format, log an error and skip
        print("Unrecognized date format for sale: ${sale.date}");
        continue;
      }
    }

    return totalPayments;
  }

  // New: Sum of all amounts actually paid to suppliers for purchases in a time window (all methods)
  double getTotalPurchasePaidFromTimestamp(
      Timestamp startTimestamp, Timestamp endTimestamp) {
    double totalPaid = 0.0;
    final String mainCurrency = _businessController.business['mainCurrency'] ?? 'TZS';

    for (final purchase in sales) {
      if (purchase.date is Timestamp) {
        final Timestamp ts = purchase.date;
        if (ts.compareTo(startTimestamp) >= 0 && ts.compareTo(endTimestamp) <= 0) {
          if (purchase.payments.isNotEmpty) {
            for (final p in purchase.payments) {
              final dynamic rawAmount = p['amount'];
              final double amt = rawAmount is int
                  ? rawAmount.toDouble()
                  : (rawAmount is num ? rawAmount.toDouble() : 0.0);
              final String currency = (p['currency'] ?? mainCurrency).toString();
              final double amtMain = currency == mainCurrency
                  ? amt
                  : amt * Preferences.getExchangeRateResult();
              totalPaid += amtMain;
            }
          } else {
            // Fallback to aggregate payment (assumed main currency)
            totalPaid += purchase.payment;
          }
        }
      }
    }
    return totalPaid;
  }

  // New: Cash-only amounts paid to suppliers for purchases in a time window
  double getTotalPurchaseCashPaidFromTimestamp(
      Timestamp startTimestamp, Timestamp endTimestamp) {
    double cashPaid = 0.0;
    final String mainCurrency = _businessController.business['mainCurrency'] ?? 'TZS';

    for (final purchase in sales) {
      if (purchase.date is Timestamp) {
        final Timestamp ts = purchase.date;
        if (ts.compareTo(startTimestamp) >= 0 && ts.compareTo(endTimestamp) <= 0) {
          if (purchase.payments.isNotEmpty) {
            for (final p in purchase.payments) {
              // Treat missing, null, or empty method as 'cash' for backward compatibility
              final String method = (p['method'] ?? 'cash').toString().trim();
              final String methodNormalized = method.isEmpty ? 'cash' : method;
              if (methodNormalized == 'cash') {
                final dynamic rawAmount = p['amount'];
                final double amt = rawAmount is int
                    ? rawAmount.toDouble()
                    : (rawAmount is num ? rawAmount.toDouble() : 0.0);
                final String currency = (p['currency'] ?? mainCurrency).toString();
                final double amtMain = currency == mainCurrency
                    ? amt
                    : amt * Preferences.getExchangeRateResult();
                cashPaid += amtMain;
              }
            }
          } else {
            // No detailed breakdown: treat aggregate as cash (backward compatibility)
            if (purchase.payment > 0) {
              cashPaid += purchase.payment;
            }
          }
        }
      }
    }
    return cashPaid;
  }

  DateTime parseDateString(String dateString) {
    // Define the format of the date string
    DateFormat format = DateFormat("dd MMMM yyyy 'at' HH:mm:ss 'UTC'XXX");

    // Parse the date string into a DateTime object
    return format.parseUtc(dateString).toLocal();
  }








  List<Map<String, dynamic>> getTopProducts(String value) {
    var dateStart = DateUtils.dateOnly(DateTime.now());
    var dateEnd =
    DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));

    // * last week
    if (value == 'last_week'.tr) {
      var date =
      DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 7));
      var weekDay = date.weekday;
      dateStart = date.subtract(Duration(days: weekDay - 1));
      dateEnd = dateStart.add(const Duration(days: 7));
    }
    // * last month
    else if (value == 'last_month'.tr) {
      var date = DateUtils.dateOnly(DateTime.now());
      dateStart = DateTime(date.year, date.month - 1, 1);
      dateEnd = DateTime(date.year, date.month, 1);
    }
    // * last year
    else if (value == 'last_year'.tr) {
      var date = DateUtils.dateOnly(DateTime.now());
      dateStart = DateTime(date.year - 1, 1, 1);
      dateEnd = DateTime(date.year, 1, 1);
    }
    // * all time
    else if (value == 'all_time'.tr) {
      dateStart = DateTime(0, 0, 0);
      dateEnd = DateTime(3000, 0, 0);
    }

    List<Map<String, dynamic>> products = [];
    List<String> productIds = [];
    for (var sale in sales) {
      if (sale.date.toDate().isAfter(dateStart) &&
          sale.date.toDate().isBefore(dateEnd)) {
        for (var product in sale.products) {
          if (!productIds.contains(product['id'])) {
            productIds.add(product['id']);
            products.add(Map.from(product));
          } else {
            for (var i = 0; i < products.length; i++) {
              if (products[i]['id'] == product['id']) {
                products[i]['price'] =
                    ((product['price'] * product['quantity']) +
                        (products[i]['price'] * products[i]['quantity'])) /
                        (products[i]['quantity'] + product['quantity']);
                products[i]['quantity'] += product['quantity'];
              }
            }
          }
        }
      }
    }
    products.sort((a, b) => b['quantity']!.compareTo(a['quantity']!));
    return products;
  }

  // * FILTERING
  DateTimeRange? selectedDateRange;
  final saleType = 'All'.obs;
  final filterClients = <String>[].obs;
  final filterEmployee = <String>[].obs;
  void filterSales() async {
    // Default period (reset → today): use reset_time stream already in [sales].
    // Custom range: query Firestore for that window only.
    final bool useCustomRange = hasCustomDateRange;
    if (useCustomRange) {
      await _filteredSalesSubscription?.cancel();
      _filteredSalesSubscription = FirestoreDb()
          .getBoughtByDateRange(selectedDateRange!.start, selectedDateRange!.end)
          .listen((data) {
        var filtered = data;
        if (filterClients.isNotEmpty) {
          filtered = filtered.where((sale) {
            return filterClients.contains(sale.supplier);
          }).toList();
        }
        if (filterEmployee.isNotEmpty) {
          filtered = filtered.where((sale) {
            return filterEmployee.contains(sale.employeeId);
          }).toList();
        }
        if (saleType.value == 'Debt') {
          filtered = filtered.where((sale) {
            return sale.debt > 0;
          }).toList();
        }
        filteredSales.value = filtered;
        setSalesByDate();
      });
    } else {
      await _filteredSalesSubscription?.cancel();
      _filteredSalesSubscription = null;
      selectedDateRange ??= defaultPeriodRange();
      if (!isDefaultPeriod(selectedDateRange!)) {
        selectedDateRange = defaultPeriodRange();
      }

      var filtered = List<Sale>.from(sales);
      if (filterClients.isNotEmpty) {
        filtered = filtered.where((sale) {
          return filterClients.contains(sale.supplier);
        }).toList();
      }
      if (filterEmployee.isNotEmpty) {
        filtered = filtered.where((sale) {
          return filterEmployee.contains(sale.employeeId);
        }).toList();
      }
      if (saleType.value == 'Debt') {
        filtered = filtered.where((sale) {
          return sale.debt > 0;
        }).toList();
      }
      filteredSales.value = filtered;
      setSalesByDate();
    }
  }
  void filterSalesById(String saleId) {
    filteredSales.value = sales.where((sale) => sale.id == saleId).toList();
  }

  void setSaleType(String type) {
    saleType.value = type;
    filterSales();
  }

  void setFilterClients(List<String> clients) {
    filterClients.value = clients;
    filterSales();
  }

  void setSelectedDateRange(DateTimeRange dateRange) {
    selectedDateRange = dateRange;
    filterSales();
  }

  void clearSelectedDateRange() async {
    selectedDateRange = defaultPeriodRange();
    await _filteredSalesSubscription?.cancel();
    _filteredSalesSubscription = null;
    bindDefaultPurchasesStream();
    filterSales();
  }

  void setFilterEmployee(List<String> employees) {
    filterEmployee.value = employees;
    filterSales();
  }

  Future<void> generateExcelFromSales() async {
    // Create a new Excel document
    var excel = Excel.createExcel();

    // Get the default sheet
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheetObject = excel[defaultSheet];

    // Set the selected date range for sales
    String businessName = _businessController.business['name'] ?? 'Business Name';
    String dateRange = selectedDateRange != null
        ? '${DateFormat('dd MMM yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(selectedDateRange!.end)}'
        : 'All Time';

    // Add the business name and date range
    sheetObject.appendRow([businessName]);
    sheetObject.appendRow(['Date Range: $dateRange']);

    // Add multiple empty rows for better spacing
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);
    sheetObject.appendRow([]);

    // Define header row with background color (without Buying Price and Debt columns)
    final headerRow = ['Products', 'Client', 'Date', 'Selling Price', 'Buying Price', 'Comment'];

    // Apply a background color to the header row
    CellStyle headerStyle = CellStyle(
      backgroundColorHex: '#FFC107', // Amber color
      bold: true,
    );

    // Add header row with styling
    var headerRowIndex = sheetObject.maxRows;
    sheetObject.appendRow(headerRow);
    sheetObject.row(headerRowIndex).forEach((cell) {
      cell?.cellStyle = headerStyle;
    });

    // Initialize variables to accumulate the totals
    double totalAmount = 0.0;
    double totalPayment = 0.0;

    // Iterate through the list of sales and add each sale as a row in the Excel sheet
    for (Sale sale in filteredSales) {
      Client client = clientController.getClient(sale.client);
      String productNames = sale.products.map((product) {
        if (product is Product) {
          return '${product.quantity} ${product.name}';
        } else if (product is Map<String, dynamic> && product.containsKey('name') && product.containsKey('quantity')) {
          return '${product['quantity']} ${product['name']}'; // If product is a Map with 'name' and 'quantity' keys
        }
        return '';
      }).join(", ");

      // Accumulate the total price and payment
      totalAmount += sale.price;
      totalPayment += sale.payment;

      // Add a row to the sheet
      sheetObject.appendRow([
        productNames,
        client.name,
        DateFormat('dd MMM yyyy').format(sale.date.toDate()), // Convert Timestamp to readable date
        sale.price,
        sale.payment,
        sale.comment,
      ]);
    }

    // Add an empty row for spacing before the Total rows
    sheetObject.appendRow([]);

    // Add Total rows for Amount and Payment at the bottom
    var totalsRowIndex = sheetObject.maxRows; // Store the row index for the totals row
    sheetObject.appendRow(['', '', 'Totals:', totalAmount, totalPayment, '']);

    // Apply a bold style and background color to the Totals row
    var totalsStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#ADD8E6', // Light blue color for the totals row
    );

    sheetObject.row(totalsRowIndex).forEach((cell) {
      cell?.cellStyle = totalsStyle;
    });

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      errorSnackbar('Failed to generate Excel file'.tr);
      return;
    }

    final fileName = 'Purchases_Report.xlsx';

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

      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Purchases Report',
      );
    }
  }






}