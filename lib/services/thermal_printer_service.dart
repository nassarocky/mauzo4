import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sale_model.dart';
import '../models/client_model.dart';

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
    final connected = await PrintBluetoothThermal.connectionStatus;
    isConnected.value = connected;
  }

  /// Start scanning for Bluetooth printers
  Future<void> startScan() async {
    isScanning.value = true;
    devices.clear();
    
    try {
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

  /// Stop scanning
  void stopScan() {
    isScanning.value = false;
  }

  /// Select and connect to a printer
  Future<void> selectPrinter(BluetoothInfo device) async {
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
          productName = product['name']?.toString() ?? '';
          quantity = double.tryParse(product['quantity']?.toString() ?? '0') ?? 0;
          price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
        } else {
          productName = product.name ?? '';
          quantity = product.quantity ?? 0;
          price = product.price ?? 0;
        }

        final itemTotal = quantity * price;
        subtotal += itemTotal;

        String line = productName.padRight(12).substring(0, 12);
        line += quantity.toString().padLeft(5);
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
      bytes += Uint8List.fromList('Thank you for your business!\n'.codeUnits);
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
