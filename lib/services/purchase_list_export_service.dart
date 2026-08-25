import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/purchase_list_draft.dart';
import '../utils/download_helper.dart';

class PurchaseListExportService {
  static String _safeFilePart(String value) => value
      .replaceAll(RegExp(r'[^\w\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static Future<Uint8List> buildPdf({
    required PurchaseListDraft draft,
    required String businessName,
  }) async {
    final pdf = pw.Document();
    final date = DateFormat('dd/MM/yyyy HH:mm').format(
      draft.updatedAt.toDate(),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            businessName,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Supplier purchase list'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Supplier: ${draft.supplierName.isEmpty ? 'Not selected' : draft.supplierName}',
          ),
          if (draft.supplierPhone.isNotEmpty)
            pw.Text('Phone: ${draft.supplierPhone}'),
          pw.Text('Updated: $date'),
          if (draft.note.isNotEmpty) pw.Text('Note: ${draft.note}'),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const ['#', 'Product', 'Requested quantity'],
            data: [
              for (var i = 0; i < draft.products.length; i++)
                [
                  '${i + 1}',
                  (draft.products[i]['name'] ?? '').toString(),
                  _formatQuantity(draft.products[i]['quantity']),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Total requested quantity: ${_formatQuantity(draft.totalQuantity)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  static Uint8List buildExcel({
    required PurchaseListDraft draft,
    required String businessName,
  }) {
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;
    final sheet = excel[defaultSheet];
    sheet.appendRow(['Supplier purchase list']);
    sheet.appendRow(['Business', businessName]);
    sheet.appendRow([
      'Supplier',
      draft.supplierName.isEmpty ? 'Not selected' : draft.supplierName,
    ]);
    sheet.appendRow(['Phone', draft.supplierPhone]);
    sheet.appendRow([
      'Updated',
      DateFormat('dd/MM/yyyy HH:mm').format(draft.updatedAt.toDate()),
    ]);
    if (draft.note.isNotEmpty) sheet.appendRow(['Note', draft.note]);
    sheet.appendRow([]);
    sheet.appendRow(['#', 'Product', 'Requested quantity']);
    for (var i = 0; i < draft.products.length; i++) {
      final item = draft.products[i];
      sheet.appendRow([
        i + 1,
        (item['name'] ?? '').toString(),
        (item['quantity'] as num?)?.toDouble() ?? 0,
      ]);
    }
    sheet.appendRow([]);
    sheet.appendRow(['', 'Total', draft.totalQuantity]);
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to generate Excel file');
    return Uint8List.fromList(bytes);
  }

  static Future<void> sharePdf({
    required PurchaseListDraft draft,
    required String businessName,
  }) async {
    final bytes = await buildPdf(draft: draft, businessName: businessName);
    await _share(
      bytes: bytes,
      fileName:
          'purchase_list_${_safeFilePart(draft.supplierName)}_${draft.id}.pdf',
      text: 'Supplier purchase list',
    );
  }

  static Future<void> shareExcel({
    required PurchaseListDraft draft,
    required String businessName,
  }) async {
    final bytes = buildExcel(draft: draft, businessName: businessName);
    await _share(
      bytes: bytes,
      fileName:
          'purchase_list_${_safeFilePart(draft.supplierName)}_${draft.id}.xlsx',
      text: 'Supplier purchase list',
    );
  }

  static Future<void> _share({
    required Uint8List bytes,
    required String fileName,
    required String text,
  }) async {
    if (kIsWeb) {
      DownloadHelper.downloadFileWeb(bytes, fileName);
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  static String _formatQuantity(dynamic value) {
    final quantity = value is num
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0;
    return quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
  }
}
