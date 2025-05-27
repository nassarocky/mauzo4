import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedBusinessId;
  DateTime? _selectedDate;
  bool _isLoading = false;
  String _errorMessage = '';

  final _pdf = pw.Document();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  Future<List<QueryDocumentSnapshot>> _getBusinesses() async {
    final query = await _firestore
        .collection('businesses')
        .where('subscriptionStatus', isEqualTo: 'subscription_ok')
        .get();
    return query.docs;
  }

  Future<void> _generateReport() async {
    if (_selectedBusinessId == null || _selectedDate == null) {
      setState(() => _errorMessage = 'Please select business and date');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final reportsRef = _firestore
          .collection('productReports')
          .doc(_selectedBusinessId)
          .collection('userReports');

      final reportDateStart = Timestamp.fromDate(DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
      ));

      final reportDateEnd = Timestamp.fromDate(DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        23,
        59,
        59,
      ));

      final querySnapshot = await reportsRef
          .where('reportDate', isGreaterThanOrEqualTo: reportDateStart)
          .where('reportDate', isLessThanOrEqualTo: reportDateEnd)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() => _errorMessage = 'No report found for selected date');
        return;
      }

      final businessDoc = await _firestore
          .collection('businesses')
          .doc(_selectedBusinessId)
          .get();

      _pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) => _buildReportContent(
            querySnapshot.docs,
            businessDoc.data()!,
          ),
        ),
      );

      final output = await getDownloadsDirectory();
      final file = File('${output?.path}/report_${_selectedDate}.pdf');
      await file.writeAsBytes(await _pdf.save());

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => _pdf.save(),
      );

    } catch (e) {
      setState(() => _errorMessage = 'Error generating report: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  pw.Widget _buildReportContent(
      List<QueryDocumentSnapshot> reports, Map<String, dynamic> businessData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
            level: 0,
            child: pw.Text('Daily Product Report - ${_dateFormat.format(_selectedDate!)}')),

        pw.SizedBox(height: 20),
        _businessInfoSection(businessData),
        pw.SizedBox(height: 30),

        for (final report in reports)
          _productSection(report.data() as Map<String, dynamic>),
      ],
    );
  }

  pw.Widget _businessInfoSection(Map<String, dynamic> businessData) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Business Name: ${businessData['name']}'),
        pw.Text('Business ID: $_selectedBusinessId'),
        pw.Text('Report Date: ${_dateFormat.format(_selectedDate!)}'),
      ],
    );
  }

  pw.Widget _productSection(Map<String, dynamic> report) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(level: 1, child: pw.Text(report['productName'])),
        pw.Text('Category: ${report['productCategory']}'),
        pw.Text('Price: \$${report['productPrice'].toStringAsFixed(2)}'),
        pw.SizedBox(height: 10),
        _transactionTable(report['breakdown']),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _transactionTable(List<dynamic> breakdown) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: pw.FlexColumnWidth(2),
        1: pw.FlexColumnWidth(3),
        2: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          children: [
            pw.Padding(
              child: pw.Text('Timestamp', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              padding: pw.EdgeInsets.all(4),
            ),
            pw.Padding(
              child: pw.Text('Transaction Type', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              padding: pw.EdgeInsets.all(4),
            ),
            pw.Padding(
              child: pw.Text('Quantity Change', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              padding: pw.EdgeInsets.all(4),
            ),
          ],
        ),
        for (final entry in breakdown)
          pw.TableRow(
            children: [
              pw.Padding(
                child: pw.Text(_formatTimestamp(entry['timestamp'])),
                padding: pw.EdgeInsets.all(4),
              ),
              pw.Padding(
                child: pw.Text(entry['transactionType']),
                padding: pw.EdgeInsets.all(4),
              ),
              pw.Padding(
                child: pw.Text(entry['change'].toString()),
                padding: pw.EdgeInsets.all(4),
              ),
            ],
          ),
      ],
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    return DateFormat('MM/dd/yyyy HH:mm').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Generate Product Report')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            FutureBuilder<List<QueryDocumentSnapshot>>(
              future: _getBusinesses(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                return DropdownButton<String>(
                  hint: Text('Select Business'),
                  value: _selectedBusinessId,
                  items: snapshot.data!.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc['name']),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedBusinessId = value),
                );
              },
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              child: Text(_selectedDate == null
                  ? 'Select Date'
                  : 'Selected Date: ${_dateFormat.format(_selectedDate!)}'),
            ),
            SizedBox(height: 20),
            if (_isLoading) CircularProgressIndicator(),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: TextStyle(color: Colors.red)),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateReport,
              child: Text('Generate PDF Report'),
            ),
          ],
        ),
      ),
    );
  }
}