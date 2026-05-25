import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/supplier_controller.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/models/supplier_model.dart';
import 'package:mauzo/models/sale_model.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/screens/sale/edit_sale.screen.dart';
import 'package:mauzo/ui/screens/Buy_Product_cart_screen.dart';
import 'package:mauzo/ui/widgets/dashed_seperator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import '../../../controllers/bought_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../controllers/sale_controller.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import '../../../utils/download_helper.dart';
import '../../../utils/purchases_access.dart';

class BoughtScreen extends StatefulWidget {
  const BoughtScreen({Key? key}) : super(key: key);

  @override
  State<BoughtScreen> createState() => _boughtControllerState();
}

class _boughtControllerState extends State<BoughtScreen> {
  final BoughtController _boughtController = Get.find();
  final ClientController _clientController = Get.find();
  final SupplierController _supplierController = Get.find();
  final ProductController _productController = Get.find();
  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  @override
  void initState() {
    super.initState();
    
    if (!PurchasesAccess.isEnabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        PurchasesAccess.notifyDisabled();
      });
      return;
    }

    if (!_profileController.hasPermission('buy_products')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to view or manage product purchases',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }

    // Check for supplier filter arguments from navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arguments = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (arguments != null && arguments.containsKey('supplierId')) {
        final String supplierId = arguments['supplierId'];
        final String supplierName = arguments['supplierName'] ?? 'Unknown Supplier';
        
        print('DEBUG: Applying supplier filter for ID: $supplierId, Name: $supplierName');
        
        // Apply supplier filter after ensuring data is loaded
        Future.delayed(const Duration(milliseconds: 1000), () {
          print('DEBUG: Sales count: ${_boughtController.sales.length}');
          print('DEBUG: Suppliers count: ${_supplierController.suppliers.length}');
          
          // Check if any sales have this supplier ID
          final matchingSales = _boughtController.sales.where((sale) => sale.supplier == supplierId).toList();
          print('DEBUG: Found ${matchingSales.length} sales with supplier ID: $supplierId');
          
          _boughtController.setFilterClients([supplierId]);
          
          // Force a refresh of the filtered sales
          Future.delayed(const Duration(milliseconds: 100), () {
            print('DEBUG: Filtered sales count: ${_boughtController.filteredSales.length}');
          });
        });
      }
      
      // Always initialize the sales data
      Timer.run(() {
        _boughtController.setSalesByDate();
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    Timer.run(() {
      _boughtController.clearSelectedDateRange();
      _boughtController.filterClients.value = [];
      //_boughtController.filterDebt.value = '';
      _boughtController.setSaleType('All');
      _boughtController.filteredSales.value = _boughtController.sales;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canViewPurchases = _profileController.hasPermission('view_purchases');
    final bool canCreatePurchase =
        _profileController.hasPermission('buy_products');

    return Scaffold(
      backgroundColor: Preferences.getTheme()
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFE5E5E5),
      floatingActionButton: canCreatePurchase
          ? FloatingActionButton(
              onPressed: () {
                if (PurchasesAccess.requireEnabled()) {
                  Navigator.pushNamed(context, '/buy');
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        title: Text(
          'all_purchases'.tr,
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,  // Make the app bar background white
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),  // Set the back icon color to black
        actions: [
          IconButton(
            icon: Image.asset(
              'assets/images/excel.png',  // Path to your custom Excel icon
              width: 24,  // Set the desired width for the icon
              height: 24,  // Set the desired height for the icon
            ),
            onPressed: () {
              _boughtController.generateExcelFromSales();  // Call the generateExcel method
            },
          ),
        ],
      ),
      body: Obx(
            () => Column(
          children: [
            Container(
              height: 8,
              color: Preferences.getTheme()
                  ? Theme.of(context).scaffoldBackgroundColor
                  : whiteColor,
            ),
            Container(
              color: Preferences.getTheme()
                  ? Theme.of(context).scaffoldBackgroundColor
                  : whiteColor,
              height: 40,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                scrollDirection: Axis.horizontal,
                children: [
                  _boughtController.sales.length !=
                      _boughtController.filteredSales.length
                      ? Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _boughtController.filterClients.value = [];
                          _boughtController.setSaleType('All');
                          _boughtController.clearSelectedDateRange();
                          _boughtController.filterSales();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: Preferences.getTheme()
                                  ? mediumGrayColor
                                  : borderColor,
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            Icons.cancel,
                            color: Preferences.getTheme()
                                ? lightGrayColor
                                : iconGrayColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  )
                      : Container(),
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        isScrollControlled: true,
                        context: context,
                        builder: (context) {
                          return const SelectSuppliersBottomSheet();
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Preferences.getTheme()
                              ? mediumGrayColor
                              : borderColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            _boughtController.filterClients.length ==
                                _supplierController.suppliers.length ||
                                _boughtController.filterClients.isEmpty
                                ? 'all_suppliers'.tr
                                : _boughtController.filterClients.length == 1
                                ? '${_boughtController.filterClients.length} ${'supplier'.tr.toLowerCase()}'
                                : '${_boughtController.filterClients.length} ${'suppliers'.tr.toLowerCase()}',
                            style: bodyText(
                              Theme.of(context).textTheme.bodyMedium!.color,
                            ),
                          ),
                          const Icon(
                            Icons.expand_more,
                            color: iconGrayColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime.now(),
                      ).then(
                            (DateTimeRange? value) {
                          if (value != null) {
                            DateTimeRange fromRange = DateTimeRange(
                              start: DateTime.now(),
                              end: DateTime.now(),
                            );
                            setState(() {
                              fromRange = value;
                              _boughtController.setSelectedDateRange(fromRange);
                            });

                            final String range =
                                '${DateFormat('dd/MM/yyyy').format(fromRange.start)} - ${DateFormat('dd/MM/yyyy').format(fromRange.end)}';
                            successSnackbar("${'date'.tr}: $range");
                          }
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Preferences.getTheme()
                              ? mediumGrayColor
                              : borderColor,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Text(
                            _boughtController.selectedDateRange != null
                                ? '${DateFormat('dd/MM/yyyy').format(_boughtController.selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_boughtController.selectedDateRange!.end)}'
                                : 'any_date'.tr,
                            style: bodyText(
                              Theme.of(context).textTheme.bodyMedium!.color,
                            ),
                          ),
                          const Icon(
                            Icons.expand_more,
                            color: iconGrayColor,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 8,
              color: Preferences.getTheme()
                  ? Theme.of(context).scaffoldBackgroundColor
                  : whiteColor,
            ),
            Expanded(
              child: _boughtController.getDatesCount() == 0
                  ? Center(
                child: Text(
                  'not_found'.tr,
                  style: bodyText(textPlaceholderColor),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: _boughtController.getDatesCount(),
                itemBuilder: (context, index) {
                  List<Map<String, dynamic>> salesByDate = [];

                  for (var i = 0; i < _boughtController.dates.length; i++) {
                    salesByDate.add({
                      'date': _boughtController.dates[i],
                      'sales': _boughtController
                          .getSalesByDate(_boughtController.dates[i]),
                    });
                  }

                  // Skip if sales list is empty (after deletion)
                  if (salesByDate[index]['sales'].isEmpty) {
                    return SizedBox.shrink();
                  }

                  return StickyHeader(
                    header: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.maxFinite,
                      height: 48,
                      color: const Color(0xFFFFEA9F),
                      child: Row(
                        children: [
                          Text(
                            DateFormat("dd.MM.yyyy", 'en_US').format(
                                salesByDate[index]['sales'][0]
                                    .date
                                    .toDate()),
                            style: h5(textDarkColor),
                          ),
                          const Spacer(),
                          Text(
                            '${'paid'.tr}: ${formatCurrency(_boughtController.getTotalPaidByDate(
                              salesByDate[index]['date'],
                            ), _businessController.business['mainCurrency'])}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: textPlaceholderColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    content: Container(
                      padding: const EdgeInsets.only(top: 20, bottom: 10),
                      child: Column(
                        children: List.from(
                          salesByDate[index]['sales'].map(
                                (sale) {
                              final supplier = sale.supplier != null && sale.supplier!.isNotEmpty 
                                  ? _supplierController.getSupplier(sale.supplier!)
                                  : null;
                              final time = sale.date.toDate();

                              return Container(
                                color: Preferences.getTheme()
                                    ? mediumGrayColor
                                    : whiteColor,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                margin: const EdgeInsets.only(
                                    left: 16, right: 16, bottom: 10),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${'reciept'.tr}: ${DateFormat("hh:mm a", 'en_US').format(time)}',
                                          style: h6(
                                            Theme.of(context)
                                                .textTheme
                                                .bodyLarge!
                                                .color,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (_profileController
                                            .hasPermission('buy_products'))
                                          PopupMenuButton(
                                            child: Icon(
                                              Icons.more_vert,
                                              color: Preferences.getTheme() ? primaryLightColor : primaryColor,
                                              size: 24,
                                            ),
                                            onSelected: (value) {
                                              if (value == 'Delete') {
                                                _boughtController.deleteSale(sale);
                                              } else if (value == 'Edit') {
                                                editPurchase(sale, supplier, context, time);
                                              }
                                            },
                                            itemBuilder: (BuildContext context) =>
                                            <PopupMenuEntry<String>>[
                                              PopupMenuItem<String>(
                                                value: 'Edit',
                                                child: Text(
                                                  'edit'.tr,
                                                  style: bodyText(redColor),
                                                ),
                                              ),
                                              PopupMenuItem<String>(
                                                value: 'Delete',
                                                child: Text(
                                                  'delete'.tr,
                                                  style: bodyText(redColor),
                                                ),
                                              ),
                                            ],
                                          )
                                        ,
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.account_circle,
                                          color: iconGrayColor,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          supplier == null
                                              ? 'unnamed_supplier'.tr
                                              : supplier.name,
                                          style: bodyText(
                                              Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .color),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const DashedSeperator(),
                                    const SizedBox(height: 12),
                                    for (var i = 0;
                                    i < sale.products.length;
                                    i++)
                                      Container(
                                        margin: const EdgeInsets.only(
                                            bottom: 12),
                                        child: Row(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment
                                                    .start,
                                                children: [
                                                  Text(
                                                    sale.products[i]
                                                    ['name'],
                                                    style: bodyText(
                                                      Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge!
                                                          .color,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                      height: 4),
                                                  Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '${sale.products[i]['quantity']} * ${formatCurrency(
                                                            (sale.products[i]['price'] is int) 
                                                              ? (sale.products[i]['price'] as int).toDouble() 
                                                              : sale.products[i]['price'],
                                                            _businessController.business['mainCurrency'],
                                                          )}',
                                                          style:
                                                          TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                            FontWeight
                                                                .w400,
                                                            color: Theme.of(
                                                                context)
                                                                .textTheme
                                                                .bodyMedium!
                                                                .color,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        formatCurrency(
                                                          (sale.products[i]['quantity'] is int ? (sale.products[i]['quantity'] as int).toDouble() : sale.products[i]['quantity']) * 
                                                          (sale.products[i]['price'] is int ? (sale.products[i]['price'] as int).toDouble() : sale.products[i]['price']),
                                                          _businessController.business['mainCurrency'],
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                          FontWeight
                                                              .w400,
                                                          color: Theme.of(
                                                              context)
                                                              .textTheme
                                                              .bodyMedium!
                                                              .color,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const DashedSeperator(),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            printInvoice(sale, supplier);
                                          },
                                          icon: const Icon(Icons.print),
                                          label: Text('print'.tr),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            shareInvoice(sale, supplier);
                                          },
                                          icon: const Icon(Icons.share),
                                          label: Text('share'.tr),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${'total'.tr}: ${formatCurrency(
                                              (sale.price is int) ? (sale.price as int).toDouble() : sale.price,
                                              _businessController.business['mainCurrency']
                                            )}',
                                            style: h6(Theme.of(context).textTheme.bodyLarge!.color),
                                          ),
                                          sale.discount > 0
                                              ? Text(
                                            '${'discount'.tr}: ${formatCurrency(
                                              (sale.discount is int) ? (sale.discount as int).toDouble() : sale.discount,
                                              _businessController.business['mainCurrency']
                                            )}',
                                            style: bodyText(
                                              Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .color,
                                            ),
                                          )
                                              : const SizedBox(),
                                          // Bottom summary row: fund source on the left, amount/status on the right
                                          Builder(builder: (_) {
                                            final String fundSourceText = (() {
                                              final fs = sale.fundSource;
                                              if (fs == null ||
                                                  fs.toString().trim().isEmpty) {
                                                return '';
                                              }
                                              final String s = fs.toString();
                                              if (s == 'other') {
                                                final note = sale.fundSourceNote;
                                                return (note != null &&
                                                        note.isNotEmpty)
                                                    ? 'Other: $note'
                                                    : 'Other';
                                              }
                                              return _businessController
                                                  .paymentMethodLabelForValue(
                                                      s);
                                            })();

                                            return Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: fundSourceText.isNotEmpty
                                                      ? Text(
                                                          fundSourceText,
                                                          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                                                          overflow: TextOverflow.ellipsis,
                                                        )
                                                      : const SizedBox(),
                                                ),
                                                sale.debt == 0
                                                    ? (sale.payment == sale.price
                                                        ? Text(
                                                            'paid'.tr,
                                                            style: bodyText(greenColor),
                                                          )
                                                        : sale.payment > 0
                                                            ? Text(
                                                                '${'paid'.tr}: ${formatCurrency(sale.payment, _businessController.business['mainCurrency'])}',
                                                                style: bodyText(greenColor),
                                                              )
                                                            : const SizedBox())
                                                    : Text(
                                                        '${'debt'.tr}: ${formatCurrency(sale.debt, _businessController.business['mainCurrency'])}',
                                                        style: bodyText(redColor),
                                                      ),
                                              ],
                                            );
                                          }),
                                          sale.employeeId !=null
                                              ? Text(
                                            '${'processed by'.tr}: ${sale.employeeName}',
                                            style:
                                            TextStyle(
                                              fontSize: 14,
                                              fontWeight:
                                              FontWeight
                                                  .w400,
                                              color: Theme.of(
                                                  context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .color,
                                            ),
                                          )
                                              : const SizedBox(),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> printInvoice(invoice, Supplier? supplier) async {
    final pdf = pw.Document();
    final currency = _businessController.business['mainCurrency'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Receipt', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Row(
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Business: ${_businessController.business['business']}', style: pw.TextStyle(fontSize: 18)),
                      pw.Text('Phone: ${_businessController.business['phone']}', style: pw.TextStyle(fontSize: 18)),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Supplier: ${supplier?.name ?? 'Unknown Supplier'}', style: pw.TextStyle(fontSize: 18)),
                      pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()) + ' ' + DateFormat('kk:mm').format(DateTime.now()), style: pw.TextStyle(fontSize: 18)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Product Name', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      pw.Text('Quantity', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      pw.Text('Price', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      pw.Text('Total ($currency)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    ],
                  ),
                  ...invoice.products.map<pw.TableRow>((product) {
                    final quantity = (product['quantity'] ?? 0).toDouble();
                    final price = (product['price'] ?? 0.0).toDouble();
                    return pw.TableRow(
                      children: [
                        pw.Text(product['name'], textAlign: pw.TextAlign.center),
                        pw.Text(quantity.toString(), textAlign: pw.TextAlign.center),
                        pw.Text(price.toString(), textAlign: pw.TextAlign.center),
                        pw.Text((quantity * price).toString(), textAlign: pw.TextAlign.center),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Total: ${invoice.price.toString()}', style: pw.TextStyle(fontSize: 16)),
                ],
              ),
              if (invoice.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: pw.TextStyle(fontSize: 16)),
                    pw.Text(invoice.discount.toString(), style: pw.TextStyle(fontSize: 16)),
                  ],
                ),
              if (invoice.debt > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Debt:', style: pw.TextStyle(fontSize: 16)),
                    pw.Text(invoice.debt.toString(), style: pw.TextStyle(fontSize: 16)),
                  ],
                ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> shareInvoice(invoice, Supplier? supplier) async {
    final pdf = pw.Document();
    final currency = _businessController.business['mainCurrency'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Receipt', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Row(
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Business: ${_businessController.business['business']}', style: pw.TextStyle(fontSize: 18)),
                      pw.Text('Phone: ${_businessController.business['phone']}', style: pw.TextStyle(fontSize: 18)),
                    ],
                  ),
                  pw.Spacer(),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Supplier: ${supplier?.name ?? 'Unknown Supplier'}', style: pw.TextStyle(fontSize: 18)),
                      pw.Text(DateFormat('yyyy-MM-dd').format(DateTime.now()) + ' ' + DateFormat('kk:mm').format(DateTime.now()), style: pw.TextStyle(fontSize: 18)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Text('Product Name', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      pw.Text('Quantity', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      pw.Text('Price', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      pw.Text('Total ($currency)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                    ],
                  ),
                  ...invoice.products.map<pw.TableRow>((product) {
                    final quantity = (product['quantity'] ?? 0).toDouble();
                    final price = (product['price'] ?? 0.0).toDouble();
                    return pw.TableRow(
                      children: [
                        pw.Text(product['name'], textAlign: pw.TextAlign.center),
                        pw.Text(quantity.toString(), textAlign: pw.TextAlign.center),
                        pw.Text(price.toString(), textAlign: pw.TextAlign.center),
                        pw.Text((quantity * price).toString(), textAlign: pw.TextAlign.center),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('Total: ${invoice.price.toString()}', style: pw.TextStyle(fontSize: 16)),
                ],
              ),
              if (invoice.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:', style: pw.TextStyle(fontSize: 16)),
                    pw.Text(invoice.discount.toString(), style: pw.TextStyle(fontSize: 16)),
                  ],
                ),
              if (invoice.debt > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Debt:', style: pw.TextStyle(fontSize: 16)),
                    pw.Text(invoice.debt.toString(), style: pw.TextStyle(fontSize: 16)),
                  ],
                ),
            ],
          );
        },
      ),
    );

    try {
      final pdfBytes = await pdf.save();
      final fileName = 'Purchase_Receipt_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      
      if (DownloadHelper.isWeb) {
        // Web: Direct download using blob
        DownloadHelper.downloadFileWeb(pdfBytes, fileName);
        successSnackbar('PDF downloaded successfully!');
      } else {
        // Mobile: Save to file and share
        final directory = await getApplicationDocumentsDirectory();
        final filePath = "${directory.path}/$fileName";
        final file = File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(pdfBytes);

        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'Purchase Receipt',
        );
      }
    } catch (e) {
      errorSnackbar('Error generating PDF: $e');
    }
  }



  void editPurchase(Sale purchase, Supplier? supplier, BuildContext context, DateTime time) {
    if (!PurchasesAccess.requireEnabled()) return;

    List<Product> products = [];

    for (final product in purchase.products) {
      Product existingProduct = _productController.getProduct(product['id']);

      if (existingProduct.id == '') {
        products.add(
          Product(
            id: product['id'],
            name: product['name'],
            price: product['price'],
            discount: product['discount'],
            quantity: (product['quantity'] as num).toDouble(),
            count: (product['quantity'] as num).toDouble(),
            code: '',
            owner: '',
          ),
        );
      } else {
        existingProduct.count = (product['quantity'] as num).toDouble();
        products.add(existingProduct);
      }
    }

    if (supplier != null) {
      _cartController.supplier = supplier;
    }
    _cartController.setDiscount(purchase.discount);
    _cartController.clearPayments();
    if (purchase.payments.isNotEmpty) {
      for (final p in purchase.payments) {
        final double amt = (p['amount'] is int)
            ? (p['amount'] as int).toDouble()
            : (p['amount'] as num?)?.toDouble() ?? 0.0;
        if (amt <= 0) continue;
        final String currency = (p['currency'] ?? _businessController.business['mainCurrency']).toString();
        final String method = (p['method'] ?? 'cash').toString();
        _cartController.addPayment(amt, currency, method: method);
      }
    } else if (purchase.payment > 0) {
      _cartController.addPayment(purchase.payment, _businessController.business['mainCurrency']);
    }

    _cartController.setComment(purchase.comment);
    _cartController.setProducts(products, purchase.products);
    _cartController.passedArgument = purchase.id;
    _cartController.origin = 'edit_purchase';

    if (!PurchasesAccess.requireEnabled()) return;

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => const BuyProductCartScreen(),
      ),
    );
  }
}

class SelectSuppliersBottomSheet extends StatefulWidget {
  const SelectSuppliersBottomSheet({Key? key}) : super(key: key);

  @override
  State<SelectSuppliersBottomSheet> createState() =>
      _SelectSuppliersBottomSheetState();
}

class _SelectSuppliersBottomSheetState extends State<SelectSuppliersBottomSheet> {
  List<String> localFilterSuppliers = [];
  final BoughtController _boughtController = Get.find();

  @override
  void initState() {
    localFilterSuppliers = [..._boughtController.filterClients]; // Note: BoughtController still uses filterClients for now
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final SupplierController supplierController = Get.find();
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'suppliers'.tr,
                  style: h5(Theme.of(context).textTheme.bodyLarge!.color),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: const Icon(
                    Icons.close,
                    color: iconGrayColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.purple,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.purple
                  ],
                  stops: [
                    0.0,
                    0.05,
                    0.9,
                    1.0
                  ], // 10% purple, 80% transparent, 10% purple
                ).createShader(rect);
              },
              blendMode: BlendMode.dstOut,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: supplierController.suppliers.length,
                itemBuilder: (_, index) {
                  return CheckboxListTile(
                    visualDensity: VisualDensity.compact,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Preferences.getTheme()
                        ? primaryLightColor
                        : primaryColor,
                    title: Text(
                      supplierController.suppliers[index].name,
                    ),
                    value: localFilterSuppliers
                        .contains(supplierController.suppliers[index].id),
                    onChanged: (value) {
                      setState(
                            () {
                          if (localFilterSuppliers
                              .contains(supplierController.suppliers[index].id)) {
                            localFilterSuppliers.remove(
                              supplierController.suppliers[index].id,
                            );
                          } else {
                            localFilterSuppliers
                                .add(supplierController.suppliers[index].id);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Preferences.getTheme() ? lightGrayColor : borderColor,
                ),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: SecondaryButton(
                    onPressed: () {
                      _boughtController.filterClients.clear();
                      _boughtController.filterSales();
                      Navigator.pop(context);
                    },
                    text: 'reset'.tr,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    text: 'apply'.tr,
                    onPressed: () {
                      _boughtController.setFilterClients(localFilterSuppliers);
                      Navigator.pop(context);
                    },
                  )
                )
              ],
            ),
          )
        ],
      ),
    );
  }





}
