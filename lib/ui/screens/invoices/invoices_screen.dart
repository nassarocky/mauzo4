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
import 'package:mauzo/ui/screens/invoices/invoice_payment_settings_screen.dart';
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
import '../../../models/sale_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../utils/download_helper.dart';
import '../../../utils/receipt_footer.dart';
import '../../../services/sms_reminder_service.dart';
import '../../../utils/sms_settings.dart';
import '../../../utils/sms_phone.dart';
import '../../widgets/dialogs/sms_recipient_dialog.dart';

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
  final ProfileController _profileController = Get.find();

  @override
  void initState() {
    super.initState();

    Timer.run(() {
      _invoiceController.setInvoicesByDate();
    });
  }

  @override
  void dispose() {
    super.dispose();
    Timer.run(() {
      // Clear filters to use default reset time loading
      _invoiceController.clearSelectedDateRange();
      _invoiceController.filterClients.value = [];
      _invoiceController.setInvoiceType('All');
    });
  }

  @override
  Widget build(BuildContext context) {
    final ProfileController _profileController = Get.find();
    final bool canCreateInvoices = _profileController.hasPermission('create_invoices');
    final bool canEditInvoices = _profileController.hasPermission('edit_invoices');
    return Scaffold(
      backgroundColor: Preferences.getTheme()
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFE5E5E5),
      floatingActionButton: canCreateInvoices ? FloatingActionButton(
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
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Invoice Payment Settings',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InvoicePaymentSettingsScreen(),
              ),
            ),
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

                  // Skip if invoices list is empty (after deletion)
                  if (invoicesByDate[index]['invoices'].isEmpty) {
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
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            printInvoice(invoice, client);
                                          },
                                          icon: const Icon(Icons.print),
                                          label: Text('print'.tr),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            shareInvoice(invoice, client);
                                          },
                                          icon: const Icon(Icons.share),
                                          label: Text('share'.tr),
                                        ),
                                        if (_profileController.hasPermission('share_invoices') ||
                                            _profileController.hasPermission('send_debt_sms') ||
                                            _profileController.user['role'] == 'owner' ||
                                            _profileController.user['role'] == 'manager')
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              sendInvoiceSms(invoice, client);
                                            },
                                            icon: const Icon(Icons.sms_outlined),
                                            label: Text('sms_send_invoice'.tr),
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

  Future<String?> _pickDocumentType() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('document_type'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text('invoice_document'.tr),
              onTap: () => Navigator.pop(ctx, 'invoice'),
            ),
            ListTile(
              leading: const Icon(Icons.request_quote_outlined),
              title: Text('quotation'.tr),
              onTap: () => Navigator.pop(ctx, 'quotation'),
            ),
          ],
        ),
      ),
    );
  }

  Future<pw.Document> _generateInvoice(
    dynamic invoice,
    Client client, {
    String documentType = 'invoice',
  }) async {
    final pdf = pw.Document();
    final currency = (_businessController.business['mainCurrency'] ?? 'TZS').toString();
    final dateTime = invoice.date.toDate();
    final business = _businessController.business;
    final isQuotation = documentType == 'quotation';
    final titleLabel = isQuotation ? 'QUOTATION' : 'INVOICE';
    final detailsLabel =
        isQuotation ? 'quotation_details'.tr : 'invoice_details'.tr;
    final numberLabel =
        isQuotation ? 'quotation_number'.tr : 'invoice_number'.tr;

    // Enabled payment details
    final List<Map<String, dynamic>> paymentDetails =
        List<Map<String, dynamic>>.from(
      (business['invoicePaymentDetails'] as List? ?? [])
          .where((e) =>
              paymentDetailShowsOnInvoice(paymentDetailMapFromFirestore(e)))
          .map((e) => paymentDetailMapFromFirestore(e)),
    );

    // Resolve client name
    final clientName = client.name.isNotEmpty
        ? client.name
        : (invoice.clientname?.toString().isNotEmpty == true
            ? invoice.clientname.toString()
            : 'N/A');

    // Load logo
    pw.Widget logoWidget = pw.SizedBox(width: 60, height: 60);
    if (business['logo'] != null && business['logo'].toString().isNotEmpty) {
      try {
        final netImage = await networkImage(business['logo'].toString());
        logoWidget =
            pw.Image(netImage, width: 60, height: 60, fit: pw.BoxFit.contain);
      } catch (_) {}
    }

    // Totals
    final subtotal = (invoice.price + invoice.discount) as double;
    final discount = (invoice.discount ?? 0.0) as double;
    final total = (invoice.price ?? 0.0) as double;
    final debt = (invoice.debt ?? 0.0) as double;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 36),
        build: (context) => [
          // ── HEADER ─────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      business['name']?.toString() ??
                          business['business']?.toString() ?? '',
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    if ((business['phone'] ?? '').toString().isNotEmpty)
                      pw.Text('Phone: ${business['phone']}',
                          style: const pw.TextStyle(fontSize: 10)),
                    if ((business['tin'] ?? '').toString().isNotEmpty)
                      pw.Text('TIN: ${business['tin']}',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              logoWidget,
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(thickness: 1.5),

          // ── INVOICE TITLE BAR ───────────────────────────────────
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 7),
            color: PdfColors.grey800,
            child: pw.Center(
              child: pw.Text(
                titleLabel,
                style: pw.TextStyle(
                  fontSize: 15,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 16),

          // ── INVOICE DETAILS + BILL TO ───────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(detailsLabel,
                        style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                        '$numberLabel: ${DateFormat('yyyyMMddHHmm').format(dateTime)}',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                        'Date: ${DateFormat('dd/MM/yyyy').format(dateTime)}',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Time: ${DateFormat('HH:mm').format(dateTime)}',
                        style: const pw.TextStyle(fontSize: 10)),
                    if (invoice.employeeName != null &&
                        invoice.employeeName.toString().isNotEmpty)
                      pw.Text('Served by: ${invoice.employeeName}',
                          style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Bill To:',
                          style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700)),
                      pw.SizedBox(height: 4),
                      pw.Text(clientName,
                          style: pw.TextStyle(
                              fontSize: 13,
                              fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── ITEMS TABLE ─────────────────────────────────────────
          pw.Table(
            border: pw.TableBorder.all(
                color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FixedColumnWidth(28),
              1: pw.FlexColumnWidth(3.5),
              2: pw.FlexColumnWidth(1),
              3: pw.FlexColumnWidth(1.8),
              4: pw.FlexColumnWidth(1.8),
            },
            children: [
              pw.TableRow(
                decoration:
                    const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _tableHeader('#'),
                  _tableHeader('Product'),
                  _tableHeader('Qty'),
                  _tableHeader('Unit Price'),
                  _tableHeader('Total ($currency)'),
                ],
              ),
              ...invoice.products
                  .asMap()
                  .entries
                  .map<pw.TableRow>((entry) {
                final i = entry.key as int;
                final product =
                    entry.value as Map<String, dynamic>;
                final qty =
                    (product['quantity'] ?? 0).toDouble();
                final price =
                    (product['price'] ?? 0.0).toDouble();
                return pw.TableRow(
                  children: [
                    _tableCell('${i + 1}',
                        align: pw.TextAlign.center),
                    _tableCell(
                        product['name']?.toString() ?? '',
                        align: pw.TextAlign.left),
                    _tableCell(
                        qty % 1 == 0
                            ? qty.toStringAsFixed(0)
                            : qty.toStringAsFixed(1),
                        align: pw.TextAlign.center),
                    _tableCell(
                        formatCurrency(price, currency),
                        align: pw.TextAlign.right),
                    _tableCell(
                        formatCurrency(qty * price, currency),
                        align: pw.TextAlign.right),
                  ],
                );
              }).toList(),
            ],
          ),
          pw.SizedBox(height: 12),

          // ── SUMMARY ─────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 230,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _summaryRow(
                        'Subtotal', formatCurrency(subtotal, currency)),
                    if (discount > 0)
                      _summaryRow('Discount',
                          '- ${formatCurrency(discount, currency)}',
                          color: PdfColors.orange800),
                    pw.Divider(thickness: 0.8),
                    _summaryRow(
                        'TOTAL', formatCurrency(total, currency),
                        bold: true),
                    if (debt > 0)
                      _summaryRow(
                          'Balance Due', formatCurrency(debt, currency),
                          color: PdfColors.red),
                  ],
                ),
              ),
            ],
          ),

          // ── PAYMENT DETAILS ─────────────────────────────────────
          if (paymentDetails.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Divider(thickness: 0.8),
            pw.SizedBox(height: 6),
            pw.Text('Payment Details',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColors.grey300, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.85),
                1: pw.FlexColumnWidth(1.15),
                2: pw.FlexColumnWidth(1.35),
                3: pw.FlexColumnWidth(1.35),
              },
              children: [
                pw.TableRow(
                  decoration:
                      const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _tableHeader('Type'),
                    _tableHeader('Provider / Bank'),
                    _tableHeader('Account name'),
                    _tableHeader('Number'),
                  ],
                ),
                ...paymentDetails.map((pd) => pw.TableRow(
                      children: [
                        _tableCell(pd['type'] == 'bank'
                            ? 'Bank'
                            : 'Mobile Money'),
                        _tableCell(pd['provider']?.toString() ?? ''),
                        _tableCell(receiptPaymentAccountLine(pd,
                            businessForFallback:
                                Map<String, dynamic>.from(business))),
                        _tableCell(pd['number']?.toString() ?? ''),
                      ],
                    )),
              ],
            ),
          ],

          // ── FOOTER ──────────────────────────────────────────────
          pw.SizedBox(height: 24),
          pw.Divider(thickness: 0.8),
          pw.Center(
            child: pw.Text(
              receiptFooterMessage(Map<String, dynamic>.from(business)),
              style: pw.TextStyle(
                fontSize: 11,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey600,
              ),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return pdf;
  }

  // ── PDF helper widgets ───────────────────────────────────────────

  pw.Widget _tableHeader(String text) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(
        text,
        style:
            pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _tableCell(String text,
      {pw.TextAlign align = pw.TextAlign.left}) {
    return pw.Padding(
      padding:
          const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(text,
          style: const pw.TextStyle(fontSize: 9), textAlign: align),
    );
  }

  pw.Widget _summaryRow(String label, String value,
      {bool bold = false, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: bold
                      ? pw.FontWeight.bold
                      : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  Future<void> sendInvoiceSms(dynamic invoice, Client client) async {
    String? phone;
    if (client.id.isNotEmpty && isValidSmsPhone(client.phone)) {
      phone = client.phone;
    } else {
      phone = await showSmsPhoneOnlyDialog(
        context: context,
        title: 'sms_send_invoice'.tr,
      );
      if (phone == null) return;
    }
    try {
      await SmsReminderService().sendBusinessSms(
        businessId: _businessController.businessId.value,
        type: 'invoice',
        phone: phone,
        clientId: client.id.isNotEmpty ? client.id : null,
        clientName: client.name.isNotEmpty ? client.name : phone,
        amount: (invoice.price as num?)?.toDouble() ?? 0,
        lines: productLinesForSms(invoice.products ?? const []),
        lang: Get.locale?.languageCode == 'en' ? 'en' : 'sw',
      );
      successSnackbar('sms_sent_invoice'.tr);
    } catch (e) {
      errorSnackbar(smsFunctionErrorMessage(e));
    }
  }

  Future<void> printInvoice(dynamic invoice, Client client) async {
    final documentType = await _pickDocumentType();
    if (documentType == null) return;

    final pdf = await _generateInvoice(
      invoice,
      client,
      documentType: documentType,
    );

    await Printing.layoutPdf(
      name: documentType == 'quotation' ? 'Quotation' : 'Invoice',
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Future<void> shareInvoice(dynamic invoice, Client client) async {
    final documentType = await _pickDocumentType();
    if (documentType == null) return;

    final pdf = await _generateInvoice(
      invoice,
      client,
      documentType: documentType,
    );

    try {
      final pdfBytes = await pdf.save();
      final prefix = documentType == 'quotation' ? 'Quotation' : 'Invoice';
      final fileName =
          '${prefix}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      
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
          text: documentType == 'quotation' ? 'Quotation' : 'Invoice Report',
        );
      }
    } catch (e) {
      errorSnackbar('Error generating PDF: $e');
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