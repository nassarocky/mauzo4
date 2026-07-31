import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/client_model.dart';
import '../models/sale_model.dart';
import '../services/firestore_db.dart';
import '../utils/constants.dart';
import '../utils/debtors_export.dart';
import '../utils/download_helper.dart';
import '../utils/sale_client_name.dart';

class ClientController extends GetxController {
  final BusinessController _businessController = Get.find();

  final clients = <Client>[].obs;
  final searchClients = <Client>[].obs;
  final sortCategory = 'name'.obs;
  final filterType = 'all'.obs;

  StreamSubscription<List<Client>>? _clientSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _clientSubscription = FirestoreDb().getClients().listen((data) {
        clients.value = data;
        searchClients.value = List<Client>.from(data);
        sort(sortCategory.value);
      });
    } catch (e) {
      print("Error binding client stream: $e");
    }
  }

  @override
  void onClose() {
    _clientSubscription?.cancel();
    super.onClose();
  }

  Client getClient(String clientId) {
    return clients.firstWhere((client) => client.id == clientId,
        orElse: () => Client(
          owner: '',
          id: '',
          name: '',
          phone: '',
          date: Timestamp.now(),
        ));
  }

  /// Client for receipts/exports: registered profile, or free-text [Sale.clientname].
  Client resolveClientForSale(Sale sale) {
    final lookedUp = getClient(sale.client);
    final displayName = saleClientDisplayName(
      lookedUpClientName: lookedUp.name,
      saleClientName: sale.clientname,
    );
    if (displayName.isEmpty || lookedUp.name.trim() == displayName) {
      return lookedUp;
    }
    return Client(
      id: lookedUp.id.isNotEmpty ? lookedUp.id : sale.client,
      owner: lookedUp.owner,
      name: displayName,
      phone: lookedUp.phone,
      date: lookedUp.date,
      debt: lookedUp.debt,
      advance: lookedUp.advance,
      advanceTransactions: lookedUp.advanceTransactions,
      note: lookedUp.note,
      image: lookedUp.image,
    );
  }

  Future<void> updateAdvance(Client client, double amount) async {
    final String? business = _businessController.businessId.value;
    if (business == null) {
      print('Owner ID is null, cannot update client advance.');
      return;
    }
    try {
      print('Updating advance for client: ${client.id}');
      // Create a transaction record for the addition.
      Map<String, dynamic> transactionRecord = {
        'amount': amount, // Positive amount for an addition.
        'time': Timestamp.now(), // Use client timestamp
      };

      await firestore
          .collection('clients')
          .doc(business)
          .collection('userClients')
          .doc(client.id)
          .update({
        'advance': client.advance + amount,
        'advanceTransactions': FieldValue.arrayUnion([transactionRecord]),
      });

      print('Advance updated successfully for client: ${client.id}');
      Get.snackbar(
        'Success',
        'Advance added successfully!',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      print('Error updating advance: $e');
      errorSnackbar(e.toString());
    }
  }

  Future<void> reduceAdvance(Client client, double amount) async {
    final String? business = _businessController.businessId.value;
    if (business == null) {
      print('Owner ID is null, cannot update client advance.');
      return;
    }
    try {
      // Create a transaction record for the reduction (negative amount).
      Map<String, dynamic> transactionRecord = {
        'amount': -amount, // Negative value for a reduction.
        'time': Timestamp.now(), // Use client timestamp
      };

      await firestore
          .collection('clients')
          .doc(business)
          .collection('userClients')
          .doc(client.id)
          .update({
        'advance': client.advance - amount,
        'advanceTransactions': FieldValue.arrayUnion([transactionRecord]),
      });

      Get.snackbar(
        'Success',
        'Advance reduced successfully!',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 3),
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  Future<void> updateDebt(Client client, double debt) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot update client debt.');
      return;
    }

    try {
      firestore
          .collection('clients')
          .doc(business)
          .collection('userClients')
          .doc(client.id)
          .update({
        'debt': debt,
      });
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  void deleteClient(String clientId) async {
    final String? business = _businessController.businessId.value;

    if (business == null) {
      print('Owner ID is null, cannot delete client.');
      return;
    }

    try {
      await firestore
          .collection('clients')
          .doc(business)
          .collection('userClients')
          .doc(clientId)
          .delete();
      successSnackbar('${'client'.tr} ${'deleted'.tr}');
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  void clearClients(){
    clients.value.clear();
    searchClients.value.clear();
  }

  void search(String searchText) {
    searchClients.value = clients
        .where((client) =>
            client.name.toLowerCase().contains(searchText.toLowerCase()))
        .toList();
    sort(sortCategory.value);
  }

  int _compareNameAZ(Client a, Client b) {
    return a.name
        .toLowerCase()
        .trim()
        .compareTo(b.name.toLowerCase().trim());
  }

  void sort(String category) {
    sortCategory.value = category;
    final sorted = List<Client>.from(searchClients);
    switch (category) {
      case 'name':
        sorted.sort(_compareNameAZ);
        break;
      case 'debt':
        sorted.sort((a, b) => b.debt.compareTo(a.debt));
        break;
      case 'date':
        sorted.sort((a, b) => b.date.compareTo(a.date));
        break;
      default:
        sorted.sort(_compareNameAZ);
    }
    searchClients.value = sorted;
  }

  void setSortCategoryValue(String value) {
    sortCategory.value = value;
  }

  void applyFilter(String filter) {
    filterType.value = filter;

    switch (filter) {
      case 'all':
        searchClients.value = List<Client>.from(clients);
        break;
      case 'with_debt':
        searchClients.value =
            clients.where((client) => client.debt > 0).toList();
        break;
      case 'with_advance':
        searchClients.value =
            clients.where((client) => client.advance > 0).toList();
        break;
      case 'no_balance':
        searchClients.value = clients
            .where((client) => client.debt == 0 && client.advance == 0)
            .toList();
        break;
      default:
        searchClients.value = List<Client>.from(clients);
    }

    sort(sortCategory.value);
  }

  /// Customers currently owed money (aggregate [Client.debt] > 0).
  List<DebtorExportRow> debtorsForExport() {
    return buildDebtorExportRows(
      names: clients.map((c) => c.name),
      phones: clients.map((c) => c.phone),
      amounts: clients.map((c) => c.debt),
    );
  }

  Future<void> generateExcelFromDebtors() async {
    final rows = debtorsForExport();
    if (rows.isEmpty) {
      errorSnackbar('no_debtors_to_export'.tr);
      return;
    }

    final excel = Excel.createExcel();
    final String defaultSheet = excel.getDefaultSheet()!;
    final Sheet sheetObject = excel[defaultSheet];

    final String businessName =
        _businessController.business['name'] ?? 'Business Name';
    final String currency =
        (_businessController.business['mainCurrency'] ?? '').toString();
    final String exportedAt =
        DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());

    sheetObject.appendRow([businessName]);
    sheetObject.appendRow(['debtors'.tr]);
    sheetObject.appendRow(['${'date'.tr}: $exportedAt']);
    sheetObject.appendRow([]);

    final headerStyle = CellStyle(
      backgroundColorHex: '#FFC107',
      bold: true,
    );
    final headerRowIndex = sheetObject.maxRows;
    sheetObject.appendRow([
      'name'.tr,
      'phone'.tr,
      '${'debt'.tr}${currency.isNotEmpty ? ' ($currency)' : ''}',
    ]);
    sheetObject.row(headerRowIndex).forEach((cell) {
      cell?.cellStyle = headerStyle;
    });

    for (final row in rows) {
      sheetObject.appendRow([row.name, row.phone, row.amount]);
    }

    sheetObject.appendRow([]);
    final totalsRowIndex = sheetObject.maxRows;
    final total = sumDebtorAmounts(rows);
    sheetObject.appendRow(['${'total'.tr}:', '', total]);
    final totalsStyle = CellStyle(
      bold: true,
      backgroundColorHex: '#ADD8E6',
    );
    sheetObject.row(totalsRowIndex).forEach((cell) {
      cell?.cellStyle = totalsStyle;
    });

    final fileBytes = excel.encode();
    if (fileBytes == null) {
      errorSnackbar('Failed to generate Excel file'.tr);
      return;
    }

    final fileName =
        'Debtors_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    if (DownloadHelper.isWeb) {
      DownloadHelper.downloadFileWeb(Uint8List.fromList(fileBytes), fileName);
      successSnackbar('Excel file downloaded successfully!'.tr);
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$fileName';
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(fileBytes);
      await Share.shareXFiles([XFile(filePath)], text: 'debtors'.tr);
    }
  }

  Future<void> generatePdfFromDebtors({bool share = false}) async {
    final rows = debtorsForExport();
    if (rows.isEmpty) {
      errorSnackbar('no_debtors_to_export'.tr);
      return;
    }

    final String businessName =
        (_businessController.business['name'] ?? 'Business').toString();
    final String currency =
        (_businessController.business['mainCurrency'] ?? '').toString();
    final String exportedAt =
        DateFormat('dd MMM yyyy HH:mm').format(DateTime.now());
    final total = sumDebtorAmounts(rows);
    final amountFmt = NumberFormat('#,##0.00');

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            businessName,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'debtors'.tr,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            '${'date'.tr}: $exportedAt',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                children: [
                  _pdfCell('name'.tr, bold: true),
                  _pdfCell('phone'.tr, bold: true),
                  _pdfCell(
                    '${'debt'.tr}${currency.isNotEmpty ? ' ($currency)' : ''}',
                    bold: true,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
              ...rows.map(
                (row) => pw.TableRow(
                  children: [
                    _pdfCell(row.name),
                    _pdfCell(row.phone.isEmpty ? '—' : row.phone),
                    _pdfCell(
                      amountFmt.format(row.amount),
                      align: pw.TextAlign.right,
                    ),
                  ],
                ),
              ),
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.lightBlue100),
                children: [
                  _pdfCell('total'.tr, bold: true),
                  _pdfCell(''),
                  _pdfCell(
                    amountFmt.format(total),
                    bold: true,
                    align: pw.TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            '${'clients'.tr}: ${rows.length}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    final fileName =
        'Debtors_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';
    final pdfBytes = await pdf.save();

    if (share) {
      if (DownloadHelper.isWeb) {
        DownloadHelper.downloadFileWeb(pdfBytes, fileName);
        successSnackbar('PDF downloaded successfully!'.tr);
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(pdfBytes);
        await Share.shareXFiles([XFile(filePath)], text: 'debtors'.tr);
      }
      return;
    }

    await Printing.layoutPdf(
      name: fileName,
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  pw.Widget _pdfCell(
    String text, {
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}
