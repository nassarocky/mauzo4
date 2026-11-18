import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../utils/download_helper.dart';
import '../utils/product_sales_stats.dart';

/// PDF / Excel export for the "most sold products" report.
class ProductSalesExportService {
  static final DateFormat _day = DateFormat('dd/MM/yyyy');

  static String _num(double v) {
    if (v == v.roundToDouble()) return NumberFormat('#,##0').format(v);
    return NumberFormat('#,##0.##').format(v);
  }

  static String _periodLabel(DateTime start, DateTime end) =>
      '${_day.format(start)} - ${_day.format(end)}';

  static String _safeFilePart(String value) => value
      .replaceAll(RegExp(r'[^\w\-]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  static String _fileBase(String businessName, DateTime start, DateTime end) {
    final f = DateFormat('yyyyMMdd');
    return 'products_sold_${_safeFilePart(businessName)}_'
        '${f.format(start)}_${f.format(end)}';
  }

  static Future<Uint8List> buildPdf({
    required List<ProductSalesRow> rows,
    required String businessName,
    required String currency,
    required DateTime start,
    required DateTime end,
    required bool selectedProductsOnly,
  }) async {
    final pdf = pw.Document();
    final totalQty = rows.fold<double>(0, (s, r) => s + r.quantity);
    final totalRevenue = rows.fold<double>(0, (s, r) => s + r.revenue);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            businessName,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text('Products sold report'),
          pw.Text('Period: ${_periodLabel(start, end)}'),
          if (selectedProductsOnly) pw.Text('Selected products only'),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: ['#', 'Product', 'Qty sold', 'Sales', 'Revenue ($currency)'],
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            data: [
              for (var i = 0; i < rows.length; i++)
                [
                  '${i + 1}',
                  rows[i].name,
                  _num(rows[i].quantity),
                  '${rows[i].salesCount}',
                  _num(rows[i].revenue),
                ],
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            'Total quantity: ${_num(totalQty)}    '
            'Total revenue: $currency ${_num(totalRevenue)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await pdf.save());
  }

  static Uint8List buildExcel({
    required List<ProductSalesRow> rows,
    required String businessName,
    required String currency,
    required DateTime start,
    required DateTime end,
    required bool selectedProductsOnly,
  }) {
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    sheet.appendRow(['Products sold report']);
    sheet.appendRow(['Business', businessName]);
    sheet.appendRow(['Period', _periodLabel(start, end)]);
    if (selectedProductsOnly) {
      sheet.appendRow(['Filter', 'Selected products']);
    }
    sheet.appendRow([]);
    sheet.appendRow(['#', 'Product', 'Qty sold', 'Sales', 'Revenue ($currency)']);
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      sheet.appendRow([i + 1, r.name, r.quantity, r.salesCount, r.revenue]);
    }
    sheet.appendRow([]);
    sheet.appendRow([
      '',
      'Total',
      rows.fold<double>(0, (s, r) => s + r.quantity),
      '',
      rows.fold<double>(0, (s, r) => s + r.revenue),
    ]);
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to generate Excel file');
    return Uint8List.fromList(bytes);
  }

  static Future<void> sharePdf({
    required List<ProductSalesRow> rows,
    required String businessName,
    required String currency,
    required DateTime start,
    required DateTime end,
    required bool selectedProductsOnly,
  }) async {
    final bytes = await buildPdf(
      rows: rows,
      businessName: businessName,
      currency: currency,
      start: start,
      end: end,
      selectedProductsOnly: selectedProductsOnly,
    );
    await _share(
      bytes: bytes,
      fileName: '${_fileBase(businessName, start, end)}.pdf',
    );
  }

  static Future<void> shareExcel({
    required List<ProductSalesRow> rows,
    required String businessName,
    required String currency,
    required DateTime start,
    required DateTime end,
    required bool selectedProductsOnly,
  }) async {
    final bytes = buildExcel(
      rows: rows,
      businessName: businessName,
      currency: currency,
      start: start,
      end: end,
      selectedProductsOnly: selectedProductsOnly,
    );
    await _share(
      bytes: bytes,
      fileName: '${_fileBase(businessName, start, end)}.xlsx',
    );
  }

  static Future<void> _share({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (kIsWeb) {
      DownloadHelper.downloadFileWeb(bytes, fileName);
      return;
    }
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Products sold report');
  }
}
