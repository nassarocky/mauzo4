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
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/models/expences.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/download_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../constants/transaction_constants.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../utils/sale_line_quantity.dart';
import '../utils/operation_error_message.dart';
import '../services/firestore_db.dart';
import '../services/inventory_movement_service.dart';
import '../services/ledger_service.dart';
import '../services/paired_product_service.dart';
import 'business_controller.dart';
import 'expence_controller.dart';

class SaleController extends GetxController {
  StreamSubscription<List<Sale>>? _saleSubscription;
  StreamSubscription<List<Sale>>? _filteredSaleSubscription;

  final BusinessController _businessController = Get.find();
  final ExpenseController expenceController = Get.find();
  final ClientController clientController = Get.find();
  final ProductController productController = Get.find();

  @override
  void onInit() {
    super.onInit();
    bindDefaultSalesStream();
  }

  /// Rebind default list to sales since business [reset_time] (not all history).
  void bindDefaultSalesStream() {
    try {
      _saleSubscription?.cancel();
      _saleSubscription = FirestoreDb().getSales().listen(
        (data) {
          sales.value = data;
          // Do not wipe an active custom date-range query.
          if (!hasCustomDateRange) {
            filterSales();
          }
        },
        onError: (e) {
          print("Error in sales stream: $e");
        },
      );
    } catch (e) {
      print("Error initializing SaleController: $e");
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

  /// Open Sales screen: show reset→today on the date chip and load that period.
  /// Keeps client/employee filters if set before navigation (e.g. employee "view orders").
  Future<void> ensureDefaultPeriodOnOpen() async {
    selectedDateRange = defaultPeriodRange();
    await _filteredSaleSubscription?.cancel();
    _filteredSaleSubscription = null;
    bindDefaultSalesStream();
    if (sales.isNotEmpty) {
      filterSales();
    }
  }

  /// After closing books / business switch: full reset to period since [reset_time].
  Future<void> resetToDefaultPeriod() async {
    filterClients.clear();
    filterEmployee.clear();
    saleType.value = 'All';
    await ensureDefaultPeriodOnOpen();
  }

  // * CRUD
  final sales = <Sale>[].obs;
  final dates = <DateTime>[].obs;

  void deleteSale(Sale sale) async {
    final String? businessId = _businessController.business['id'];

    if (businessId == null) {
      print('business ID is null, cannot delete sale.');
      return;
    }

    try {
      final saleRef = firestore
          .collection('sales')
          .doc(businessId)
          .collection('userSales')
          .doc(sale.id);
      final operationId = firestore.collection('transactions').doc().id;

      await firestore.runTransaction((transaction) async {
        final saleSnapshot = await transaction.get(saleRef);
        if (!saleSnapshot.exists) {
          throw Exception('Sale ${sale.id} no longer exists.');
        }
        final saleData = Map<String, dynamic>.from(saleSnapshot.data() as Map);
        final productLines = List<dynamic>.from(
          saleData['products'] ?? const [],
        );
        final quantities = <String, double>{};
        for (final raw in productLines) {
          final line = Map<String, dynamic>.from(raw as Map);
          if ((line['itemType'] ?? 'product').toString() == 'service') {
            continue;
          }
          final id = (line['id'] ?? '').toString();
          if (id.isEmpty) continue;
          quantities[id] = (quantities[id] ?? 0.0) + saleLineBaseQuantity(line);
        }

        final allIds = <String>{...quantities.keys};
        for (final id in quantities.keys) {
          final cached = productController.getProduct(id);
          if (PairedProductService.isPairedMain(cached) &&
              cached.twinProductId != null) {
            allIds.add(cached.twinProductId!);
          }
        }

        final productIds = allIds.toList();
        final productRefs = [
          for (final id in productIds)
            firestore
                .collection('products')
                .doc(businessId)
                .collection('userProducts')
                .doc(id),
        ];
        final snapshots = await Future.wait(
          productRefs.map(transaction.get),
        );
        final productSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{
              for (var i = 0; i < productIds.length; i++)
                productIds[i]: snapshots[i],
            };

        final movements = <String, double>{};
        for (final entry in quantities.entries) {
          movements[entry.key] = (movements[entry.key] ?? 0.0) + entry.value;
          final cached = productController.getProduct(entry.key);
          if (PairedProductService.isPairedMain(cached) &&
              cached.twinProductId != null) {
            final twinId = cached.twinProductId!;
            movements[twinId] = (movements[twinId] ?? 0.0) - entry.value;
          }
        }

        for (final movement in movements.entries) {
          final snapshot = productSnapshots[movement.key];
          if (snapshot == null || !snapshot.exists) {
            throw Exception('Product ${movement.key} no longer exists.');
          }
          final product = Product.fromSnapshot(snapshot);
          final live = ((snapshot.data()?['quantity'] ?? 0) as num).toDouble();
          final next = live + movement.value;
          if (next < 0) {
            throw Exception(
              '${product.name}: cannot reverse this sale because linked stock is insufficient.',
            );
          }
          final historyRef = InventoryMovementService.transactionRef(
            businessId: businessId,
            operationId: operationId,
            productId: product.id,
          );
          transaction.update(snapshot.reference, {'quantity': next});
          transaction.set(
            historyRef,
            InventoryMovementService.historyData(
              transactionId: historyRef.id,
              product: product,
              delta: movement.value,
              previousQuantity: live,
              origin: TransactionOrigins.saleDeleted,
              businessId: businessId,
              operationId: operationId,
              referenceId: sale.id,
              referenceType: TransactionReferenceTypes.sale,
              employeeName: sale.employeeName,
              notes: 'Stock restored after the sale was deleted.',
            ),
          );
        }

        transaction.delete(saleRef);
      });

      sales.remove(sale);
      filteredSales.remove(sale);
      setSalesByDate();

      // Remove corresponding ledger entries
      try {
        await LedgerService().deleteSaleLedgerEntries(
          saleId: sale.id,
          payments: sale.payments,
          postedAt: sale.date,
        );
      } catch (e) {
        print(
          '⚠️ SaleController.deleteSale: ledger cleanup failed for ${sale.id}: $e',
        );
      }

      successSnackbar('Sale ${'deleted'.tr}');
    } catch (e) {
      errorSnackbar(operationErrorMessage(e));
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
    return getTotalPaymentsByDate(DateUtils.dateOnly(DateTime.now()), sales);
  }

  /// Paid amount for one calendar day (same logic as dashboard [getTodaySales] / Mauzo ya leo).
  double getTotalPaymentsByDate(DateTime date, [List<Sale>? source]) {
    final List<Sale> list = source ?? filteredSales;
    double total = 0;
    final DateTime day = DateUtils.dateOnly(date);
    for (final sale in list) {
      final DateTime saleDate = DateUtils.dateOnly(sale.date.toDate());
      if (saleDate == day) {
        total += _toDouble(sale.payment);
      }
    }
    return total;
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
    var date = DateUtils.dateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 7));
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

  /// Daily header total in Mauzo yote — net sales that day from [filteredSales]
  /// (price − discount; excludes debt-repayment rows).
  double getTotalSalesByDate(DateTime date) {
    double total = 0;
    final target = DateUtils.dateOnly(date);
    for (final sale in filteredSales) {
      if (sale.saleType == 'debt_repayment') continue;
      if (DateUtils.dateOnly(sale.date.toDate()) == target) {
        total += getSaleInvoiceNet(sale);
      }
    }
    return total;
  }

  double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '0') ?? 0.0;
  }

  /// Net invoice total in filter: full [price] minus [discount] (excludes debt-repayment rows).
  /// Shown as MAUZO YOTE / TOTAL SALES in the Mauzo yote summary bar.
  double getFilteredTotalSalesAmount() {
    double total = 0;
    for (final sale in filteredSales) {
      if (sale.saleType == 'debt_repayment') continue;
      total += getSaleInvoiceNet(sale);
    }
    return total;
  }

  /// Full invoice amount after discount (before payment/debt split).
  double getSaleInvoiceNet(Sale sale) {
    final double price = _toDouble(sale.price);
    final double discount = _toDouble(sale.discount);
    final double net = price - discount;
    return net > 0 ? net : 0;
  }

  /// All cash collected in filter (includes debt repayments) — full payments picture.
  double getFilteredTotalPaymentsAmount() {
    double total = 0;
    for (final sale in filteredSales) {
      total += _toDouble(sale.payment);
    }
    return total;
  }

  /// Invoice value still outstanding (credit) in the current filtered list.
  double getFilteredTotalUnpaidAmount() {
    double total = 0;
    for (final sale in filteredSales) {
      if (sale.saleType == 'debt_repayment') continue;
      total += _toDouble(sale.debt);
    }
    return total;
  }

  double getTotalSalesFromTimestamp(
    Timestamp startTimestamp,
    Timestamp endTimestamp,
  ) {
    double totalSales = 0;
    Timestamp currentTimestamp = Timestamp.now();

    for (var sale in sales) {
      // Skip debt repayment sales - they are not new revenue
      if (sale.saleType == 'debt_repayment') {
        continue;
      }

      // Ensure sale.date is of type Timestamp
      if (sale.date is Timestamp) {
        Timestamp saleTimestamp = sale.date;

        // Check if the saleTimestamp is within the specified range (INCLUSIVE boundaries)
        if (saleTimestamp.compareTo(startTimestamp) >= 0 &&
            saleTimestamp.compareTo(endTimestamp) <= 0) {
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

  double getTotalSalesBuyingFromTimestamp(
    Timestamp startTimestamp,
    Timestamp endDate,
  ) {
    double totalSales = 0;
    Timestamp currentTimestamp = Timestamp.now();

    print('🔍 COGS Calculation Debug - Start');
    print('📅 Date range: ${startTimestamp.toDate()} to ${endDate.toDate()}');
    print('📦 Total sales to check: ${sales.length}');

    for (var sale in sales) {
      // Skip debt repayment sales - they have no COGS
      if (sale.saleType == 'debt_repayment') {
        continue;
      }

      // Ensure sale.date is of type Timestamp
      if (sale.date is Timestamp) {
        Timestamp saleTimestamp = sale.date;

        // Check if the saleTimestamp is within the specified range (INCLUSIVE boundaries)
        if (saleTimestamp.compareTo(startTimestamp) >= 0 &&
            saleTimestamp.compareTo(endDate) <= 0) {
          print(
            '✅ Sale ${sale.id} - Date: ${saleTimestamp.toDate()}, BuyingPrice: ${sale.buyingPrice}',
          );
          totalSales += sale.buyingPrice;
        } else {
          print(
            '⏭️ Sale ${sale.id} - Outside range (${saleTimestamp.toDate()})',
          );
        }
      } else {
        // If the date is not in a recognized format, log an error and skip
        print("Unrecognized date format for sale: ${sale.date}");
        continue;
      }
    }

    print('💰 Total COGS: $totalSales');
    return totalSales;
  }

  double getTotalPaymentFromTimestamp(
    Timestamp startTimestamp,
    Timestamp endDate,
  ) {
    double totalPayments = 0;
    Timestamp currentTimestamp = Timestamp.now();

    for (var sale in sales) {
      // Skip debt repayment sales - they are not new revenue
      if (sale.saleType == 'debt_repayment') {
        continue;
      }

      // Ensure sale.date is of type Timestamp
      if (sale.date is Timestamp) {
        Timestamp saleTimestamp = sale.date;

        // Check if the saleTimestamp is within the specified range (INCLUSIVE boundaries)
        if (saleTimestamp.compareTo(startTimestamp) >= 0 &&
            saleTimestamp.compareTo(endDate) <= 0) {
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

  double getDebtCollectedFromTimestamp(
    Timestamp startTimestamp,
    Timestamp endTimestamp,
  ) {
    double debtCollected = 0;

    for (var sale in sales) {
      // Only count debt repayment sales - these are collections on old debts
      if (sale.saleType == 'debt_repayment') {
        if (sale.date is Timestamp) {
          Timestamp saleTimestamp = sale.date;

          // Check if the saleTimestamp is within the specified range
          if (saleTimestamp.compareTo(startTimestamp) >= 0 &&
              saleTimestamp.compareTo(endTimestamp) <= 0) {
            debtCollected += sale.payment;
          }
        }
      }
    }

    return debtCollected;
  }

  double getTotalServiceSalesFromTimestamp(
    Timestamp startTimestamp,
    Timestamp endTimestamp,
  ) {
    double totalServiceSales = 0;
    const double debtTol = 0.01;

    for (var sale in sales) {
      if (sale.saleType == 'debt_repayment') {
        continue;
      }
      if (sale.date is! Timestamp) {
        continue;
      }
      final Timestamp saleTimestamp = sale.date;
      if (saleTimestamp.compareTo(startTimestamp) < 0 ||
          saleTimestamp.compareTo(endTimestamp) > 0) {
        continue;
      }

      // Align with product-style reporting: service revenue is not counted in this tile
      // while the sale still has outstanding debt; after debt is cleared on the original
      // sale document, lines count like a normal settled sale.
      final bool debtBlocksServiceRevenue = sale.debt.abs() > debtTol;

      for (var product in sale.products) {
        String itemType = 'product';
        if (product is Map<String, dynamic> &&
            product.containsKey('itemType')) {
          itemType = (product['itemType'] ?? 'product').toString();
        } else if (product is Product) {
          itemType = product.itemType;
        }
        if (itemType != 'service') continue;
        if (debtBlocksServiceRevenue) continue;

        if (product is Map<String, dynamic>) {
          final dynamic rawP = product['price'];
          final double price = rawP is int
              ? rawP.toDouble()
              : (rawP is num
                    ? rawP.toDouble()
                    : double.tryParse(rawP?.toString() ?? '0') ?? 0.0);
          final double quantity = saleLineBaseQuantity(product);
          totalServiceSales += price * quantity;
        } else if (product is Product) {
          totalServiceSales += product.price * product.quantity;
        }
      }
    }
    return totalServiceSales;
  }

  DateTime parseDateString(String dateString) {
    // Define the format of the date string
    DateFormat format = DateFormat("dd MMMM yyyy 'at' HH:mm:ss 'UTC'XXX");

    // Parse the date string into a DateTime object
    return format.parseUtc(dateString).toLocal();
  }

  List<Map<String, dynamic>> getTopProducts(String value) {
    var dateStart = DateUtils.dateOnly(DateTime.now());
    var dateEnd = DateUtils.dateOnly(
      DateTime.now(),
    ).add(const Duration(days: 1));

    // * last week
    if (value == 'last_week'.tr) {
      var date = DateUtils.dateOnly(
        DateTime.now(),
      ).subtract(const Duration(days: 7));
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
  // Filled with reset→today on open; custom picks use getSalesByDateRange.
  DateTimeRange? selectedDateRange;
  final filteredSales = <Sale>[].obs;
  final saleType = 'All'.obs;
  final filterClients = <String>[].obs;
  final filterEmployee = <String>[].obs;
  void filterSales() async {
    // Default period (reset → today): use reset_time stream already in [sales].
    // Custom range: query Firestore for that window only.
    final bool useCustomRange = hasCustomDateRange;
    if (useCustomRange) {
      await _filteredSaleSubscription?.cancel();
      _filteredSaleSubscription = FirestoreDb()
          .getSalesByDateRange(selectedDateRange!.start, selectedDateRange!.end)
          .listen((data) {
            var filtered = data;
            if (filterClients.isNotEmpty) {
              filtered = filtered.where((sale) {
                return filterClients.contains(sale.client);
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
      await _filteredSaleSubscription?.cancel();
      _filteredSaleSubscription = null;
      // Keep chip filled with the default period while using reset stream data.
      selectedDateRange ??= defaultPeriodRange();
      if (!isDefaultPeriod(selectedDateRange!)) {
        selectedDateRange = defaultPeriodRange();
      }

      var filtered = List<Sale>.from(sales);
      if (filterClients.isNotEmpty) {
        filtered = filtered.where((sale) {
          return filterClients.contains(sale.client);
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

  void filterSalesById(String saleId) async {
    filteredSales.value = sales.where((sale) => sale.id == saleId).toList();
    if (filteredSales.isNotEmpty) {
      setSalesByDate();
      return;
    }

    try {
      final String? businessId = _businessController.business['id'];
      if (businessId == null || businessId.isEmpty) {
        return;
      }
      final doc = await firestore
          .collection('sales')
          .doc(businessId)
          .collection('userSales')
          .doc(saleId)
          .get();
      if (doc.exists) {
        final sale = Sale.fromSnapshot(doc);
        filteredSales.value = [sale];
        setSalesByDate();
      }
    } catch (e) {
      print('filterSalesById fetch error: $e');
    }
  }

  void setSaleType(String type) {
    saleType.value = type;
    filterSales();
  }

  void setFilterClients(List<String> clients) {
    filterClients.value = clients;
    filterSales();
  }

  void setFilterEmployee(List<String> employees) {
    filterEmployee.value = employees;
    filterSales();
  }

  void setSelectedDateRange(DateTimeRange dateRange) {
    selectedDateRange = DateTimeRange(
      start: DateUtils.dateOnly(dateRange.start),
      end: DateUtils.dateOnly(dateRange.end),
    );
    filterSales();
  }

  void clearSelectedDateRange() async {
    selectedDateRange = defaultPeriodRange();
    await _filteredSaleSubscription?.cancel();
    _filteredSaleSubscription = null;
    bindDefaultSalesStream();
    filterSales();
  }

  @override
  void onClose() {
    _saleSubscription?.cancel();
    _filteredSaleSubscription?.cancel();
    super.onClose();
  }
  //for mobile app

  /*
  Future<void> generateExcelFromSales() async {
    // Create a new Excel document
    var excel = Excel.createExcel();

    // Get the default sheet
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheetObject = excel[defaultSheet];

    // Set the selected date range for expenses
    expenceController.selectedDateRange = selectedDateRange;

    // Add the business name and date range as the first row (heading)
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

    // Define header row with background color
    final headerRow = ['Products', 'Client', 'Date', 'Price', 'Buying Price', 'Payment', 'Debt', 'Comment'];

    // Apply a background color to the header row
    CellStyle headerStyle = CellStyle(
      backgroundColorHex: '#FFC107', // Amber color
      bold: true,
    );

    // Add header row with styling
    var headerRowIndex = sheetObject.maxRows;
    expenceController.filterExpenses();
    sheetObject.appendRow(headerRow);
    sheetObject.row(headerRowIndex).forEach((cell) {
      cell?.cellStyle = headerStyle;
    });

    // Initialize variables to accumulate the totals
    double totalAmount = 0.0;
    double totalBuyingAmount = 0.0;
    double totalPayment = 0.0;
    double totalDebt = 0.0;
    double totalExpense = 0.0;

    // Iterate through the list of sales and add each sale as a row in the Excel sheet
    for (Sale sale in filteredSales) {
      Client client = clientController.resolveClientForSale(sale);
      String productNames = sale.products.map((product) {
        if (product is Product) {
          return '${product.quantity} ${product.name}';
        } else if (product is Map<String, dynamic> && product.containsKey('name') && product.containsKey('quantity')) {
          return '${product['quantity']} ${product['name']}'; // If product is a Map with 'name' and 'quantity' keys
        }
        return '';
      }).join(", ");

      // Accumulate the total price, payment, debt, and buying price
      totalAmount += sale.price;
      totalBuyingAmount += sale.buyingPrice;
      totalPayment += sale.payment;
      totalDebt += sale.debt;

      // Add a row to the sheet
      sheetObject.appendRow([
        productNames,
        client.name,
        DateFormat('dd MMM yyyy').format(sale.date.toDate()), // Convert Timestamp to readable date
        sale.price,
        sale.buyingPrice, // Add Buying Price
        sale.payment,
        sale.debt,
        sale.comment,
      ]);
    }

    // Calculate total expenses
    for (Expense expense in expenceController.filteredExpenses) {
      totalExpense += expense.amount;
    }

    // Add an empty row for spacing before the Total rows
    sheetObject.appendRow([]);

    // Add Total rows for Amount, Buying Price, Payment, and Debt at the bottom
    var totalsRowIndex = sheetObject.maxRows; // Store the row index for the totals row
    sheetObject.appendRow(['', '', 'Totals:', totalAmount, totalBuyingAmount, totalPayment, totalDebt, '']);

// Apply a bold style and background color to the Totals row
    var totalsStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#ADD8E6', // Light blue color for the totals row
    );

    sheetObject.row(totalsRowIndex).forEach((cell) {
      cell?.cellStyle = totalsStyle;
    });

// Calculate estimated profit: totalAmount - totalBuyingAmount - totalExpense
    double estimatedProfit = totalAmount - totalBuyingAmount - totalExpense;

// Add a report section for estimated profit and how it was calculated
    sheetObject.appendRow(['']);
    sheetObject.appendRow(['', '', 'Total Expenses:', totalExpense]);
    sheetObject.appendRow(['', '', 'Estimated Profit:', estimatedProfit]);
    sheetObject.appendRow(['', '', 'Calculation: Estimated Profit = Total Selling Price - Total Buying Price - Total Expenses']);

// Apply a bold style and background color to the Total rows and profit rows
    var totalRows = [
      sheetObject.maxRows - 4, // Expense row
      sheetObject.maxRows - 3, // Estimated profit row
      sheetObject.maxRows - 2, // Profit calculation row
    ];

    for (var rowIndex in totalRows) {
      sheetObject.row(rowIndex+1).forEach((cell) {
        cell?.cellStyle = CellStyle(bold: true, backgroundColorHex: '#D3D3D3'); // Light gray color for other rows
      });
    }


    // Save the file to the user's device
    final directory = await getApplicationDocumentsDirectory();
    final filePath = "${directory.path}/Sales_Report.xlsx";
    final fileBytes = excel.encode();


    final file = File(filePath)
      ..createSync(recursive: true)
      ..writeAsBytesSync(fileBytes!);

    final result = await Share.shareXFiles(
      [XFile(filePath)],
      text: 'Sales Report',
    );

    if (result.status == ShareResultStatus.success) {
      print('Thank you for sharing the report!');
    } else if (result.status == ShareResultStatus.dismissed) {
      print('Share dismissed');
    }


  }*/

  //for web app

  Future<void> generateExcelFromSales() async {
    // Create a new Excel document
    var excel = Excel.createExcel();

    // Get the default sheet
    String defaultSheet = excel.getDefaultSheet()!;
    Sheet sheetObject = excel[defaultSheet];

    // Set the selected date range for expenses
    expenceController.selectedDateRange = selectedDateRange;

    // Add the business name and date range as the first row (heading)
    String businessName =
        _businessController.business['name'] ?? 'Business Name';
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

    // Define header row with background color
    final headerRow = [
      'Products',
      'Client',
      'Date',
      'Price',
      'Buying Price',
      'Payment',
      'Debt',
      'Comment',
    ];

    // Apply a background color to the header row
    CellStyle headerStyle = CellStyle(
      backgroundColorHex: '#FFC107', // Amber color
      bold: true,
    );

    // Add header row with styling
    var headerRowIndex = sheetObject.maxRows;
    expenceController.filterExpenses();
    sheetObject.appendRow(headerRow);
    sheetObject.row(headerRowIndex).forEach((cell) {
      cell?.cellStyle = headerStyle;
    });

    // Initialize variables to accumulate the totals
    double totalAmount = 0.0;
    double totalBuyingAmount = 0.0;
    double totalPayment = 0.0;
    double totalDebt = 0.0;
    double totalExpense = 0.0;

    // Iterate through the list of sales and add each sale as a row in the Excel sheet
    for (Sale sale in filteredSales) {
      Client client = clientController.resolveClientForSale(sale);
      String productNames = sale.products
          .map((product) {
            if (product is Product) {
              return '${product.quantity} ${product.name}';
            } else if (product is Map<String, dynamic> &&
                product.containsKey('name') &&
                product.containsKey('quantity')) {
              return '${product['quantity']} ${product['name']}'; // If product is a Map with 'name' and 'quantity' keys
            }
            return '';
          })
          .join(", ");

      // Accumulate the total price, payment, debt, and buying price
      totalAmount += sale.price;
      totalBuyingAmount += sale.buyingPrice;
      totalPayment += sale.payment;
      totalDebt += sale.debt;

      // Add a row to the sheet
      sheetObject.appendRow([
        productNames,
        client.name,
        DateFormat(
          'dd MMM yyyy',
        ).format(sale.date.toDate()), // Convert Timestamp to readable date
        sale.price,
        sale.buyingPrice, // Add Buying Price
        sale.payment,
        sale.debt,
        sale.comment,
      ]);
    }

    // Calculate total expenses
    for (Expense expense in expenceController.filteredExpenses) {
      totalExpense += expense.amount;
    }

    // Add an empty row for spacing before the Total rows
    sheetObject.appendRow([]);

    // Add Total rows for Amount, Buying Price, Payment, and Debt at the bottom
    var totalsRowIndex =
        sheetObject.maxRows; // Store the row index for the totals row
    sheetObject.appendRow([
      '',
      '',
      'Totals:',
      totalAmount,
      totalBuyingAmount,
      totalPayment,
      totalDebt,
      '',
    ]);

    // Apply a bold style and background color to the Totals row
    var totalsStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#ADD8E6', // Light blue color for the totals row
    );

    sheetObject.row(totalsRowIndex).forEach((cell) {
      cell?.cellStyle = totalsStyle;
    });

    // Calculate estimated profit: totalAmount - totalBuyingAmount - totalExpense
    double estimatedProfit = totalAmount - totalBuyingAmount - totalExpense;

    // Add a report section for estimated profit and how it was calculated
    sheetObject.appendRow(['']);
    sheetObject.appendRow(['', '', 'Total Expenses:', totalExpense]);
    sheetObject.appendRow(['', '', 'Estimated Profit:', estimatedProfit]);
    sheetObject.appendRow([
      '',
      '',
      'Calculation: Estimated Profit = Total Selling Price - Total Buying Price - Total Expenses',
    ]);

    // Apply a bold style and background color to the Total rows and profit rows
    var totalRows = [
      sheetObject.maxRows - 4, // Expense row
      sheetObject.maxRows - 3, // Estimated profit row
      sheetObject.maxRows - 2, // Profit calculation row
    ];

    for (var rowIndex in totalRows) {
      sheetObject.row(rowIndex + 1).forEach((cell) {
        cell?.cellStyle = CellStyle(
          bold: true,
          backgroundColorHex: '#D3D3D3',
        ); // Light gray color for other rows
      });
    }

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      errorSnackbar('Failed to generate Excel file'.tr);
      return;
    }

    final fileName = 'Sales_Report.xlsx';

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

      await Share.shareXFiles([XFile(filePath)], text: 'Sales Report');
    }
  }

  void clearSales() {
    sales.value.clear();
    filteredSales.value.clear();
    filterClients.value.clear();
  }
}
