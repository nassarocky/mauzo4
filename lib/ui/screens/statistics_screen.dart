import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/services/firestore_db.dart';
import 'package:mauzo/models/sale_model.dart';

import '../../controllers/product_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../utils/preferences.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final BusinessController _businessController = Get.find();
  final ProductController _productController = Get.find();
  final ProfileController _profileController = Get.find();
  
  // Load ALL sales data directly from Firestore (no reset_time filter)
  List<Sale> _allSales = [];
  StreamSubscription<List<Sale>>? _salesSubscription;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // CRITICAL SECURITY CHECK: Verify user has permission to view statistics
    if (!_profileController.hasPermission('view_statistics')) {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: User tried to access StatisticsScreen without view_statistics permission');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to view statistics',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }
    
    // Load all sales data for statistics (bypasses reset_time filter)
    _loadAllSalesData();
  }

  void _loadAllSalesData() {
    _salesSubscription = FirestoreDb().getAllSalesForStatistics().listen((sales) {
      setState(() {
        _allSales = sales;
        _isLoading = false;
      });
    });
  }

  @override
  void dispose() {
    _salesSubscription?.cancel();
    super.dispose();
  }

  String time = 'last_week'.tr;

  // Calculate statistics methods using _allSales data
  double _getTodaySales() {
    double todaysSales = 0;
    DateTime date = DateUtils.dateOnly(DateTime.now());
    for (var sale in _allSales) {
      DateTime saleDate = DateUtils.dateOnly(sale.date.toDate());
      if (saleDate == date) {
        todaysSales += sale.payment;
      }
    }
    return todaysSales;
  }

  double _getYesterdaySales() {
    double yesterdaySales = 0;
    DateTime yesterday = DateUtils.dateOnly(DateTime.now().subtract(const Duration(days: 1)));
    for (var sale in _allSales) {
      DateTime saleDate = DateUtils.dateOnly(sale.date.toDate());
      if (saleDate == yesterday) {
        yesterdaySales += sale.price;
      }
    }
    return yesterdaySales;
  }

  double _getLastWeekSales() {
    double lastWeekSales = 0;
    DateTime now = DateTime.now();
    DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));

    for (var sale in _allSales) {
      DateTime saleDate = sale.date.toDate();
      if (saleDate.isAfter(sevenDaysAgo)) {
        lastWeekSales += sale.price;
      }
    }
    return lastWeekSales;
  }

  double _getLastMonthSales() {
    double lastMonthSales = 0;
    DateTime now = DateTime.now();
    DateTime thirtyDaysAgo = now.subtract(const Duration(days: 30));

    for (var sale in _allSales) {
      DateTime saleDate = sale.date.toDate();
      if (saleDate.isAfter(thirtyDaysAgo)) {
        lastMonthSales += sale.price;
      }
    }
    return lastMonthSales;
  }

  double _getLastYearSales() {
    double lastYearSales = 0;
    DateTime now = DateTime.now();
    DateTime oneYearAgo = now.subtract(const Duration(days: 365));

    for (var sale in _allSales) {
      DateTime saleDate = sale.date.toDate();
      if (saleDate.isAfter(oneYearAgo)) {
        lastYearSales += sale.price;
      }
    }
    return lastYearSales;
  }

  double _getTotalSales() {
    double totalSales = 0;
    for (var sale in _allSales) {
      totalSales += sale.price;
    }
    return totalSales;
  }

  List<Map<String, dynamic>> _getTopProducts(String timeFilter) {
    Map<String, Map<String, dynamic>> productStats = {};
    
    DateTime now = DateTime.now();
    
    for (var sale in _allSales) {
      DateTime saleDate = sale.date.toDate();
      bool includeThisSale = false;
      
      if (timeFilter == 'today'.tr) {
        // Only today's sales
        DateTime today = DateUtils.dateOnly(now);
        DateTime saleDateOnly = DateUtils.dateOnly(saleDate);
        includeThisSale = saleDateOnly == today;
      } else if (timeFilter == 'yesterday'.tr) {
        // Only yesterday's sales
        DateTime yesterday = DateUtils.dateOnly(now.subtract(const Duration(days: 1)));
        DateTime saleDateOnly = DateUtils.dateOnly(saleDate);
        includeThisSale = saleDateOnly == yesterday;
      } else if (timeFilter == 'last_week'.tr) {
        // Last 7 days
        DateTime sevenDaysAgo = now.subtract(const Duration(days: 7));
        includeThisSale = saleDate.isAfter(sevenDaysAgo);
      } else if (timeFilter == 'last_month'.tr) {
        // Last 30 days
        DateTime thirtyDaysAgo = now.subtract(const Duration(days: 30));
        includeThisSale = saleDate.isAfter(thirtyDaysAgo);
      } else if (timeFilter == 'last_year'.tr) {
        // Last 365 days
        DateTime oneYearAgo = now.subtract(const Duration(days: 365));
        includeThisSale = saleDate.isAfter(oneYearAgo);
      } else {
        // All time
        includeThisSale = true;
      }
      
      if (includeThisSale) {
        for (var product in sale.products) {
          String productId = product['id'];
          String productName = product['name'];
          double quantity = (product['quantity'] ?? 0).toDouble();
          double price = (product['price'] ?? 0).toDouble();

          if (productStats.containsKey(productId)) {
            productStats[productId]!['quantity'] += quantity;
          } else {
            productStats[productId] = {
              'id': productId,
              'name': productName,
              'quantity': quantity,
              'price': price,
            };
          }
        }
      }
    }

    List<Map<String, dynamic>> topProducts = productStats.values.toList();
    topProducts.sort((a, b) => (b['quantity'] as double).compareTo(a['quantity'] as double));
    
    return topProducts.take(20).toList();
  }

  double _getSalesForTimeFilter(String timeFilter) {
    if (timeFilter == 'today'.tr) {
      return _getTodaySales();
    } else if (timeFilter == 'yesterday'.tr) {
      return _getYesterdaySales();
    } else if (timeFilter == 'last_week'.tr) {
      return _getLastWeekSales();
    } else if (timeFilter == 'last_month'.tr) {
      return _getLastMonthSales();
    } else if (timeFilter == 'last_year'.tr) {
      return _getLastYearSales();
    } else {
      return _getTotalSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> items = [
      'today'.tr,
      'yesterday'.tr,
      'last_week'.tr,
      'last_month'.tr,
      'last_year'.tr,
      'all_time'.tr,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text('statistics'.tr),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.only(left: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          Preferences.getTheme() ? lightGrayColor : borderColor,
                    ),
                  ),
                  child: DropdownButton(
                    isExpanded: true,
                    underline: Container(),
                    value: time,
                    items: items.map((item) {
                      return DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        time = value!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF00AD30),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'total_sales_statistics'.tr,
                      style: bodyText(whiteColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(
                          _getSalesForTimeFilter(time), _businessController.business['mainCurrency']),
                      style: h5(whiteColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'products_sold'.tr,
                style: h5(Theme.of(context).textTheme.bodyLarge!.color),
              ),
              const SizedBox(height: 20),
              _getTopProducts(time).isEmpty
                  ? SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Center(
                            child: Text('no_products_sold'.tr),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _getTopProducts(time).length,
                      itemBuilder: (context, index) {
                        var product = _getTopProducts(time)[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _productController
                                          .getProduct(product['id'])
                                          .image !=
                                      ''
                                  ? Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: borderColor),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: CachedNetworkImage(
                                          imageUrl: _productController
                                              .getProduct(product['id'])
                                              .image!,
                                          placeholder: (context, url) =>
                                              Container(
                                            padding: const EdgeInsets.all(10),
                                            child:
                                                const CircularProgressIndicator(),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              Container(
                                            height: 48,
                                            width: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF80B2FF),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            padding: const EdgeInsets.all(10),
                                            child: Image.asset(
                                                'assets/images/box.png'),
                                          ),
                                          height: 48,
                                          width: 48,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      height: 48,
                                      width: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF80B2FF),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.all(10),
                                      child:
                                          Image.asset('assets/images/box.png'),
                                    ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product['name'],
                                      style: bodyText(
                                        Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text(
                                          '${'sold'.tr}: ${product['quantity']}',
                                          style: bodyText(greenColor),
                                        ),
                                        const SizedBox(width: 14),
                                        Text(
                                          '${'total'.tr}: ${formatCurrency(product['quantity'] * product['price'], _businessController.business['mainCurrency'])}',
                                          style: bodyText(greenColor),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
            ],
          ),
        ),
      ),
    );
  }
}
