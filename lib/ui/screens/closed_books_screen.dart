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
    double totalSales, totalSalesBuying, totalPayment, debt, debtCollected, expenses, purchasesPaid, purchasesCashPaid;
    
    if (customStart != null) {
      // Custom date range: Query Firestore directly
      print('📊 Generating custom report from Firestore: ${startTimestamp.toDate()} to ${endTimestamp.toDate()}');
      
      final results = await _fetchDataFromFirestore(startTimestamp, endTimestamp);
      totalSales = results['totalSales']!;
      totalSalesBuying = results['totalSalesBuying']!;
      totalPayment = results['totalPayment']!;
      debt = results['debt']!;
      debtCollected = results['debtCollected']!;
      expenses = results['expenses']!;
      purchasesPaid = results['purchasesPaid']!;
      purchasesCashPaid = results['purchasesCashPaid']!;
    } else {
      // Default report: Use already loaded data from controllers
      print('📊 Generating default report from loaded data');
      
      totalSales = _saleController.getTotalSalesFromTimestamp(startTimestamp, endTimestamp);
      totalSalesBuying = _saleController.getTotalSalesBuyingFromTimestamp(startTimestamp, endTimestamp);
      totalPayment = _saleController.getTotalPaymentFromTimestamp(startTimestamp, endTimestamp);
      
      // ALWAYS fetch debt from Firestore to avoid race condition with controller loading
      // Controller data may not be loaded yet when report is generated quickly
      print('🔄 Fetching debt directly from Firestore to avoid race condition...');
      final debtResults = await _fetchDebtFromFirestore(startTimestamp, endTimestamp);
      debt = debtResults['debt']!;
      
      debtCollected = _saleController.getDebtCollectedFromTimestamp(startTimestamp, endTimestamp);
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
      debtCollected: debtCollected,
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
              SizedBox(height: 16),
              Text('Net Profit Calculation Breakdown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 8),
              _buildProfitCalculationBreakdown(book),
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
        _buildTableRow('${'TOTAL PAYMENTS (Cash In) + DEBT COLLECTED:'.tr}', book.totalPayment + book.debtCollected, _businessController.business['mainCurrency']),
        _buildTableRow('${'COGS (Buying Price):'.tr}', book.reserveDouble2 ?? 0.0, _businessController.business['mainCurrency']),
        _buildTableRow('${'PURCHASES PAID'.tr}', book.reserveDouble1 ?? 0.0, _businessController.business['mainCurrency']),
        _buildTableRow('${'DEBT (Created in Period):'.tr}', book.debt, _businessController.business['mainCurrency']),
        _buildTableRow('${'DEBT COLLECTED (Old Debt Paid):'.tr}', book.debtCollected, _businessController.business['mainCurrency']),
        _buildTableRow('${'EXPENSES:'.tr}', book.expenses, _businessController.business['mainCurrency']),
        _buildTableRow(
          '${'Available balance (payments + debt collected - expenses - purchases paid)'.tr}',
          (book.totalPayment + book.debtCollected - book.expenses - (book.totalPurchase)),
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

  Widget _buildProfitCalculationBreakdown(CloseBook book) {
    final totalPayment = book.totalPayment;
    final debt = book.debt;
    final cogs = book.reserveDouble2 ?? 0.0;
    final expenses = book.expenses;
    final netProfit = book.netProfit;
    
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Formula: Net Profit = (Total Payment + Debt) - COGS - Expenses',
            style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
          ),
          Divider(thickness: 1),
          _buildCalculationRow('Total Payment (Cash In)', totalPayment, book.currency),
          _buildCalculationRow('+ Debt (Credit Sales)', debt, book.currency, isAddition: true),
          Divider(thickness: 1),
          _buildCalculationRow('= Revenue', totalPayment + debt, book.currency, isBold: true),
          Divider(thickness: 1),
          _buildCalculationRow('- COGS (Cost of Goods Sold)', cogs, book.currency, isSubtraction: true),
          _buildCalculationRow('- Expenses', expenses, book.currency, isSubtraction: true),
          Divider(thickness: 2),
          _buildCalculationRow(
            '= NET PROFIT',
            netProfit,
            book.currency,
            isBold: true,
            isResult: true,
            isNegative: netProfit < 0,
          ),
          if (netProfit < 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 16),
                  SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Negative profit: Your costs (COGS + Expenses) exceed your revenue',
                      style: TextStyle(color: Colors.red, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalculationRow(
    String label,
    double value,
    String currency, {
    bool isAddition = false,
    bool isSubtraction = false,
    bool isBold = false,
    bool isResult = false,
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isResult ? 14 : 12,
                color: isNegative ? Colors.red : (isResult ? Colors.green.shade700 : Colors.black87),
              ),
            ),
          ),
          Text(
            '$currency ${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isResult ? 14 : 12,
              color: isNegative ? Colors.red : (isResult ? Colors.green.shade700 : Colors.black87),
            ),
          ),
        ],
      ),
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
        _buildPDFTableRow('TOTAL PAYMENTS (Cash In) + DEBT COLLECTED:'.tr, book.totalPayment + book.debtCollected, book.currency),
        _buildPDFTableRow('COGS (Buying Price):'.tr, book.reserveDouble2 ?? 0.0, book.currency),
        _buildPDFTableRow(
            'PURCHASES PAID:'.tr,
            book.reserveDouble1 ?? 0.0, // Use the double value directly or default to 0.0
            book.currency
        ),

        _buildPDFTableRow('DEBT (Created in Period):'.tr, book.debt, book.currency),
        _buildPDFTableRow('DEBT COLLECTED (Old Debt Paid):'.tr, book.debtCollected, book.currency),
        _buildPDFTableRow('EXPENSES:'.tr, book.expenses, book.currency),
        _buildPDFTableRow(
          'Available balance (payments + debt collected - expenses - purchases paid)'.tr,
          (book.totalPayment + book.debtCollected - book.expenses - (book.totalPurchase)),
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
        'debtCollected': 0.0,
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
      double debtCollected = 0.0;

      for (var doc in salesSnapshot.docs) {
        final data = doc.data();
        final saleType = data['saleType'] ?? 'original';
        
        // Track debt repayment separately - these are collections on old debts
        if (saleType == 'debt_repayment') {
          debtCollected += (data['payment'] ?? 0.0).toDouble();
          continue;
        }
        
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
      
      print('🔍 === FIRESTORE DEBT CALCULATION DEBUG ===');
      print('📅 Report Period: ${startTimestamp.toDate()} to ${endTimestamp.toDate()}');
      print('📊 Total PENDING debts fetched: ${debtSnapshot.docs.length}');
      
      for (var doc in debtSnapshot.docs) {
        final data = doc.data();
        final Timestamp? dateIncurred = data['dateIncurred'];
        // Use INITIAL debt amount (when sale was made), not remaining debt
        // This ensures we count the full credit extended in the period, not what's still owed
        final double initialDebt = (data['initialDebtAmount'] ?? 0.0).toDouble();
        final String client = data['client'] ?? 'Unknown';
        
        if (dateIncurred != null) {
          print('  💳 Debt: Client=$client, Amount=$initialDebt');
          print('     Date Incurred: ${dateIncurred.toDate()}');
          print('     Start Compare: ${dateIncurred.compareTo(startTimestamp)} (>=0 means after start)');
          print('     End Compare: ${dateIncurred.compareTo(endTimestamp)} (<=0 means before end)');
        } else {
          print('  ⚠️ Debt with NULL dateIncurred: Client=$client, Amount=$initialDebt');
        }
        
        // Filter by date range in code
        if (dateIncurred != null &&
            dateIncurred.compareTo(startTimestamp) >= 0 &&
            dateIncurred.compareTo(endTimestamp) <= 0) {
          debt += initialDebt;
          debtCount++;
          print('     ✅ INCLUDED in period - Added $initialDebt');
        } else {
          print('     ❌ EXCLUDED from period');
        }
      }

      print('📊 === FIRESTORE DEBT SUMMARY ===');
      print('Total PENDING debts: ${debtSnapshot.docs.length}');
      print('Debts in Date Range: $debtCount');
      print('Total Debt Amount: $debt');
      print('===================================');
      
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
        'debtCollected': debtCollected,
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
        'debtCollected': 0.0,
        'expenses': 0.0,
        'purchasesPaid': 0.0,
        'purchasesCashPaid': 0.0,
      };
    }
  }

  /// Fetch only debt data from Firestore for reliable calculation
  /// Avoids race condition with controller data loading
  Future<Map<String, double>> _fetchDebtFromFirestore(Timestamp startTimestamp, Timestamp endTimestamp) async {
    final String? businessId = _businessController.businessId.value;
    
    if (businessId == null || businessId.isEmpty) {
      print('❌ Business ID is null, cannot fetch debt');
      return {'debt': 0.0};
    }

    try {
      // Query debt history - fetch PENDING debts only and filter by date in code
      final debtSnapshot = await _firestore
          .collection('debtHistory')
          .doc(businessId)
          .collection('clientDebtHistory')
          .where('status', isEqualTo: 'PENDING')
          .get();

      double debt = 0.0;
      int debtCount = 0;
      
      print('🔍 === DIRECT DEBT FETCH (AVOIDING RACE CONDITION) ===');
      print('📅 Report Period: ${startTimestamp.toDate()} to ${endTimestamp.toDate()}');
      print('📊 Total PENDING debts fetched: ${debtSnapshot.docs.length}');
      
      for (var doc in debtSnapshot.docs) {
        final data = doc.data();
        final Timestamp? dateIncurred = data['dateIncurred'];
        final double initialDebt = (data['initialDebtAmount'] ?? 0.0).toDouble();
        final String client = data['client'] ?? 'Unknown';
        
        if (dateIncurred != null) {
          print('  💳 Debt: Client=$client, Amount=$initialDebt');
          print('     Date Incurred: ${dateIncurred.toDate()}');
          print('     Start Compare: ${dateIncurred.compareTo(startTimestamp)} (>=0 means after start)');
          print('     End Compare: ${dateIncurred.compareTo(endTimestamp)} (<=0 means before end)');
        } else {
          print('  ⚠️ Debt with NULL dateIncurred: Client=$client, Amount=$initialDebt');
        }
        
        // Filter by date range in code
        if (dateIncurred != null &&
            dateIncurred.compareTo(startTimestamp) >= 0 &&
            dateIncurred.compareTo(endTimestamp) <= 0) {
          debt += initialDebt;
          debtCount++;
          print('     ✅ INCLUDED in period - Added $initialDebt');
        } else {
          print('     ❌ EXCLUDED from period');
        }
      }

      print('📊 === DIRECT DEBT FETCH SUMMARY ===');
      print('Total PENDING debts: ${debtSnapshot.docs.length}');
      print('Debts in Date Range: $debtCount');
      print('Total Debt Amount: $debt');
      print('===================================');

      return {'debt': debt};
    } catch (e) {
      print('❌ Error fetching debt from Firestore: $e');
      return {'debt': 0.0};
    }
  }
}

void _showDeleteConfirmation(
  BuildContext context,
  CloseBook book,
  BusinessController businessController,
  ClosedBooksController closedBooksController,
) {
  final DateFormat formatter = DateFormat('dd MMM yyyy, hh:mm a');
  
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('Delete Report'.tr),
        content: Text(
          '${'Are you sure you want to delete this report?'.tr}\n\n'
          '${'Report Period:'.tr}\n'
          '${formatter.format(book.startDate)} - ${formatter.format(book.endDate)}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close confirmation dialog first
              Navigator.of(dialogContext).pop();
              
              // Show loading indicator
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext loadingContext) {
                  return WillPopScope(
                    onWillPop: () async => false,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Deleting report...'.tr),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
              
              try {
                final String businessId = businessController.business['id'];
                await closedBooksController.deleteClosedBook(businessId, book.id);
                
                // Close loading dialog using root navigator
                Navigator.of(context, rootNavigator: true).pop();
                
                // Show success message
                successSnackbar('Report deleted successfully!'.tr);
              } catch (e) {
                // Close loading dialog using root navigator
                Navigator.of(context, rootNavigator: true).pop();
                
                // Show error message
                errorSnackbar('Error deleting report: $e'.tr);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('delete'.tr),
          ),
        ],
      );
    },
  );
}

class ReportCard extends StatelessWidget {
  final CloseBook book;
  final VoidCallback onTap;

  const ReportCard({required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final DateFormat formatter = DateFormat('dd MMM yyyy, hh:mm a');
    final ProfileController profileController = Get.find();
    final BusinessController businessController = Get.find();
    final ClosedBooksController closedBooksController = Get.find();
    
    // Check if user is owner or manager
    final bool canDelete = profileController.isManagerOrOwner();
    
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (String value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation(
                      context,
                      book,
                      businessController,
                      closedBooksController,
                    );
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('delete'.tr, style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            if (!canDelete)
              Icon(Icons.arrow_forward_ios, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
