import 'dart:io';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/invoice_model.dart';

Future<File> generatePdfInvoice(Invoice invoice) async {
  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(
      build: (context) {
        return pw.Column(
          children: [
            pw.Text('Invoice', style: pw.TextStyle(fontSize: 40)),
            pw.Text('Owner: ${invoice.owner}'),
            pw.Text('Date: ${invoice.date.toLocal()}'),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Product', 'Quantity', 'Price', 'Total'],
              data: invoice.items.map((item) {
                return [
                  item.name,
                  item.quantity,
                  item.price,
                  item.quantity * item.price,
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Total Amount: \$${invoice.total}'),
          ],
        );
      },
    ),
  );

  final output = await getTemporaryDirectory();
  final file = File('${output.path}/invoice.pdf');
  await file.writeAsBytes(await pdf.save());
  return file;
}
