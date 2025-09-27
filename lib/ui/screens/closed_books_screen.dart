import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../controllers/bought_controller.dart';
import '../../controllers/business_controller.dart';
import '../../controllers/closed_books_controller.dart';
import '../../controllers/debt_history_controller.dart';
import '../../controllers/expence_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../controllers/sale_controller.dart';
import '../../models/close_book_model.dart';
import '../../utils/constants.dart';
import 'package:http/http.dart' as http;

class CloseBookScreen extends StatefulWidget {
  @override
  _CloseBookScreenState createState() => _CloseBookScreenState();
}

class _CloseBookScreenState extends State<CloseBookScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ClosedBooksController closedBooksController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();
  final SaleController _saleController = Get.find();
  final BoughtController _boughtController = Get.find();
  final DebtHistoryController _debtHistoryController = Get.find();
  final ExpenseController _expenseController = Get.find();
  final ProductController _productController = Get.find();

  @override
  Widget build(BuildContext context) {
    final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
    void _showConfirmationDialog() {
      showDialog(
        context: _scaffoldKey.currentContext!,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('confirmation'.tr),
            content: Text('Are you sure you want to generate a new report?'.tr),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('cancel'.tr),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  // Show a loading indicator
                  ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(
                    SnackBar(
                      content: Text('Generating report...'.tr),
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.fixed,
                    ),
                  );

                  try {
                    final newReport = await generateNewReport();

                    if (newReport != null) {
                      successSnackbar('Report generated successfully!');
                      _showReportDetail(_scaffoldKey.currentContext!, newReport);
                    } else {
                      errorSnackbar('Failed to generate the report.');
                    }
                  } catch (e) {
                    errorSnackbar('Error generating report: $e');
                  }
                },
                child: Text('confirm'.tr),
              ),
            ],
          );
        },
      );
    }
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text('Reports'.tr),
      ),
      body: Column(
        children: [
          // Row with two buttons: default report & custom date range.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
      _showConfirmationDialog();
                },
                icon: Icon(Icons.file_download),
                label: Text('Generate Report'.tr),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () {
                  // Open date range picker for a custom report
                  showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  ).then((DateTimeRange? value) {
                    if (value != null) {
                      _saleController.setSelectedDateRange(value);
                      final String range =
                          '${DateFormat('dd/MM/yyyy').format(value.start)} - ${DateFormat('dd/MM/yyyy').format(value.end)}';
                      successSnackbar("${'date'.tr}: $range");
                      generateNewReport(
                        customStart: value.start,
                        customEnd: value.end,
                      ).then((report) {
                        if (report != null) {
                          successSnackbar('Report generated successfully!');
                          _showReportDetail(context, report);
                        } else {
                          errorSnackbar('Failed to generate report.');
                        }
                      });
                    }
                  });
                },
                icon: Icon(Icons.date_range),
                label: Text(''),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Display list of reports.
          Expanded(
            child: Obx(() {
              if (closedBooksController.closedBooks.isEmpty) {
                return Center(child: Text('No reports available.'.tr));
              }
              return ListView.builder(
                itemCount: closedBooksController.closedBooks.length,
                itemBuilder: (context, index) {
                  final book = closedBooksController.closedBooks[index];
                  return ReportCard(
                    book: book,
                    onTap: () {
                      _showReportDetail(context, book);
                    },
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<CloseBook?> generateNewReport({DateTime? customStart, DateTime? customEnd}) async {
    // Determine the start timestamp: customStart if provided, else business reset_time.
    Timestamp startTimestamp;
    if (customStart != null) {
      startTimestamp = Timestamp.fromDate(customStart);
    } else {
      startTimestamp = _businessController.business['reset_time'];
    }

    // Determine end date: customEnd if provided, else current time.
    DateTime endDate = customEnd ?? DateTime.now();

    // Calculate report values for the period.
    double totalSales = _saleController.getTotalSalesFromTimestamp(startTimestamp, Timestamp.fromDate(endDate));
    double totalSalesBuying = _saleController.getTotalSalesBuyingFromTimestamp(startTimestamp, Timestamp.fromDate(endDate));
    double totalPayment = _saleController.getTotalPaymentFromTimestamp(startTimestamp, Timestamp.fromDate(endDate));
    double debt = _debtHistoryController.getTotalDebtFromTimestamp(startTimestamp, Timestamp.fromDate(endDate));
    double totalDebt = _debtHistoryController.getTotalDebt();
    double debtCollected = _debtHistoryController.getTotalDebtPaymentsBackTimestamp(startTimestamp, Timestamp.fromDate(endDate));
    double expenses = _expenseController.getTotalExpensesFromTimestamp(startTimestamp, Timestamp.fromDate(endDate));
    double totalStock = _productController.calculateTotalStock();
    double purchases = _boughtController.getTotalSalesFromTimestamp(startTimestamp, Timestamp.fromDate(endDate));
    double netProfit = totalSales - totalSalesBuying - expenses;
    double totalPurchase = 0.0;
    double totalDiscounts = 0.0;
    String currency = _businessController.business['mainCurrency'] ?? "TZS";

    // Amounts paid to suppliers in the period
    // - purchasesPaid: all methods (cash, bank, mobile)
    // - purchasesCashPaid: cash-only for cash-in-hand computation
    final double purchasesPaid = _boughtController.getTotalPurchasePaidFromTimestamp(
      startTimestamp,
      Timestamp.fromDate(endDate),
    );
    final double purchasesCashPaid = _boughtController.getTotalPurchaseCashPaidFromTimestamp(
      startTimestamp,
      Timestamp.fromDate(endDate),
    );

    DateTime startDate = startTimestamp.toDate();

    CloseBook newReport = CloseBook(
      id: '',
      owner: _profileController.user['owner'] ?? '',
      totalSales: totalSales,
      totalPayment: totalPayment,
      totalDebt: totalDebt,
      debt: debt,
      reserveDouble1: purchasesPaid,
      reserveDouble2: totalSalesBuying,
      expenses: expenses,
      startDate: startDate,
      endDate: endDate,
      finalStock: totalStock,
      debtCollected: debtCollected,
      netProfit: netProfit,
      totalPurchase: purchasesCashPaid,
      totalDiscounts: totalDiscounts,
      currency: currency,
      createdBy: _profileController.user['name'] ?? '',
      createdAt: DateTime.now(),
    );

    try {
      // For default reports, save the report; for custom ranges, simply return it.
      if (customStart != null) {
        return newReport;
      } else {
        final reportRef = _firestore
            .collection('closedbooks')
            .doc(_businessController.business['id'])
            .collection('userClosedBooks')
            .doc();

        await reportRef.set(newReport.toFirestore());
        print('New report generated and saved successfully!');

        // Reset product quantities after report generation.
        _resetProductQuantities();

        return newReport;
      }
    } catch (e) {
      print('Error generating report: $e');
      return null;
    }
  }

  Future<void> _resetProductQuantities() async {
    final String businessId = _businessController.business['id'];
    final Uri url = Uri.parse(
        'https://us-central1-hesabumauzo.cloudfunctions.net/resetBusinessResetTime?profile=$businessId'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        // Optionally show success message.
      } else {
        errorSnackbar('Failed to update product quantities.'.tr);
      }
    } catch (e) {
      errorSnackbar('Error: ${e.toString()}'.tr);
    }
  }

  void _showReportDetail(BuildContext context, CloseBook book) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          '${'From:'.tr} ${DateFormat('dd MMM yyyy, hh:mm a').format(book.startDate)} ${'to'.tr} ${DateFormat('dd MMM yyyy, hh:mm a').format(book.endDate)}',
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportTable(book),
              SizedBox(height: 16),
              Text('Final Stock & Total Debt', style: TextStyle(fontWeight: FontWeight.bold)),
              _buildStockAndDebtTable(book),
            ],
          ),
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              _generateAndSharePDF(book);
            },
            icon: Icon(Icons.picture_as_pdf),
            label: Text('Generate PDF & Share'.tr),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('close'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(CloseBook book) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      children: [
        _buildTableRow('${'TOTAL SALES (Accrual):'.tr}', book.totalSales, _businessController.business['mainCurrency']),
        _buildTableRow('${'TOTAL PAYMENTS (Cash In):'.tr}', book.totalPayment, _businessController.business['mainCurrency']),
        _buildTableRow('${'COGS (Buying Price):'.tr}', book.reserveDouble2 ?? 0.0, _businessController.business['mainCurrency']),
        _buildTableRow('${'PURCHASES PAID'.tr}', book.reserveDouble1 ?? 0.0, _businessController.business['mainCurrency']),
        _buildTableRow('${'DEBT (Created in Period):'.tr}', book.debt, _businessController.business['mainCurrency']),
        _buildTableRow('${'DEBT COLLECTED (from previous periods):'.tr}', book.debtCollected, _businessController.business['mainCurrency']),
        _buildTableRow('${'EXPENSES:'.tr}', book.expenses, _businessController.business['mainCurrency']),
        _buildTableRow(
          '${'TOTAL CASH IN HAND (payments - expenses - purchases paid)'.tr}',
          (book.totalPayment - book.expenses - (book.totalPurchase)),
          _businessController.business['mainCurrency'],
        ),
        _buildTableRow('${'ESTIMATED PROFIT (sales - COGS - expenses)'.tr}', book.netProfit, _businessController.business['mainCurrency']),
      ],
    );
  }

  TableRow _buildTableRow(String label, double value, String currency) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '$currency ${value.toStringAsFixed(2)}',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildStockAndDebtTable(CloseBook book) {
    return Table(
      border: TableBorder.all(color: Colors.grey),
      children: [
        _buildTableRow('FINAL STOCK'.tr, book.finalStock, book.currency),
        _buildTableRow('TOTAL DEBT'.tr, book.totalDebt, book.currency),
      ],
    );
  }

  void _generateAndSharePDF(CloseBook book) async {
    final pdf = pw.Document();

    // Business details for the header.
    final businessName = _businessController.business['name'] ?? 'Business Name';
    final phone = _businessController.business['phone'] ?? 'Phone Number';
    final tin = _businessController.business['tin'] ?? 'TIN Number';
    final startTime = DateFormat('dd MMM yyyy, hh:mm a').format(book.startDate);
    final endTime = DateFormat('dd MMM yyyy, hh:mm a').format(book.endDate);

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                businessName,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('Phone: $phone'),
              pw.Text('TIN: $tin'),
              pw.Text('Report From: $startTime to $endTime'),
              pw.SizedBox(height: 20),
              pw.Text(
                'Report Summary',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              _buildPDFTable(book),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final filePath = '${output.path}/report.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      final result = await Share.shareXFiles(
        [XFile("${output.path}/report.pdf")],
        text: 'Report',
      );

      if (result.status == ShareResultStatus.success) {
        print('Report shared successfully!');
      } else if (result.status == ShareResultStatus.dismissed) {
        print('Share dismissed');
      }
    } catch (e) {
      errorSnackbar('Error sharing PDF: $e');
    }
  }
  //Helper function to build the PDF table
  pw.Widget _buildPDFTable(CloseBook book) {

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey),
      children: [
        _buildPDFTableRow('TOTAL SALES (Accrual):'.tr, book.totalSales, book.currency),
        _buildPDFTableRow('TOTAL PAYMENTS (Cash In):'.tr, book.totalPayment, book.currency),
        _buildPDFTableRow('COGS (Buying Price):'.tr, book.reserveDouble2 ?? 0.0, book.currency),
        _buildPDFTableRow(
            'PURCHASES PAID:'.tr,
            book.reserveDouble1 ?? 0.0, // Use the double value directly or default to 0.0
            book.currency
        ),

        _buildPDFTableRow('DEBT (Created in Period):'.tr, book.debt, book.currency),
        _buildPDFTableRow('DEBT COLLECTED (from previous periods):'.tr, book.debtCollected, book.currency),
        _buildPDFTableRow('EXPENSES:'.tr, book.expenses, book.currency),
        _buildPDFTableRow(
          'TOTAL CASH IN HAND (payments - expenses - purchases paid)'.tr,
          (book.totalPayment  - book.expenses - (book.totalPurchase)),
          book.currency,
        ),

        _buildPDFTableRow(
          'ESTIMATED PROFIT (sales - COGS - expenses)'.tr,
          book.netProfit,
          book.currency,
        ),
        _buildPDFTableRow('FINAL STOCK'.tr, book.finalStock, book.currency),
        _buildPDFTableRow('TOTAL DEBT'.tr, book.totalDebt, book.currency),
      ],
    );
  }

  pw.TableRow _buildPDFTableRow(String label, double value, String currency) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8.0),
          child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8.0),
          child: pw.Text('$currency ${value.toStringAsFixed(2)}'),
        ),
      ],
    );
  }
}

class ReportCard extends StatelessWidget {
  final CloseBook book;
  final VoidCallback onTap;

  const ReportCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('dd MMM yyyy, hh:mm a');
    return Card(
      margin: EdgeInsets.all(8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(FontAwesomeIcons.filePdf, color: Colors.red),
        title: Text(
          '${'Report:'.tr}${formatter.format(book.startDate)} - ${formatter.format(book.endDate)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent),
        ),
        subtitle: Text(
          '${'Total Payments:'.tr}${book.currency} ${book.totalPayment.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
