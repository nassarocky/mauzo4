import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/utils/constants.dart';
import '../models/sale_model.dart';
import '../services/firestore_db.dart';
import '../controllers/business_controller.dart';

class InvoiceController extends GetxController {
  final BusinessController _businessController = Get.find();

  final invoices = <Sale>[].obs;
  final filteredInvoices = <Sale>[].obs;
  final dates = <DateTime>[].obs;
  final saleType = 'All'.obs;
  final filterClients = <String>[].obs;

  DateTimeRange? selectedDateRange;
  StreamSubscription<List<Sale>>? _invoiceSubscription;
  StreamSubscription<List<Sale>>? _filteredInvoiceSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _invoiceSubscription = FirestoreDb().getInvoices().listen((data) {
        invoices.value = data;
        filteredInvoices.value = data;
      });
    } catch (e) {
      print("Error initializing InvoiceController: $e");
    }
  }

  @override
  void onClose() {
    _invoiceSubscription?.cancel();
    _filteredInvoiceSubscription?.cancel();
    super.onClose();
  }




  void deleteSale(Sale sale) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot delete sale.');
      return;
    }

    try {
      invoices.remove(sale);
      filteredInvoices.remove(sale);
      
      // Refresh dates list to remove empty date groups
      setInvoicesByDate();
      
      await firestore
          .collection('invoices')
          .doc(business)
          .collection('userInvoices')
          .doc(sale.id)
          .delete();
      successSnackbar('Sale ${'deleted'.tr}');
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  int getDatesCount() {
    return dates.length;
  }

  void setInvoicesByDate() {
    dates.value = [];
    for (var i = 0; i < filteredInvoices.length; i++) {
      DateTime date = filteredInvoices[i].date.toDate();
      date = DateUtils.dateOnly(date);

      if (!dates.contains(date)) {
        dates.add(date);
      }
    }
    dates.sort((a, b) => b.compareTo(a));
  }

  double getTodayInvoices() {
    double todaysInvoices = 0;
    DateTime date = DateUtils.dateOnly(DateTime.now());
    for (var i = 0; i < invoices.length; i++) {
      DateTime saleDate = DateUtils.dateOnly(invoices[i].date.toDate());
      if (saleDate == date) {
        todaysInvoices += invoices[i].price;
      }
    }
    return todaysInvoices;
  }

  double getTotalInvoices() {
    double totalInvoices = 0;
    for (var i = 0; i < invoices.length; i++) {
      totalInvoices += invoices[i].price;
    }
    return totalInvoices;
  }

  double getLastWeekInvoices() {
    double lastWeekInvoices = 0;
    var date =
    DateUtils.dateOnly(DateTime.now()).subtract(const Duration(days: 7));
    var weekDay = date.weekday;
    var firstDayOfWeek = date.subtract(Duration(days: weekDay - 1));

    for (var i = 0; i < invoices.length; i++) {
      DateTime saleDate = invoices[i].date.toDate();
      if (saleDate.isAfter(firstDayOfWeek) &&
          saleDate.isBefore(firstDayOfWeek.add(const Duration(days: 7)))) {
        lastWeekInvoices += invoices[i].price;
      }
    }
    return lastWeekInvoices;
  }

  double getLastMonthInvoices() {
    double lastMonthInvoices = 0;
    var date = DateUtils.dateOnly(DateTime.now());
    var firstDayOfMonth = DateTime(date.year, date.month - 1, 1);
    var lastDayOfMonth = DateTime(date.year, date.month, 1);

    for (var i = 0; i < invoices.length; i++) {
      DateTime saleDate = invoices[i].date.toDate();
      if (saleDate.isAfter(firstDayOfMonth) &&
          saleDate.isBefore(lastDayOfMonth)) {
        lastMonthInvoices += invoices[i].price;
      }
    }
    return lastMonthInvoices;
  }

  double getLastYearInvoices() {
    double lastYearInvoices = 0;

    var date = DateUtils.dateOnly(DateTime.now());
    var firstDayOfYear = DateTime(date.year - 1, 1, 1);
    var lastDayOfYear = DateTime(date.year, 1, 1);

    for (var i = 0; i < invoices.length; i++) {
      DateTime saleDate = invoices[i].date.toDate();
      if (saleDate.isAfter(firstDayOfYear) &&
          saleDate.isBefore(lastDayOfYear)) {
        lastYearInvoices += invoices[i].price;
      }
    }
    return lastYearInvoices;
  }

  List<Sale> getInvoicesByDate(DateTime date) {
    List<Sale> invoicesByDate = [];
    date = DateUtils.dateOnly(date);
    for (var i = 0; i < filteredInvoices.length; i++) {
      DateTime saleDate = DateUtils.dateOnly(filteredInvoices[i].date.toDate());
      if (saleDate == date) {
        invoicesByDate.add(filteredInvoices[i]);
      }
    }
    invoicesByDate.sort((a, b) => b.date.compareTo(a.date));
    return invoicesByDate;
  }

  double getTotalInvoicesByDate(DateTime date) {
    double totalInvoicesByDate = 0;
    date = DateUtils.dateOnly(date);
    for (var i = 0; i < invoices.length; i++) {
      DateTime saleDate = DateUtils.dateOnly(invoices[i].date.toDate());
      if (saleDate == date) {
        totalInvoicesByDate += invoices[i].price;
      }
    }
    return totalInvoicesByDate;
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
    for (var sale in invoices) {
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


  void filterInvoices() async {
    // If date range is selected, query database for that range
    if (selectedDateRange != null) {
      // Cancel previous filtered subscription if exists
      await _filteredInvoiceSubscription?.cancel();
      
      // Query database for the selected date range
      _filteredInvoiceSubscription = FirestoreDb()
          .getInvoicesByDateRange(selectedDateRange!.start, selectedDateRange!.end)
          .listen((data) {
        // Start with queried data
        var filtered = data;
        
        // Apply additional filters
        if (filterClients.isNotEmpty) {
          filtered = filtered.where((sale) {
            return filterClients.contains(sale.client);
          }).toList();
        }
        if (saleType.value == 'Debt') {
          filtered = filtered.where((sale) {
            return sale.debt > 0;
          }).toList();
        }
        
        filteredInvoices.value = filtered;
        setInvoicesByDate();
      });
    } else {
      // No date range selected, use in-memory filtering
      await _filteredInvoiceSubscription?.cancel();
      
      filteredInvoices.value = invoices;
      
      if (filterClients.isNotEmpty) {
        filteredInvoices.value = filteredInvoices.where((sale) {
          return filterClients.contains(sale.client);
        }).toList();
      }
      if (saleType.value == 'Debt') {
        filteredInvoices.value = filteredInvoices.where((sale) {
          return sale.debt > 0;
        }).toList();
      }
      
      setInvoicesByDate();
    }
  }

  void setInvoiceType(String type) {
    saleType.value = type;
    filterInvoices();
  }

  void setFilterClients(List<String> clients) {
    filterClients.value = clients;
    filterInvoices();
  }

  void setSelectedDateRange(DateTimeRange dateRange) {
    selectedDateRange = dateRange;
    filterInvoices();
  }

  void clearSelectedDateRange() async {
    selectedDateRange = null;
    await _filteredInvoiceSubscription?.cancel();
    _filteredInvoiceSubscription = null;
    filterInvoices();
  }
  void clearInvoice(){
    invoices.value.clear();
    filteredInvoices.value.clear();
    filterClients.value.clear();
  }
}
