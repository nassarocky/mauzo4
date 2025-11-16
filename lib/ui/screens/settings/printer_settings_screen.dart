import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../services/thermal_printer_service.dart';
import '../../widgets/printer_selection_dialog.dart';

class PrinterSettingsScreen extends StatelessWidget {
  const PrinterSettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize printer service if not already done
    if (!Get.isRegistered<ThermalPrinterService>()) {
      Get.put(ThermalPrinterService());
    }
    final ThermalPrinterService printerService = Get.find();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thermal Printer Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Connection Status Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bluetooth, size: 32),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Printer Connection',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Obx(() => Text(
                                printerService.isConnected.value
                                    ? 'Connected'
                                    : 'Not Connected',
                                style: TextStyle(
                                  color: printerService.isConnected.value
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              )),
                            ],
                          ),
                        ),
                        Obx(() => Icon(
                          printerService.isConnected.value
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: printerService.isConnected.value
                              ? Colors.green
                              : Colors.grey,
                          size: 32,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Printer Card
            Obx(() {
              if (printerService.selectedPrinter.value != null) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Selected Printer',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.print, color: Colors.blue),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    printerService.selectedPrinter.value!.name ?? 'Unknown',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    printerService.selectedPrinter.value!.address ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 16),

            // Action Buttons
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) => const PrinterSelectionDialog(),
                  );
                },
                icon: const Icon(Icons.search),
                label: const Text('Select Printer'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Obx(() {
              if (printerService.isConnected.value) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await printerService.disconnect();
                      Get.snackbar(
                        'Disconnected',
                        'Printer disconnected successfully',
                        snackPosition: SnackPosition.BOTTOM,
                        backgroundColor: Colors.orange,
                        colorText: Colors.white,
                      );
                    },
                    icon: const Icon(Icons.bluetooth_disabled),
                    label: const Text('Disconnect'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      backgroundColor: Colors.red,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            const SizedBox(height: 32),

            // Info Section
            const Text(
              'Setup Instructions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.settings_bluetooth, color: Colors.blue),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Step 1: Pair Your Printer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 36),
                      child: Text(
                        '1. Turn on your thermal printer\n'
                        '2. Open Android Settings\n'
                        '3. Go to Bluetooth settings\n'
                        '4. Scan and pair with your printer\n'
                        '   (Usually named: BlueTooth Printer, TP-***)',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.print, color: Colors.green),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Step 2: Connect in App',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 36),
                      child: Text(
                        '1. Tap "Select Printer" above\n'
                        '2. Tap "Scan for Printers"\n'
                        '3. Select your printer from the list\n'
                        '4. Wait for connection confirmation',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.receipt, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Step 3: Print Receipts',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.only(left: 36),
                      child: Text(
                        '1. Go to any sale in Sales screen\n'
                        '2. Tap the blue "Thermal" button\n'
                        '3. Receipt will print automatically',
                        style: TextStyle(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.amber.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.amber),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Compatible with ESC/POS thermal printers (58mm or 80mm)',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
