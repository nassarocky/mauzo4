import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/ui/screens/sale/invoice_dual_screen.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/widgets/dashed_seperator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sticky_headers/sticky_headers/widget.dart';
import '../../../controllers/invoice_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../models/client_model.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/buttons/secondary_button.dart';
import '../sale/add_sale_screen.dart';
import '../sale/edit_sale.screen.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({Key? key}) : super(key: key);

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final InvoiceController _invoiceController = Get.find();
  final ClientController _clientController = Get.find();
  final ProductController _productController = Get.find();
  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();

  @override
  void initState() {
    Timer.run(() {
      _invoiceController.setInvoicesByDate();
    });

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    Timer.run(() {
      _invoiceController.clearSelectedDateRange();
      _invoiceController.filterClients.value = [];
      _invoiceController.setInvoiceType('All');
      _invoiceController.filteredInvoices.value = _invoiceController.invoices;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ProfileController _profileController = Get.find();
final bool canEditInvoices = _profileController.hasPermission('edit_invoices');
    return Scaffold(
      backgroundColor: Preferences.getTheme()
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFE5E5E5),
      floatingActionButton: canEditInvoices ? FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DualScreenAppInvoice(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ) : null,
      appBar: AppBar(
        title: Text('all_invoices'.tr),
        elevation: 0,
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
                  _invoiceController.invoices.length !=
                      _invoiceController.filteredInvoices.length
                      ? Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          _invoiceController.filterClients.value = [];
                          _invoiceController.setInvoiceType('All');
                          _invoiceController.clearSelectedDateRange();
                          _invoiceController.filterInvoices();
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
                            _invoiceController.filterClients.length ==
                                _clientController.clients.length ||
                                _invoiceController.filterClients.isEmpty
                                ? 'all_clients'.tr
                                : _invoiceController.filterClients.length == 1
                                ? '${_invoiceController.filterClients.length} ${'client'.tr.toLowerCase()}'
                                : '${_invoiceController.filterClients.length} ${'clients'.tr.toLowerCase()}',
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
                              _invoiceController.setSelectedDateRange(fromRange);
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _invoiceController.selectedDateRange != null
                                ? '${DateFormat('dd/MM/yyyy').format(_invoiceController.selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_invoiceController.selectedDateRange!.end)}'
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
              child: _invoiceController.getDatesCount() == 0
                  ? Center(
                child: Text(
                  'not_found'.tr,
                  style: bodyText(textPlaceholderColor),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 40),
                itemCount: _invoiceController.getDatesCount(),
                itemBuilder: (context, index) {
                  List<Map<String, dynamic>> invoicesByDate = [];

                  for (var i = 0; i < _invoiceController.dates.length; i++) {
                    invoicesByDate.add({
                      'date': _invoiceController.dates[i],
                      'invoices': _invoiceController
                          .getInvoicesByDate(_invoiceController.dates[i]),
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
                                invoicesByDate[index]['invoices'][0]
                                    .date
                                    .toDate()),
                            style: h5(textDarkColor),
                          ),
                        ],
                      ),
                    ),
                    content: Container(
                      padding: const EdgeInsets.only(top: 20, bottom: 10),
                      child: Column(
                        children: List.from(
                          invoicesByDate[index]['invoices'].map(
                                (invoice) {
                              final client = _clientController
                                  .getClient(invoice.client);
                              final time = invoice.date.toDate();

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
                                        if (_profileController.hasPermission('edit_invoices') || _profileController.hasPermission('sale_invoices') || _profileController.hasPermission('delete_invoices'))
                                          PopupMenuButton(
                                          child: Icon(
                                            Icons.more_vert,
                                            color: Preferences.getTheme()
                                                ? primaryLightColor
                                                : primaryColor,
                                            size: 24,
                                          ),
                                          onSelected: (value) {
                                            if (value == 'Sale') {
                                              saleInvoice(invoice, client,
                                                  context, time);
                                            } else if (value == 'Delete') {
                                              _invoiceController.deleteSale(invoice);
                                            } else if (value == 'Edit') {
                                              editInvoice(invoice, client,
                                                  context, time);
                                            }
                                          },
                                          itemBuilder: (BuildContext context) =>
                                          <PopupMenuEntry<String>>[
                                            if (invoice.frominvoice == false && _profileController.hasPermission('edit_invoices'))
                                              PopupMenuItem<String>(
                                                value: 'Edit',
                                                child: Text(
                                                  'edit'.tr,
                                                  style: bodyText(
                                                    Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color,
                                                  ),
                                                ),
                                              ),
                                            if (invoice.frominvoice == false && _profileController.hasPermission('sale_invoices'))
                                              PopupMenuItem<String>(
                                                value: 'Sale',
                                                child: Text(
                                                  'sale_invoice'.tr,
                                                  style: bodyText(
                                                    Theme.of(context)
                                                        .textTheme
                                                        .bodyLarge!
                                                        .color,
                                                  ),
                                                ),
                                              ),
                                            if (_profileController.hasPermission('delete_invoices'))
                                              PopupMenuItem<String>(
                                                value: 'Delete',
                                                child: Text(
                                                  'delete'.tr,
                                                  style: bodyText(redColor),
                                                ),
                                              ),
                                          ],
                                        ),
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
                                          invoice.client == ''
                                              ? invoice.clientname
                                              : _clientController
                                              .getClient(invoice.client)
                                              .id ==
                                              ''
                                              ? invoice.clientname
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
                                    i < invoice.products.length;
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
                                                CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    invoice.products[i]['name'],
                                                    style: bodyText(
                                                      Theme.of(context)
                                                          .textTheme
                                                          .bodyLarge!
                                                          .color,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '${invoice.products[i]['quantity']} * ${formatCurrency(
                                                            invoice.products[i]
                                                            ['price'],
                                                            _businessController
                                                                .business[
                                                            'mainCurrency'],
                                                          )}',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                            FontWeight.w400,
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
                                                          invoice.products[i]
                                                          ['quantity'] *
                                                              invoice.products[i]
                                                              ['price'],
                                                          _businessController
                                                              .business[
                                                          'mainCurrency'],
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                          FontWeight.w400,
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
                                            printInvoice(invoice, client);
                                          },
                                          icon: const Icon(Icons.print),
                                          label: Text('print'.tr),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            shareInvoice(invoice, client);
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
                                            '${'total'.tr}: ${formatCurrency(invoice.price, _businessController.business['mainCurrency'])}',
                                            style: h6(Theme.of(context)
                                                .textTheme
                                                .bodyLarge!
                                                .color),
                                          ),
                                          invoice.discount > 0
                                              ? Text(
                                            '${'discount'.tr}: ${formatCurrency(invoice.discount, _businessController.business['mainCurrency'])}',
                                            style: bodyText(
                                              Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium!
                                                  .color,
                                            ),
                                          )
                                              : const SizedBox(),
                                          invoice.frominvoice == true
                                              ? Text(
                                            'sold'.tr,
                                            style: bodyText(greenColor),
                                          )
                                              : Text(
                                            'Not sold'.tr,
                                            style: bodyText(redColor),
                                          ),
                                          invoice.debt > 0
                                              ? Text(
                                            '${'debt'.tr}: ${formatCurrency(invoice.debt, _businessController.business['mainCurrency'])}',
                                            style: bodyText(redColor),
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

  Future<pw.Document> _generateInvoice(dynamic invoice, Client client) async {
    final pdf = pw.Document();
    final currency = _businessController.business['mainCurrency'];
    final dateTime = invoice.date.toDate();

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
                        _businessController.business['name'] ?? _businessController.business['business'],
                        style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text('Phone: ${_businessController.business['phone']}', style: pw.TextStyle(fontSize: 14)),
                      if (_businessController.business['tin'] != null && _businessController.business['tin'] != '')
                        pw.Text('TIN: ${_businessController.business['tin']}', style: pw.TextStyle(fontSize: 14)),
                    ],
                  ),
                  logoWidget,
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),

              // Transaction Info
              pw.Text(
                'Invoice',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice #: ${DateFormat('yyyyMMddHHmm').format(dateTime)}', style: pw.TextStyle(fontSize: 12)),
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
                  //  if (invoice.debt > 0)
                 //     pw.Text('Debt: ${formatCurrency(invoice.debt, currency)}', style: pw.TextStyle(fontSize: 12)),
                  //  if (invoice.payment > 0)
                    //  pw.Text('Paid: ${formatCurrency(invoice.payment, currency)}', style: pw.TextStyle(fontSize: 12)),
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

  Future<void> printInvoice(dynamic invoice, Client client) async {
    final pdf = await _generateInvoice(invoice, client);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> shareInvoice(dynamic invoice, Client client) async {
    final pdf = await _generateInvoice(invoice, client);

    final output = await getTemporaryDirectory();
    final file = File("${output.path}/invoice.pdf");
    await file.writeAsBytes(await pdf.save());
    final result = await Share.shareXFiles(
      [XFile("${output.path}/invoice.pdf")],
      text: 'Invoice Report',
    );

    if (result.status == ShareResultStatus.success) {
      print('Thank you for sharing the report!');
    } else if (result.status == ShareResultStatus.dismissed) {
      print('Share dismissed');
    }
  }

  void saleInvoice(dynamic invoice, Client client, BuildContext context, dynamic time) {
    List<Product> products = [];
    for (final product in invoice.products) {
      if (_productController.getProduct(product['id']).id == '') {
        products.add(
          Product(
            id: product['id'],
            name: product['name'],
            price: product['price'],
            count: product['count'],
            discount: product['discount'],
            quantity: 1,
            code: '',
            owner: '',
          ),
        );
      } else {
        Product pr = _productController.getProduct(product['id']);
        products.add(pr);
      }
    }
    _cartController.client = client;

    _cartController.setDiscount(invoice.discount);
    _cartController.clearPayments();
    if (invoice.payments.isNotEmpty) {
      for (final p in invoice.payments) {
        final double amt = (p['amount'] is int)
            ? (p['amount'] as int).toDouble()
            : (p['amount'] as num?)?.toDouble() ?? 0.0;
        if (amt <= 0) continue;
        final String currency = (p['currency'] ?? _businessController.business['mainCurrency']).toString();
        final String method = (p['method'] ?? 'cash').toString();
        _cartController.addPayment(amt, currency, method: method);
      }
    } else if (invoice.payment > 0) {
      _cartController.addPayment(
        (invoice.payment is int) ? (invoice.payment as int).toDouble() : invoice.payment,
        _businessController.business['mainCurrency'],
      );
    }

    _cartController.setComment(invoice.comment);
    _cartController.setProducts(products, invoice.products);
    _cartController.passedArgument = invoice.id;

    Navigator.pushNamed(context, '/cart');
  }

  void editInvoice(dynamic invoice, Client client, BuildContext context, dynamic time) {
    List<Product> products = [];

    for (final product in invoice.products) {
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

    _cartController.client = client;
    _cartController.setDiscount(invoice.discount);

    if (invoice.payment > 0) {
      _cartController.addPayment(
        invoice.payment,
        _businessController.business['mainCurrency'],
      );
    }

    _cartController.setComment(invoice.comment);
    _cartController.setProducts(products, invoice.products);
    _cartController.passedArgument = invoice.id;
    _cartController.editInvoice = 'edit';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DualScreenAppInvoice(),
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
  final InvoiceController _invoiceController = Get.find();

  @override
  void initState() {
    localFilterClients = [..._invoiceController.filterClients];
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
                    activeColor: Preferences.getTheme() ? primaryLightColor : primaryColor,
                    title: Text(
                      clientController.clients[index].name,
                    ),
                    value: localFilterClients.contains(clientController.clients[index].id),
                    onChanged: (value) {
                      setState(
                            () {
                          if (localFilterClients.contains(clientController.clients[index].id)) {
                            localFilterClients.remove(
                              clientController.clients[index].id,
                            );
                          } else {
                            localFilterClients.add(clientController.clients[index].id);
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
                      _invoiceController.filterClients.clear();
                      _invoiceController.filterInvoices();
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
                      _invoiceController.setFilterClients(localFilterClients);
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