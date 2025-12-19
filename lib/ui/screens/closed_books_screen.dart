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
import '../../utils/download_helper.dart';
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
                onPressed: () async {
                  // Open date range picker for a custom report
                  final DateTimeRange? value = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  
                  if (value != null) {
                    _saleController.setSelectedDateRange(value);
                    final String range =
                        '${DateFormat('dd/MM/yyyy').format(value.start)} - ${DateFormat('dd/MM/yyyy').format(value.end)}';
                    
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (BuildContext context) {
                        return Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Fetching data from Firestore...'.tr),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                    
                    try {
                      final report = await generateNewReport(
                        customStart: value.start,
                        customEnd: value.end,
                      );
                      
                      // Close loading dialog
                      Navigator.of(context).pop();
                      
                      if (report != null) {
                        successSnackbar('Report generated successfully for $range!');
                        _showReportDetail(context, report);
                      } else {
                        errorSnackbar('Failed to generate report.');
                      }
                    } catch (e) {
                      // Close loading dialog
                      Navigator.of(context).pop();
                      errorSnackbar('Error generating report: $e');
                    }
                  }
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
    Timestamp endTimestamp = Timestamp.fromDate(endDate);

    // For custom date ranges, fetch data directly from Firestore
    // For default reports, use already loaded data from controllers
    double totalSales, totalSalesBuying, totalPayment, debt, expenses, purchasesPaid, purchasesCashPaid;
    
    if (customStart != null) {
      // Custom date range: Query Firestore directly
      print('📊 Generating custom report from Firestore: ${startTimestamp.toDate()} to ${endTimestamp.toDate()}');
      
      final results = await _fetchDataFromFirestore(startTimestamp, endTimestamp);
      totalSales = results['totalSales']!;
      totalSalesBuying = results['totalSalesBuying']!;
      totalPayment = results['totalPayment']!;
      debt = results['debt']!;
      expenses = results['expenses']!;
      purchasesPaid = results['purchasesPaid']!;
      purchasesCashPaid = results['purchasesCashPaid']!;
    } else {
      // Default report: Use already loaded data from controllers
      print('📊 Generating default report from loaded data');
      
      totalSales = _saleController.getTotalSalesFromTimestamp(startTimestamp, endTimestamp);
      totalSalesBuying = _saleController.getTotalSalesBuyingFromTimestamp(startTimestamp, endTimestamp);
      totalPayment = _saleController.getTotalPaymentFromTimestamp(startTimestamp, endTimestamp);
      debt = _debtHistoryController.getTotalDebtFromTimestamp(startTimestamp, endTimestamp);
      expenses = _expenseController.getTotalExpensesFromTimestamp(startTimestamp, endTimestamp);
      purchasesPaid = _boughtController.getTotalPurchasePaidFromTimestamp(startTimestamp, endTimestamp);
      purchasesCashPaid = _boughtController.getTotalPurchaseCashPaidFromTimestamp(startTimestamp, endTimestamp);
    }
    
    double totalDebt = _debtHistoryController.getTotalDebt();
    double totalStock = _productController.calculateTotalStock();
    String currency = _businessController.business['mainCurrency'] ?? "TZS";

    // Calculate total discounts given
    // Discounts = Original Price - (Cash + Credit)
    double totalDiscounts = totalSales - (totalPayment + debt);

    // Calculate net profit using COGS (Cost of Goods Sold)
    // COGS = buying price of items actually sold in the period
    // Formula: (Payment + Debt) - COGS - Expenses
    // This correctly accounts for:
    // - Cash received (totalPayment)
    // - Credit sales (debt) 
    // - Discounts are automatically excluded (not in payment or debt)
    double netProfit = (totalPayment + debt) - totalSalesBuying - expenses;

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

    try {
      // Update the reset_time field to the current timestamp directly in Firestore
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .update({'reset_time': Timestamp.now()});
      
      print('Reset time successfully updated.');
      
      // CRITICAL: Refresh business controller to update cached reset_time
      // This ensures sales stream uses the new reset_time for filtering
      await _businessController.updateBusinessData();
      print('Business controller refreshed with new reset_time.');
    } catch (e) {
      errorSnackbar('Failed to update reset time: ${e.toString()}'.tr);
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
        _buildTableRow('${'EXPENSES:'.tr}', book.expenses, _businessController.business['mainCurrency']),
        _buildTableRow(
          '${'TOTAL CASH IN HAND (payments - expenses - purchases paid)'.tr}',
          (book.totalPayment - book.expenses - (book.totalPurchase)),
          _businessController.business['mainCurrency'],
        ),
        _buildTableRow('${'NET PROFIT (payments + debt - COGS - expenses)'.tr}', book.netProfit, _businessController.business['mainCurrency']),
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
        pageFormat: PdfPageFormat.a4,
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
      final pdfBytes = await pdf.save();
      final fileName = 'Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      
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
          text: 'Closed Books Report',
        );
      }
    } catch (e) {
      errorSnackbar('Error generating PDF: $e');
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
        _buildPDFTableRow('EXPENSES:'.tr, book.expenses, book.currency),
        _buildPDFTableRow(
          'TOTAL CASH IN HAND (payments - expenses - purchases paid)'.tr,
          (book.totalPayment  - book.expenses - (book.totalPurchase)),
          book.currency,
        ),

        _buildPDFTableRow(
          'NET PROFIT (payments + debt - COGS - expenses)'.tr,
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

  /// Fetch data directly from Firestore for custom date ranges
  /// This allows reports for dates before reset_time
  Future<Map<String, double>> _fetchDataFromFirestore(Timestamp startTimestamp, Timestamp endTimestamp) async {
    final String? businessId = _businessController.businessId.value;
    
    if (businessId == null || businessId.isEmpty) {
      print('❌ Business ID is null, cannot fetch data');
      return {
        'totalSales': 0.0,
        'totalSalesBuying': 0.0,
        'totalPayment': 0.0,
        'debt': 0.0,
        'expenses': 0.0,
        'purchasesPaid': 0.0,
        'purchasesCashPaid': 0.0,
      };
    }

    try {
      // Query sales within date range
      final salesSnapshot = await _firestore
          .collection('sales')
          .doc(businessId)
          .collection('userSales')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp)
          .get();

      double totalSales = 0.0;
      double totalSalesBuying = 0.0;
      double totalPayment = 0.0;

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        totalSales += (data['price'] ?? 0.0).toDouble();
        totalSalesBuying += (data['buyingPrice'] ?? 0.0).toDouble();
        totalPayment += (data['payment'] ?? 0.0).toDouble();
      }

      print('✅ Fetched ${salesSnapshot.docs.length} sales from Firestore');

      // Query debt history - fetch PENDING debts only and filter by date in code
      // PENDING debts = new credit extended (PAID debts are already converted to sales)
      // Uses remainingDebtAmount to calculate total debt
      final debtSnapshot = await _firestore
          .collection('debtHistory')
          .doc(businessId)
          .collection('clientDebtHistory')
          .where('status', isEqualTo: 'PENDING')
          .get();

      double debt = 0.0;
      int debtCount = 0;
      
      for (var doc in debtSnapshot.docs) {
        final data = doc.data();
        final Timestamp? dateIncurred = data['dateIncurred'];
        final double remainingDebt = (data['remainingDebtAmount'] ?? 0.0).toDouble();
        
        // Filter by date range in code
        if (dateIncurred != null &&
            dateIncurred.compareTo(startTimestamp) >= 0 &&
            dateIncurred.compareTo(endTimestamp) <= 0) {
          debt += remainingDebt;
          debtCount++;
        }
      }

      print('✅ Fetched ${debtSnapshot.docs.length} PENDING debts, $debtCount in date range');

      // Query expenses - fetch all and filter by date in code
      // (Using same pattern as debt_history to avoid potential permission issues)
      final expensesSnapshot = await _firestore
          .collection('expenses')
          .doc(businessId)
          .collection('userExpenses')
          .get();

      double expenses = 0.0;
      int expenseCount = 0;
      
      print('🔍 Filtering expenses: start=${startTimestamp.toDate()}, end=${endTimestamp.toDate()}');
      
      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        final Timestamp? date = data['date'];
        final double amount = (data['amount'] ?? 0.0).toDouble();
        
        if (date != null) {
          print('  📝 Expense: date=${date.toDate()}, amount=$amount');
        }
        
        // Filter by date range in code
        if (date != null &&
            date.compareTo(startTimestamp) >= 0 &&
            date.compareTo(endTimestamp) <= 0) {
          expenses += amount;
          expenseCount++;
          print('  ✅ INCLUDED in range');
        } else {
          print('  ❌ EXCLUDED from range');
        }
      }

      print('✅ Fetched ${expensesSnapshot.docs.length} total expenses, $expenseCount in date range');
      print('💰 Total expenses amount: $expenses');

      // Query purchases (recovered collection) - fetch all and filter by date in code
      // (Using same pattern to avoid potential permission issues)
      final purchasesSnapshot = await _firestore
          .collection('recovered')
          .doc(businessId)
          .collection('userRecovered')
          .get();

      double purchasesPaid = 0.0;
      double purchasesCashPaid = 0.0;
      int purchaseCount = 0;

      for (var doc in purchasesSnapshot.docs) {
        final data = doc.data();
        final Timestamp? date = data['date'];
        
        // Filter by date range in code
        if (date != null &&
            date.compareTo(startTimestamp) >= 0 &&
            date.compareTo(endTimestamp) <= 0) {
          final payment = (data['payment'] ?? 0.0).toDouble();
          final paymentMethod = data['paymentMethod'] ?? 'cash';
          
          purchasesPaid += payment;
          
          if (paymentMethod.toString().toLowerCase() == 'cash') {
            purchasesCashPaid += payment;
          }
          purchaseCount++;
        }
      }

      print('✅ Fetched ${purchasesSnapshot.docs.length} total purchases, $purchaseCount in date range');
      
      // Debug: Print all fetched values
      print('📊 === REPORT DATA SUMMARY ===');
      print('💰 Total Sales (Original Price): $totalSales');
      print('💰 Total Payment (Cash Received): $totalPayment');
      print('💰 Debt (Credit Sales): $debt');
      print('💰 Actual Revenue: payment + debt = ${totalPayment + debt}');
      print('💰 Discounts Given: ${totalSales - (totalPayment + debt)}');
      print('💰 Total Sales Buying Price (COGS): $totalSalesBuying');
      print('💰 Expenses: $expenses');
      print('💰 Purchases Paid: $purchasesPaid');
      print('💰 Purchases Cash Paid: $purchasesCashPaid');
      print('📊 ──────────────────────────────');
      print('📊 Net Profit = (totalPayment + debt) - totalSalesBuying - expenses');
      print('📊 Net Profit = ($totalPayment + $debt) - $totalSalesBuying - $expenses');
      print('📊 Net Profit = ${(totalPayment + debt) - totalSalesBuying - expenses}');
      print('📊 ==========================');

      return {
        'totalSales': totalSales,
        'totalSalesBuying': totalSalesBuying,
        'totalPayment': totalPayment,
        'debt': debt,
        'expenses': expenses,
        'purchasesPaid': purchasesPaid,
        'purchasesCashPaid': purchasesCashPaid,
      };
    } catch (e) {
      print('❌ Error fetching data from Firestore: $e');
      errorSnackbar('Error fetching data: $e');
      return {
        'totalSales': 0.0,
        'totalSalesBuying': 0.0,
        'totalPayment': 0.0,
        'debt': 0.0,
        'expenses': 0.0,
        'purchasesPaid': 0.0,
        'purchasesCashPaid': 0.0,
      };
    }
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
