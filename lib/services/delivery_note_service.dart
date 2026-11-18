import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../utils/sale_line_quantity.dart';

/// One row on a delivery note: what is being delivered and how much (no prices).
class DeliveryNoteLine {
  const DeliveryNoteLine({required this.name, required this.quantity});

  final String name;
  final String quantity;
}

/// Turns sale lines into delivery note rows. Prices are intentionally dropped.
/// Lines with no name or a zero/negative quantity are skipped.
List<DeliveryNoteLine> deliveryNoteLinesFromProducts(List<dynamic> products) {
  final lines = <DeliveryNoteLine>[];
  for (final product in products) {
    if (product is! Map) continue;
    final pm = Map<String, dynamic>.from(product);
    final name = (pm['name'] ?? '').toString().trim();
    if (name.isEmpty) continue;
    if (saleLineDisplayQuantity(pm) <= 0) continue;
    lines.add(
      DeliveryNoteLine(name: name, quantity: saleLineQuantityWithUomLabel(pm)),
    );
  }
  return lines;
}

/// A4 delivery note: business + customer details, item/quantity table, a
/// "Delivered by" block (name entered by the user, date filled automatically)
/// and a "Received by" signature box. Does not show prices, totals, discounts
/// or payments.
pw.Document buildDeliveryNotePdf({
  required String businessName,
  String businessPhone = '',
  String? businessTin,
  required DateTime date,
  required String clientName,
  String clientPhone = '',
  required List<DeliveryNoteLine> lines,
  String remarks = '',
  String deliveredBy = '',
  DateTime? deliveredDate,
}) {
  final doc = pw.Document();
  final noteNumber = 'DN-${DateFormat('yyyyMMddHHmm').format(date)}';
  const small = pw.TextStyle(fontSize: 10);
  final bold = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);

  pw.Widget cell(String text, {pw.TextStyle? style, pw.Alignment? align}) {
    return pw.Container(
      alignment: align ?? pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(text, style: style ?? small),
    );
  }

  pw.Widget signatureBox(String title) {
    return pw.Expanded(
      child: pw.Container(
        height: 80,
        margin: const pw.EdgeInsets.only(right: 12),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: bold),
            pw.Spacer(),
            pw.Text('Name: ______________________', style: small),
            pw.SizedBox(height: 6),
            pw.Text('Signature / Date: ______________', style: small),
          ],
        ),
      ),
    );
  }

  pw.Widget deliveredByBox() {
    final name = deliveredBy.trim();
    final day = DateFormat('yyyy-MM-dd').format(deliveredDate ?? DateTime.now());
    return pw.Expanded(
      child: pw.Container(
        height: 80,
        margin: const pw.EdgeInsets.only(right: 12),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey700, width: 0.8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Delivered by', style: bold),
            pw.Spacer(),
            pw.Text('Name: $name', style: small),
            pw.SizedBox(height: 6),
            pw.Text('Date: $day', style: small),
          ],
        ),
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  businessName,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (businessPhone.isNotEmpty)
                  pw.Text('Phone: $businessPhone', style: small),
                if (businessTin != null && businessTin.isNotEmpty)
                  pw.Text('TIN: $businessTin', style: small),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'DELIVERY NOTE',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text('No: $noteNumber', style: small),
                pw.Text(
                  'Date: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}',
                  style: small,
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 14),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 6),
        pw.Text('Deliver to', style: bold),
        pw.Text(clientName, style: small),
        if (clientPhone.isNotEmpty) pw.Text('Phone: $clientPhone', style: small),
        pw.SizedBox(height: 14),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey600, width: 0.6),
          columnWidths: const {
            0: pw.FixedColumnWidth(30),
            1: pw.FlexColumnWidth(),
            2: pw.FixedColumnWidth(110),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey300),
              children: [
                cell('#', style: bold),
                cell('Description', style: bold),
                cell('Quantity', style: bold, align: pw.Alignment.centerRight),
              ],
            ),
            for (var i = 0; i < lines.length; i++)
              pw.TableRow(
                children: [
                  cell('${i + 1}'),
                  cell(lines[i].name),
                  cell(lines[i].quantity, align: pw.Alignment.centerRight),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Total items: ${lines.length}',
          style: bold,
        ),
        if (remarks.trim().isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('Remarks', style: bold),
          pw.Text(remarks.trim(), style: small),
        ],
        pw.SizedBox(height: 28),
        pw.Text(
          'Goods received in good condition unless noted above.',
          style: pw.TextStyle(
            fontSize: 9,
            fontStyle: pw.FontStyle.italic,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            deliveredByBox(),
            signatureBox('Received by'),
          ],
        ),
      ],
    ),
  );

  return doc;
}

Future<Uint8List> buildDeliveryNoteBytes({
  required String businessName,
  String businessPhone = '',
  String? businessTin,
  required DateTime date,
  required String clientName,
  String clientPhone = '',
  required List<DeliveryNoteLine> lines,
  String remarks = '',
  String deliveredBy = '',
  DateTime? deliveredDate,
}) {
  return buildDeliveryNotePdf(
    businessName: businessName,
    businessPhone: businessPhone,
    businessTin: businessTin,
    date: date,
    clientName: clientName,
    clientPhone: clientPhone,
    lines: lines,
    remarks: remarks,
    deliveredBy: deliveredBy,
    deliveredDate: deliveredDate,
  ).save();
}
