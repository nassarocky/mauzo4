import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/ui/screens/cart_screen.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/screens/sale/edit_sale.screen.dart';
import 'package:mauzo/ui/widgets/dashed_seperator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import '../../../controllers/profile_controller.dart';
import '../../../controllers/sale_controller.dart';
import '../../../models/product_model.dart';
import '../../../models/sale_model.dart';
import '../../../utils/constants.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';

import 'edit_sale_screen2.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({Key? key}) : super(key: key);

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final SaleController _saleController = Get.find();
  final ClientController _clientController = Get.find();
  final ProductController _productController = Get.find();
  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  @override
  void initState() {
    Timer.run(() {
      _saleController.setSalesByDate();
    });

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    Timer.run(() {
      _saleController.selectedDateRange=DateTimeRange(
        start: DateTime.now().subtract(Duration(days: 30)), // 30 days back
        end: DateTime.now(), // Today
      );
      _saleController.filterClients.value = [];
      _saleController.setSaleType('All');
      _saleController.filteredSales.value = _saleController.sales;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool canMakeSales = _profileController.hasPermission('make_sales');

    return Scaffold(
      backgroundColor: Preferences.getTheme()
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFE5E5E5),
      floatingActionButton: canMakeSales ? FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/sale/add');
        },
        child: const Icon(Icons.add),
      ) : null,
      appBar: AppBar(
        title: Text(
          'all_sales'.tr,
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
        actions: [
          if(canMakeSales)
            IconButton(
              icon: Image.asset(
                'assets/images/excel.png',
                width: 24,
                height: 24,
              ),
              onPressed: () {
                _saleController.generateExcelFromSales();
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
                  _saleController.sales.length !=
                      _saleController.filteredSales.length
                      ? Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _saleController.filterClients.value = [];
                          _saleController.setSaleType('All');
                          _saleController.clearSelectedDateRange();
                          _saleController.filterSales();
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
                            _saleController.filterClients.length ==
                                _clientController.clients.length ||
                                _saleController.filterClients.isEmpty
                                ? 'all_clients'.tr
                                : _saleController.filterClients.length == 1
                                ? '${_saleController.filterClients.length} ${'client'.tr.toLowerCase()}'
                                : '${_saleController.filterClients.length} ${'clients'.tr.toLowerCase()}',
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
                      if (canMakeSales)
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
                                _saleController.setSelectedDateRange(fromRange);
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
                            _saleController.selectedDateRange != null
                                ? '${DateFormat('dd/MM/yyyy').format(_saleController.selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_saleController.selectedDateRange!.end)}'
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
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('payment'.tr),
                          contentPadding: const EdgeInsets.all(16),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RadioListTile(
                                contentPadding: EdgeInsets.zero,
                                value: 'All',
                                title: Text("all".tr),
                                groupValue: _saleController.saleType.value,
                                activeColor: Preferences.getTheme()
                                    ? primaryLightColor
                                    : primaryColor,
                                onChanged: (String? value) {
                                  _saleController.setSaleType(value!);
                                  Navigator.pop(context);
                                },
                              ),
                              RadioListTile(
                                contentPadding: EdgeInsets.zero,
                                value: 'Debt',
                                title: Text("debt".tr),
                                groupValue: _saleController.saleType.value,
                                activeColor: Preferences.getTheme()
                                    ? primaryLightColor
                                    : primaryColor,
                                onChanged: (String? value) {
                                  _saleController.setSaleType(value!);
                                  Navigator.pop(context);
                                },
                              )
                            ],
                          ),
                        ),
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
                            _saleController.saleType.value == 'All'
                                ? 'all_sales'.tr
                                : 'debt'.tr,
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
              child: _saleController.getDatesCount() == 0
                  ? Center(
                child: Text(
                  'not_found'.tr,
                  style: bodyText(textPlaceholderColor),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: _saleController.getDatesCount(),
                itemBuilder: (context, index) {
                  List<Map<String, dynamic>> salesByDate = [];

                  for (var i = 0; i < _saleController.dates.length; i++) {
                    salesByDate.add({
                      'date': _saleController.dates[i],
                      'sales': _saleController
                          .getSalesByDate(_saleController.dates[i]),
                    });
                  }

                  return StickyHeader(
                    header: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      width: double.maxFinite,
                      height: 48,
                      color: (canMakeSales || _businessController.business['allowSalesView'])
                          ? const Color(0xFFFFEA9F)
                          : const Color(0xFFE5E5E5),
                      child: Row(
                        children: [
                          if(canMakeSales || _businessController.business['allowSalesView'])
                            Text(
                              DateFormat("dd.MM.yyyy", 'en_US').format(
                                  salesByDate[index]['sales'][0]
                                      .date
                                      .toDate()),
                              style: h5(textDarkColor),
                            ),
                          const Spacer(),
                          if(canMakeSales || _businessController.business['allowSalesView'])
                            Text(
                              '${'total'.tr}: ${formatCurrency(_saleController.getTotalSalesByDate(
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

                              // Build a compact list of unique payment method labels (Cash, Bank, Mobile)
                              final String methodsText = (() {
                                if (sale.payments.isEmpty) return '';
                                final labels = <String>{};
                                for (final p in sale.payments) {
                                  final String method = (p['method'] ?? 'cash').toString();
                                  final String label = method == 'bank'
                                      ? 'Bank'
                                      : method == 'mobile'
                                          ? 'Mobile'
                                          : 'Cash';
                                  labels.add(label);
                                }
                                return labels.join(', ');
                              })();

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
                                        if ((_profileController.hasPermission('edit_sales') || _profileController.hasPermission('delete_sales')) && sale.debt == 0.0 && sale.products.isNotEmpty && sale.payment != 0.0)

                                          PopupMenuButton(
                                            child: Icon(
                                              Icons.more_vert,
                                              color: Preferences.getTheme() ? primaryLightColor : primaryColor,
                                              size: 24,
                                            ),
                                            onSelected: (value) {
                                              if (value == 'Delete') {
                                                _saleController.deleteSale(sale);
                                              } else if (value ==
                                                  'Edit') {
                                                editInvoice(sale, client,
                                                    context, time);
                                              }
                                            },
                                            itemBuilder: (BuildContext context) =>
                                            <PopupMenuEntry<String>>[
                                              if (_profileController.hasPermission('delete_sales'))
                                                PopupMenuItem<String>(
                                                  value: 'Delete',
                                                  child: Text(
                                                    'delete'.tr,
                                                    style: bodyText(redColor),
                                                  ),
                                                ),
                                              if (_profileController.hasPermission('edit_sales'))
                                                PopupMenuItem<String>(
                                                  value: 'Edit',
                                                  child: Text(
                                                    'edit'.tr,
                                                    style: bodyText(redColor),
                                                  ),
                                                )
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
                                              ? sale.clientname
                                              : _clientController
                                              .getClient(
                                              sale.client)
                                              .id ==
                                              ''
                                              ? sale.clientname
                                              : client.name,
                                          style: bodyText(
                                              Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .color),
                                        ),
                                      ],
                                    ),
                                    if (sale.products.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      const DashedSeperator(),
                                      const SizedBox(height: 12),
                                      for (var i = 0; i < sale.products.length; i++)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      sale.products[i]['name'],
                                                      style: bodyText(
                                                        Theme.of(context).textTheme.bodyLarge!.color,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            '${sale.products[i]['quantity']} * ${formatCurrency(
                                                              (sale.products[i]['price'] is int) 
                                                                ? (sale.products[i]['price'] as int).toDouble() 
                                                                : sale.products[i]['price'],
                                                              _businessController.business['mainCurrency'],
                                                            )}',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.w400,
                                                              color: Theme.of(context).textTheme.bodyMedium!.color,
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
                                                            fontWeight: FontWeight.w400,
                                                            color: Theme.of(context).textTheme.bodyMedium!.color,
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
                                    ],

                                    const SizedBox(height: 12),
                                    // Payment chips removed to reduce height; methods are shown inline with amount below
                                    SizedBox(
                                      width: double.infinity,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          sale.price > 0
                                              ? Text(
                                            '${'total'.tr}: ${formatCurrency(
                                              (sale.price is int) ? (sale.price as int).toDouble() : sale.price,
                                              _businessController.business['mainCurrency']
                                            )}',
                                            style: h6(Theme.of(context).textTheme.bodyLarge!.color),
                                          )
                                              : Text(
                                            'Debt repayment'.tr,
                                            style: h6(Theme.of(context).textTheme.bodyLarge!.color),
                                          ),

                                          sale.discount > 0
                                              ? Text(
                                            '${'discount'.tr}: ${formatCurrency(
                                              (sale.discount is int) ? (sale.discount as int).toDouble() : sale.discount,
                                              _businessController.business['mainCurrency']
                                            )}',
                                            style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                                          )
                                              : const SizedBox(),

                                          // Bottom summary row: payment methods on the left, amount/status on the right
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: methodsText.isNotEmpty
                                                    ? Text(
                                                        methodsText,
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
                                          ),

                                          sale.employeeId != null
                                              ? Text(
                                            '${'processed by'.tr}: ${sale.employeeName}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: Theme.of(context).textTheme.bodyMedium!.color,
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

  Future<pw.Document> _generateReceipt(Sale invoice, Client client) async {
    final pdf = pw.Document();
    final currency = _businessController.business['mainCurrency'];
    final dateTime = invoice.date.toDate();

    // Log the logo URL to verify it exists
    print('Logo URL: ${_businessController.business['logo']}');

    // Load the logo if available, ensuring a non-null widget is always returned
    pw.Widget logoWidget;
    if (_businessController.business['logo'] != null && _businessController.business['logo'] != '') {
      try {
        final netImage = await networkImage(_businessController.business['logo']);
        print('Logo loaded successfully');
        logoWidget = pw.Image(netImage, width: 50, height: 50);
      } catch (e) {
        print('Error loading logo: $e');
        logoWidget = pw.Container(
          width: 50,
          height: 50,
          child: pw.Center(
            child: pw.Text('No Logo', style: pw.TextStyle(fontSize: 10)),
          ),
        );
      }
    } else {
      print('No logo URL provided');
      logoWidget = pw.Container(
        width: 50,
        height: 50,
        child: pw.Center(
          child: pw.Text('No Logo', style: pw.TextStyle(fontSize: 10)),
        ),
      );
    }

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Header with Business Info on the Left and Logo on the Right
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _businessController.business['name'],
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Phone: ${_businessController.business['phone']}', style: pw.TextStyle(fontSize: 14)),
                      if (_businessController.business['tin'] != null && _businessController.business['tin'] != '')
                        pw.Text('TIN: ${_businessController.business['tin']}', style: pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                  logoWidget, // Now safe to use since logoWidget is non-nullable
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),

              // Transaction Info
              pw.Text(
                'Receipt',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Receipt #: ${DateFormat('yyyyMMddHHmm').format(dateTime)}', style: pw.TextStyle(fontSize: 12)),
                  pw.Text(
                    '${DateFormat('yyyy-MM-dd').format(dateTime)} ${DateFormat('HH:mm').format(dateTime)}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Client: ${client.name}', style: pw.TextStyle(fontSize: 12)),
                  if (invoice.employeeId != null && invoice.employeeName != null)
                    pw.Text('Served by: ${invoice.employeeName}', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),

              // Itemized List
              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: pw.FractionColumnWidth(0.4), // Product Name
                  1: pw.FractionColumnWidth(0.2), // Quantity
                  2: pw.FractionColumnWidth(0.2), // Price
                  3: pw.FractionColumnWidth(0.2), // Total
                },
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Product', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Qty', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Price', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Total ($currency)', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                  ...invoice.products.map<pw.TableRow>((product) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(product['name'], style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.left),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(product['quantity'].toString(), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(formatCurrency(product['price'], currency), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(formatCurrency(product['quantity'] * product['price'], currency), style: pw.TextStyle(fontSize: 10), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    );
                  }).toList(),
                ],
              ),

              // Summary
              pw.SizedBox(height: 10),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ${formatCurrency(invoice.price + invoice.discount, currency)}', style: pw.TextStyle(fontSize: 12)),
                    if (invoice.discount > 0)
                      pw.Text('Discount: ${formatCurrency(invoice.discount, currency)}', style: pw.TextStyle(fontSize: 12)),
                    pw.Divider(),
                    pw.Text('Total: ${formatCurrency(invoice.price, currency)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    if (invoice.debt > 0)
                      pw.Text('Debt: ${formatCurrency(invoice.debt, currency)}', style: pw.TextStyle(fontSize: 12)),
                    if (invoice.payment > 0)
                      pw.Text('Paid: ${formatCurrency(invoice.payment, currency)}', style: pw.TextStyle(fontSize: 12)),
                  ],
                ),
              ),

              // Footer
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic)),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }
  Future<void> printInvoice(Sale invoice, Client client) async {
    final pdf = await _generateReceipt(invoice, client);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> shareInvoice(Sale invoice, Client client) async {
    final pdf = await _generateReceipt(invoice, client);

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/sales.pdf");
    await file.writeAsBytes(await pdf.save());

    final result = await Share.shareXFiles(
      [XFile("${output.path}/sales.pdf")],
      text: 'Sales Receipt',
    );

    if (result.status == ShareResultStatus.success) {
      print('Thank you for sharing the receipt!');
    } else if (result.status == ShareResultStatus.dismissed) {
      print('Share dismissed');
    }
  }

  void editInvoice(Sale sale, Client client, BuildContext context, time) {
    List<Product> products = [];

    for (final product in sale.products) {
      Product existingProduct = _productController.getProduct(product['id']);

      if (existingProduct.id == '') {
        print('⚠️ Product not found in _productController');
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
        print('✅ Product found: ${existingProduct.name}');
        existingProduct.count = (product['quantity'] as num).toDouble();
        products.add(existingProduct);
      }

      print('🔢 Product ID: ${product['id']}, Quantity from sale: ${product['quantity']}');
    }

    _cartController.client = client;
    _cartController.setDiscount(sale.discount);
    _cartController.clearPayments();
    if (sale.payments.isNotEmpty) {
      for (final p in sale.payments) {
        final double amt = (p['amount'] is int)
            ? (p['amount'] as int).toDouble()
            : (p['amount'] as num?)?.toDouble() ?? 0.0;
        if (amt <= 0) continue;
        final String currency = (p['currency'] ?? _businessController.business['mainCurrency']).toString();
        final String method = (p['method'] ?? 'cash').toString();
        _cartController.addPayment(amt, currency, method: method);
      }
    } else if (sale.payment > 0) {
      _cartController.addPayment(
        (sale.payment is int) ? (sale.payment as int).toDouble() : sale.payment,
        _businessController.business['mainCurrency'],
      );
    }

    _cartController.setComment(sale.comment);
    _cartController.setProducts(products, sale.products);

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => EditSaleScreen2(
          sale: sale,
          title: ('${'sale'.tr} ${DateFormat("dd.MM.yyyy", 'en_US').format(time)} ${DateFormat("hh:mm a", 'en_US').format(time)}'),
        ),
      ),
    );
  }

  void editSale(Sale sale, Client client, BuildContext context, DateTime time) {
    List<Product> products = [];

    for (final product in sale.products) {
      Product existingProduct = _productController.getProduct(product['id']);

      if (existingProduct.id == '') {
        products.add(
          Product(
            id: product['id'],
            name: product['name'],
            price: product['price'],
            discount: product['discount'],
            quantity: (product['quantity'] as num).toDouble(),
            code: '',
            owner: '',
          ),
        );
      } else {
        existingProduct.quantity = (product['quantity'] as num).toDouble();
        products.add(existingProduct);
      }
    }

    _cartController.client = client;

    _cartController.setDiscount(sale.discount);
    _cartController.clearPayments();
    if (sale.payments.isNotEmpty) {
      for (final p in sale.payments) {
        final double amt = (p['amount'] is int)
            ? (p['amount'] as int).toDouble()
            : (p['amount'] as num?)?.toDouble() ?? 0.0;
        if (amt <= 0) continue;
        final String currency = (p['currency'] ?? _businessController.business['mainCurrency']).toString();
        final String method = (p['method'] ?? 'cash').toString();
        _cartController.addPayment(amt, currency, method: method);
      }
    } else if (sale.payment > 0) {
      _cartController.addPayment(
        (sale.payment is int) ? (sale.payment as int).toDouble() : sale.payment,
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
  final SaleController _saleController = Get.find();

  @override
  void initState() {
    localFilterClients = [..._saleController.filterClients];
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
                  ],
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
                      _saleController.filterClients.clear();
                      _saleController.filterSales();
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
                      _saleController.setFilterClients(localFilterClients);
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