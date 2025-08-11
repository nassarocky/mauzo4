import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/screens/sale/edit_sale.screen.dart';
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

class BoughtScreen extends StatefulWidget {
  const BoughtScreen({Key? key}) : super(key: key);

  @override
  State<BoughtScreen> createState() => _boughtControllerState();
}

class _boughtControllerState extends State<BoughtScreen> {
  final BoughtController _boughtController = Get.find();
  final ClientController _clientController = Get.find();
  final ProductController _productController = Get.find();
  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  @override
  void initState() {
    super.initState();
    
    // CRITICAL SECURITY CHECK: Verify user has permission to buy products
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
    
    Timer.run(() {
      _boughtController.setSalesByDate();
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

    return Scaffold(
      backgroundColor: Preferences.getTheme()
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFE5E5E5),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/buy');
        },
        child: const Icon(Icons.add),
      ),
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
                          return const SelectClientsBottomSheet();
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
                                _clientController.clients.length ||
                                _boughtController.filterClients.isEmpty
                                ? 'all_clients'.tr
                                : _boughtController.filterClients.length == 1
                                ? '${_boughtController.filterClients.length} ${'client'.tr.toLowerCase()}'
                                : '${_boughtController.filterClients.length} ${'clients'.tr.toLowerCase()}',
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
                            '${'total'.tr}: ${formatCurrency(_boughtController.getTotalSalesByDate(
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
                              final client = _clientController
                                  .getClient(sale.client);
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
                                        if (sale.debt == 0 && canViewPurchases)
                                          PopupMenuButton(
                                            child: Icon(
                                              Icons.more_vert,
                                              color: Preferences.getTheme() ? primaryLightColor : primaryColor,
                                              size: 24,
                                            ),
                                            onSelected: (value) {
                                              if (value == 'Delete') {
                                                _boughtController.deleteSale(sale);
                                              }
                                            },
                                            itemBuilder: (BuildContext context) =>
                                            <PopupMenuEntry<String>>[
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
                                          sale.client == ''
                                              ? 'unnamed_client'.tr
                                              : _clientController
                                              .getClient(
                                              sale.client)
                                              .id ==
                                              ''
                                              ? 'unnamed_client'.tr
                                              : client.name,
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
                                            printInvoice(sale, client);
                                          },
                                          icon: const Icon(Icons.print),
                                          label: Text('print'.tr),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            shareInvoice(sale, client);
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
                                          sale.payment == sale.price
                                              ? Text(
                                            'paid'.tr,
                                            style: bodyText(
                                              greenColor,
                                            ),
                                          )
                                              : sale.payment > 0
                                              ? Text(
                                            '${'paid'.tr}: ${formatCurrency(sale.payment, _businessController.business['mainCurrency'])}',
                                            style: bodyText(
                                              greenColor,
                                            ),
                                          )
                                              : const SizedBox(),
                                          sale.debt > 0
                                              ? Text(
                                            '${'debt'.tr}: ${formatCurrency(sale.debt, _businessController.business['mainCurrency'])}',
                                            style: bodyText(
                                              redColor,
                                            ),
                                          )           : const SizedBox(),
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

  Future<void> printInvoice(invoice, Client client) async {
    final pdf = pw.Document();
    final currency = _businessController.business['mainCurrency'];

    pdf.addPage(
      pw.Page(
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
                      pw.Text('Client: ${client.name}', style: pw.TextStyle(fontSize: 18)),
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
                    return pw.TableRow(
                      children: [
                        pw.Text(product['name'], textAlign: pw.TextAlign.center),
                        pw.Text(product['quantity'].toString(), textAlign: pw.TextAlign.center),
                        pw.Text(product['price'].toString(), textAlign: pw.TextAlign.center),
                        pw.Text((product['quantity'] * product['price']).toString(), textAlign: pw.TextAlign.center),
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

  Future<void> shareInvoice(invoice, Client client) async {
    final pdf = pw.Document();
    final currency = _businessController.business['mainCurrency'];

    pdf.addPage(
      pw.Page(
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
                      pw.Text('Client: ${client.name}', style: pw.TextStyle(fontSize: 18)),
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
                    return pw.TableRow(
                      children: [
                        pw.Text(product['name'], textAlign: pw.TextAlign.center),
                        pw.Text(product['quantity'].toString(), textAlign: pw.TextAlign.center),
                        pw.Text(product['price'].toString(), textAlign: pw.TextAlign.center),
                        pw.Text((product['quantity'] * product['price']).toString(), textAlign: pw.TextAlign.center),
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

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/invoice.pdf");
    await file.writeAsBytes(await pdf.save());

    final result = await Share.shareXFiles(
      [XFile("${output.path}/invoice.pdf")],
      text: 'Product in Store Report',
    );

    // Optionally, handle the result status
    if (result.status == ShareResultStatus.success) {
      print('Thank you for sharing the report!');
    } else if (result.status == ShareResultStatus.dismissed) {
      print('Share dismissed');
    }
  }



  void editSale(sale, Client client, BuildContext context, time) {
    List<Product> products = [];
    for (final product in sale.products) {
      for (int quantity = 0; quantity < product['quantity']; quantity++) {
        if (_productController.getProduct(product['id']).id == '') {
          products.add(
            Product(
              id: product['id'],
              name: product['name'],
              price: product['price'],
              discount: product['discount'],
              quantity: 1,
              code: '',
              owner: '',
            ),
          );
        } else {
          products.add(_productController.getProduct(product['id']));
        }
      }
    }
    _cartController.client = client;

    _cartController.setDiscount(sale.discount);
    if (sale.payment > 0) {
      _cartController.addPayment(
        sale.payment,
        _businessController.business['mainCurrency'],
      );
    }

    _cartController.setComment(sale.comment);
    _cartController.setProducts(products, sale.products);

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => EditSaleScreen(
          sale: sale,
          title:
          ('${'sale'.tr} ${DateFormat("dd.MM.yyyy", 'en_US').format(time)} ${DateFormat("hh:mm a", 'en_US').format(time)}'),
        ),
      ),
    );
  }
}

class SelectClientsBottomSheet extends StatefulWidget {
  const SelectClientsBottomSheet({Key? key}) : super(key: key);

  @override
  State<SelectClientsBottomSheet> createState() =>
      _SelectClientsBottomSheetState();
}

class _SelectClientsBottomSheetState extends State<SelectClientsBottomSheet> {
  List<String> localFilterClients = [];
  final BoughtController _boughtController = Get.find();

  @override
  void initState() {
    localFilterClients = [..._boughtController.filterClients];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final ClientController clientController = Get.find();
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'clients'.tr,
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
                itemCount: clientController.clients.length,
                itemBuilder: (_, index) {
                  return CheckboxListTile(
                    visualDensity: VisualDensity.compact,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Preferences.getTheme()
                        ? primaryLightColor
                        : primaryColor,
                    title: Text(
                      clientController.clients[index].name,
                    ),
                    value: localFilterClients
                        .contains(clientController.clients[index].id),
                    onChanged: (value) {
                      setState(
                            () {
                          if (localFilterClients
                              .contains(clientController.clients[index].id)) {
                            localFilterClients.remove(
                              clientController.clients[index].id,
                            );
                          } else {
                            localFilterClients
                                .add(clientController.clients[index].id);
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
                      _boughtController.setFilterClients(localFilterClients);
                      Navigator.pop(context);
                    },
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }





}
