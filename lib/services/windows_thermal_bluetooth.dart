import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_thermal_printer_windows/flutter_thermal_printer_windows.dart'
    as win;
import 'package:get/get.dart';

/// Windows-only Bluetooth thermal helpers.
///
/// Isolated so [ThermalPrinterService] can call this only when
/// `defaultTargetPlatform == TargetPlatform.windows`.
class WindowsThermalBluetooth {
  WindowsThermalBluetooth._();

  static final _api = win.ThermalPrinterWindows.instance;

  static Future<List<win.BluetoothPrinter>> listPrinters({
    Duration scanTimeout = const Duration(seconds: 12),
  }) async {
    final Map<String, win.BluetoothPrinter> byId = {};
    try {
      for (final p in await _api.getPairedPrinters()) {
        byId[p.id] = p;
      }
    } catch (e) {
      debugPrint('Windows getPairedPrinters: $e');
    }
    try {
      for (final p in await _api.scanForPrinters(timeout: scanTimeout)) {
        byId[p.id] = p;
      }
    } catch (e) {
      debugPrint('Windows scanForPrinters: $e');
    }
    return byId.values.toList();
  }

  static Future<void> connect(win.BluetoothPrinter printer) async {
    if (!printer.isPaired) {
      await _api.pairPrinter(printer);
    }
    await _api.connect(printer, printSampleOnSuccess: false);
  }

  static Future<void> disconnect(win.BluetoothPrinter printer) async {
    await _api.disconnect(printer);
  }

  static Future<void> printRaw(
    win.BluetoothPrinter printer,
    List<int> bytes,
  ) async {
    await _api.printRawBytes(printer, Uint8List.fromList(bytes));
  }
}
