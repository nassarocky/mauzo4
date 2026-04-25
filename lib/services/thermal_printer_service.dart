import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/sale_model.dart';
import '../models/client_model.dart';
import '../utils/sale_line_quantity.dart';
import '../utils/receipt_footer.dart';

class ThermalPrinterService extends GetxController {
  final RxList<BluetoothInfo> devices = <BluetoothInfo>[].obs;
  final Rx<BluetoothInfo?> selectedPrinter = Rx<BluetoothInfo?>(null);
  final RxBool isConnected = false.obs;
  final RxBool isScanning = false.obs;

  @override
  void onInit() {
    super.onInit();
    _checkConnection();
  }

  /// Check if connected to a printer
  Future<void> _checkConnection() async {
    // On web and Windows desktop, Bluetooth thermal plugin is not used
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      isConnected.value = false;
      return;
    }
    try {
      final connected = await PrintBluetoothThermal.connectionStatus;
      isConnected.value = connected;
    } catch (_) {
      isConnected.value = false;
    }
  }

  /// Start scanning for Bluetooth printers
  Future<void> startScan() async {
    isScanning.value = true;
    devices.clear();
    
    try {
      // On web and Windows desktop, scanning is not supported in this flow
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        isScanning.value = false;
        Get.snackbar(
          'Desktop Printing',
          'On desktop, use the system print dialog when printing a receipt.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.blue,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        return;
      }
      // Request Bluetooth permissions
      bool permissionGranted = await _requestBluetoothPermissions();
      
      if (!permissionGranted) {
        Get.snackbar(
          'Permission Required',
          'Bluetooth permissions are required to scan for printers',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
        isScanning.value = false;
        return;
      }
      
      // Scan for paired Bluetooth devices
      final results = await PrintBluetoothThermal.pairedBluetooths;
      devices.value = results;
      
      if (results.isEmpty) {
        Get.snackbar(
          'No Printers Found',
          'Please pair your printer in Android Bluetooth settings first',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      print('Error scanning: $e');
      Get.snackbar(
        'Scan Error',
        'Failed to scan for printers: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    isScanning.value = false;
  }
  
  /// Request Bluetooth permissions
  Future<bool> _requestBluetoothPermissions() async {
    try {
      print('Checking Bluetooth permissions...');
      
      // Check Android 12+ permissions
      final bluetoothScanStatus = await Permission.bluetoothScan.status;
      final bluetoothConnectStatus = await Permission.bluetoothConnect.status;
      
      print('Bluetooth Scan status: $bluetoothScanStatus');
      print('Bluetooth Connect status: $bluetoothConnectStatus');
      
      // If already granted, return true
      if (bluetoothScanStatus.isGranted && bluetoothConnectStatus.isGranted) {
        print('Bluetooth permissions already granted');
        return true;
      }
      
      // If denied, request them
      if (bluetoothScanStatus.isDenied || bluetoothConnectStatus.isDenied) {
        print('Requesting Bluetooth permissions...');
        Map<Permission, PermissionStatus> statuses = await [
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
        ].request();
        
        print('Permission request result: $statuses');
        
        // Check if permanently denied
        if (statuses.values.any((status) => status.isPermanentlyDenied)) {
          Get.snackbar(
            'Permission Denied',
            'Please enable Bluetooth permissions in app settings',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
            mainButton: TextButton(
              onPressed: () => openAppSettings(),
              child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
            ),
          );
          return false;
        }
        
        // Check if all permissions were granted
        return statuses.values.every((status) => status.isGranted);
      }
      
      // If restricted or limited, try anyway
      print('Bluetooth permissions in restricted state, proceeding...');
      return true;
    } catch (e) {
      print('Permission check error: $e');
      // If permission check fails, try to proceed anyway
      // (might be on older Android where these permissions don't exist)
      return true;
    }
  }

  /// Desktop (Windows) implementation using PDF + OS print dialog (58mm paper width)
  Future<void> _printReceiptDesktop({
    required Sale sale,
    required Client client,
    required Map<String, dynamic> business,
    String? employeeName,
  }) async {
    final doc = pw.Document();

    // 58mm roll-like format (approx. long page). Use generous height to avoid truncation.
    // If your pdf version supports roll57, you can replace with PdfPageFormat.roll57
    final pageFormat = PdfPageFormat(58 * PdfPageFormat.mm, 300 * PdfPageFormat.mm);
    final pageTheme = pw.PageTheme(
      pageFormat: pageFormat,
      margin: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    );

    // Prepare receipt content
    final currency = (business['mainCurrency'] ?? '').toString();
    final businessName = (business['name'] ?? 'Business Name').toString();
    final businessPhone = (business['phone'] ?? '').toString();
    final businessTin = business['tin']?.toString();
    final dateTime = sale.date.toDate();

    // Build items and totals
    double subtotal = 0;
    final List<pw.TableRow> itemRows = [];

    itemRows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Text('Item', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Text('Qty', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ),
        ],
      ),
    );

    for (var product in sale.products) {
      String productName = '';
      double quantity = 0;
      double price = 0;

      if (product is Map<String, dynamic>) {
        final pm = Map<String, dynamic>.from(product);
        productName = pm['name']?.toString() ?? '';
        quantity = saleLineDisplayQuantity(pm);
        price = double.tryParse(pm['price']?.toString() ?? '0') ?? 0;
      } else {
        // Fallback for typed product objects
        try {
          // ignore: avoid_dynamic_calls
          productName = (product.name ?? '').toString();
          // ignore: avoid_dynamic_calls
          quantity = (product.quantity ?? 0).toDouble();
          // ignore: avoid_dynamic_calls
          price = (product.price ?? 0).toDouble();
        } catch (_) {}
      }

      final itemTotal = quantity * price;
      subtotal += itemTotal;

      itemRows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(productName, style: const pw.TextStyle(fontSize: 8), maxLines: 1, overflow: pw.TextOverflow.clip),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(
              () {
                if (product is Map<String, dynamic>) {
                  final pm = Map<String, dynamic>.from(product);
                  final q = saleLineDisplayQuantity(pm);
                  final lab = saleLineUomLabel(pm);
                  final qs = q == q.roundToDouble()
                      ? (q == q.truncateToDouble()
                          ? q.toInt().toString()
                          : q.toStringAsFixed(2))
                      : q.toStringAsFixed(2);
                  if (lab != null && lab.isNotEmpty) return '$qs $lab';
                  return qs;
                }
                return quantity.toStringAsFixed(0);
              }(),
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 8),
            ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Text(itemTotal.toStringAsFixed(0), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
            ),
          ],
        ),
      );
    }

    final payment = sale.payment;
    final debt = sale.price - sale.payment;

    doc.addPage(
      pw.MultiPage(
        pageTheme: pageTheme,
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  businessName,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              if (businessPhone.isNotEmpty)
                pw.Center(
                  child: pw.Text('Phone: $businessPhone', style: const pw.TextStyle(fontSize: 8)),
                ),
              if (businessTin != null && businessTin.isNotEmpty)
                pw.Center(
                  child: pw.Text('TIN: $businessTin', style: const pw.TextStyle(fontSize: 8)),
                ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),
              pw.Center(child: pw.Text('RECEIPT', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
              pw.SizedBox(height: 4),

              // Meta
              pw.Text('Receipt #: ${DateFormat('yyyyMMddHHmm').format(dateTime)}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(dateTime)}', style: const pw.TextStyle(fontSize: 8)),
              pw.Text('Client: ${client.name}', style: const pw.TextStyle(fontSize: 8)),
              if (employeeName != null)
                pw.Text('Served by: $employeeName', style: const pw.TextStyle(fontSize: 8)),

              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1),

              // Items
              pw.Table(
                border: null,
                columnWidths: const {
                  0: pw.FlexColumnWidth(3),
                  1: pw.FlexColumnWidth(1),
                  2: pw.FlexColumnWidth(1),
                },
                children: itemRows,
              ),

              pw.Divider(thickness: 1),

              // Totals
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('$currency ${subtotal.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Payment:', style: const pw.TextStyle(fontSize: 9)),
                  pw.Text('$currency ${payment.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              if (debt > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Balance Due:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('$currency ${debt.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                )
              else if (debt < 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Change:', style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('$currency ${(-debt).toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),

              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  receiptFooterMessage(business),
                  style: const pw.TextStyle(fontSize: 9),
                  textAlign: pw.TextAlign.center,
                ),
              ),

              // Payment details
              ...() {
                final List paymentDetails = (business['invoicePaymentDetails'] as List? ?? [])
                    .where((e) => (e as Map)['showOnInvoice'] == true)
                    .toList();
                if (paymentDetails.isEmpty) return <pw.Widget>[];
                return <pw.Widget>[
                  pw.SizedBox(height: 6),
                  pw.Divider(thickness: 0.5),
                  pw.Center(child: pw.Text('Payment Details', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                  pw.SizedBox(height: 4),
                  ...paymentDetails.map<pw.Widget>((pd) {
                    final m = pd as Map;
                    final label = m['type'] == 'bank' ? 'Bank' : 'Mobile';
                    return pw.Text('$label | ${m['provider']}: ${m['number']}', style: const pw.TextStyle(fontSize: 7));
                  }),
                ];
              }(),
            ],
          )
        ],
      ),
    );

    // Show OS print dialog and print
    await Printing.layoutPdf(
      name: 'Receipt',
      format: pageFormat,
      onLayout: (PdfPageFormat _) async => doc.save(),
    );
  }

  /// Stop scanning
  void stopScan() {
    isScanning.value = false;
  }

  /// Select and connect to a printer
  Future<void> selectPrinter(BluetoothInfo device) async {
    // On web and Windows desktop, Bluetooth selection is not required
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      Get.snackbar(
        'Desktop Printing',
        'Bluetooth selection is not needed on desktop. Use the print dialog.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
      return;
    }
    // Show loading dialog
    Get.dialog(
      const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Connecting to printer...'),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
    
    try {
      print('=== Connecting to printer: ${device.name} (${device.macAdress}) ===');
      
      // Check Bluetooth permissions first
      bool permissionGranted = await _requestBluetoothPermissions();
      if (!permissionGranted) {
        Get.back(); // Close loading dialog
        Get.snackbar(
          'Permission Required',
          'Bluetooth permissions are required to connect',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
        return;
      }
      
      print('Permissions granted');
      
      // Disconnect from current printer if connected
      if (isConnected.value) {
        print('Disconnecting from current printer...');
        await PrintBluetoothThermal.disconnect;
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Connect to new printer
      print('Attempting connection to ${device.macAdress}...');
      final connected = await PrintBluetoothThermal.connect(macPrinterAddress: device.macAdress);
      print('Connection result: $connected');
      
      Get.back(); // Close loading dialog
      
      if (connected == true) {
        selectedPrinter.value = device;
        isConnected.value = true;
        
        print('Successfully connected!');
        
        Get.snackbar(
          'Connected',
          'Connected to ${device.name}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 2),
        );
      } else {
        print('Connection returned false');
        throw Exception('Connection failed - printer may be off or out of range');
      }
    } catch (e) {
      print('Connection error: $e');
      Get.back(); // Close loading dialog if still open
      Get.snackbar(
        'Connection Failed',
        'Failed to connect: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    }
  }

  /// Print receipt for a sale
  Future<void> printReceipt({
    required Sale sale,
    required Client client,
    required Map<String, dynamic> business,
    String? employeeName,
  }) async {
    // On Windows desktop, use OS printing via PDF (58mm) instead of Bluetooth
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        await _printReceiptDesktop(
          sale: sale,
          client: client,
          business: business,
          employeeName: employeeName,
        );
        Get.snackbar(
          'Success',
          'Receipt sent to printer',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } catch (e) {
        Get.snackbar(
          'Print Error',
          'Failed to print on desktop: $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
      return;
    }

    if (!isConnected.value || selectedPrinter.value == null) {
      Get.snackbar(
        'Not Connected',
        'Please select and connect to a printer first',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    try {
      List<int> bytes = [];

      // Header
      bytes += Uint8List.fromList('\n'.codeUnits);
      bytes += Uint8List.fromList('${business['name'] ?? 'Business Name'}\n'.codeUnits);
      bytes += Uint8List.fromList('Phone: ${business['phone'] ?? ''}\n'.codeUnits);

      if (business['tin'] != null && business['tin'].toString().isNotEmpty) {
        bytes += Uint8List.fromList('TIN: ${business['tin']}\n'.codeUnits);
      }

      bytes += Uint8List.fromList('--------------------------------\n'.codeUnits);
      bytes += Uint8List.fromList('RECEIPT\n'.codeUnits);
      bytes += Uint8List.fromList('\n'.codeUnits);

      // Receipt details
      final dateTime = sale.date.toDate();
      bytes += Uint8List.fromList('Receipt #: ${DateFormat('yyyyMMddHHmm').format(dateTime)}\n'.codeUnits);
      bytes += Uint8List.fromList('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(dateTime)}\n'.codeUnits);
      bytes += Uint8List.fromList('Client: ${client.name}\n'.codeUnits);
      
      if (employeeName != null) {
        bytes += Uint8List.fromList('Served by: $employeeName\n'.codeUnits);
      }

      bytes += Uint8List.fromList('--------------------------------\n'.codeUnits);

      // Items header with currency
      final currency = business['mainCurrency'] ?? '';
      bytes += Uint8List.fromList('\n'.codeUnits);
      bytes += Uint8List.fromList('Item         Qty  Price($currency)\n'.codeUnits);
      bytes += Uint8List.fromList('--------------------------------\n'.codeUnits);

      // Items
      double subtotal = 0;

      for (var product in sale.products) {
        String productName = '';
        double quantity = 0;
        double price = 0;

        if (product is Map<String, dynamic>) {
          final pm = Map<String, dynamic>.from(product);
          productName = pm['name']?.toString() ?? '';
          quantity = saleLineDisplayQuantity(pm);
          price = double.tryParse(pm['price']?.toString() ?? '0') ?? 0;
        } else {
          productName = product.name ?? '';
          quantity = product.quantity ?? 0;
          price = product.price ?? 0;
        }

        final itemTotal = quantity * price;
        subtotal += itemTotal;

        String line = productName.padRight(12).substring(0, 12);
        final qtyStr = product is Map<String, dynamic>
            ? () {
                final pm = Map<String, dynamic>.from(product as Map);
                final q = saleLineDisplayQuantity(pm);
                final lab = saleLineUomLabel(pm);
                final qs = q == q.roundToDouble()
                    ? (q == q.truncateToDouble()
                        ? q.toInt().toString()
                        : q.toStringAsFixed(2))
                    : q.toStringAsFixed(2);
                if (lab != null && lab.isNotEmpty) return '$qs $lab';
                return qs;
              }()
            : quantity.toStringAsFixed(0);
        line += qtyStr.padLeft(5);
        line += itemTotal.toStringAsFixed(0).padLeft(11);
        bytes += Uint8List.fromList('$line\n'.codeUnits);
      }

      bytes += Uint8List.fromList('--------------------------------\n'.codeUnits);

      // Totals
      bytes += Uint8List.fromList('Subtotal: $currency ${subtotal.toStringAsFixed(0)}\n'.codeUnits);
      bytes += Uint8List.fromList('Payment: $currency ${sale.payment.toStringAsFixed(0)}\n'.codeUnits);

      final debt = sale.price - sale.payment;
      if (debt > 0) {
        bytes += Uint8List.fromList('Balance Due: $currency ${debt.toStringAsFixed(0)}\n'.codeUnits);
      } else if (debt < 0) {
        bytes += Uint8List.fromList('Change: $currency ${(-debt).toStringAsFixed(0)}\n'.codeUnits);
      }

      bytes += Uint8List.fromList('--------------------------------\n'.codeUnits);
      bytes += Uint8List.fromList('\n'.codeUnits);
      final footerText = receiptFooterMessage(business);
      for (final line in footerText.split('\n')) {
        bytes += Uint8List.fromList('$line\n'.codeUnits);
      }

      // Payment details
      final List paymentDetailsList = (business['invoicePaymentDetails'] as List? ?? [])
          .where((e) => (e as Map)['showOnInvoice'] == true)
          .toList();
      if (paymentDetailsList.isNotEmpty) {
        bytes += Uint8List.fromList('--------------------------------\n'.codeUnits);
        bytes += Uint8List.fromList('Payment Details:\n'.codeUnits);
        for (final pd in paymentDetailsList) {
          final m = pd as Map;
          final label = m['type'] == 'bank' ? 'Bank' : 'Mobile';
          bytes += Uint8List.fromList('$label: ${m['provider']}\n'.codeUnits);
          bytes += Uint8List.fromList('  ${m['number']}\n'.codeUnits);
        }
      }

      bytes += Uint8List.fromList('\n\n\n'.codeUnits);
      
      // Send to printer - print_bluetooth_thermal expects List<int>
      print('Sending ${bytes.length} bytes to printer...');
      await PrintBluetoothThermal.writeBytes(bytes);
      print('Print command sent successfully');
      
      Get.snackbar(
        'Success',
        'Receipt printed successfully',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to print: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  /// Disconnect from printer
  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
      isConnected.value = false;
      selectedPrinter.value = null;
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  @override
  void onClose() {
    disconnect();
    super.onClose();
  }
}
