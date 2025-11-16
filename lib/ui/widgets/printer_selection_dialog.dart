import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../services/thermal_printer_service.dart';

class PrinterSelectionDialog extends StatelessWidget {
  const PrinterSelectionDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ThermalPrinterService printerService = Get.find();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Bluetooth Printer',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scan button
            Obx(() => ElevatedButton.icon(
              onPressed: printerService.isScanning.value
                  ? null
                  : () => printerService.startScan(),
              icon: printerService.isScanning.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(
                printerService.isScanning.value
                    ? 'Scanning...'
                    : 'Scan for Printers',
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
              ),
            )),
            const SizedBox(height: 16),

            // Important notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'First pair your printer in Android Bluetooth Settings, then scan here',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Devices list
            Expanded(
              child: Obx(() {
                if (printerService.devices.isEmpty && !printerService.isScanning.value) {
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.print_disabled, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            'No paired Bluetooth printers found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'To add a printer:',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildStep('1', 'Turn on your thermal printer'),
                                const SizedBox(height: 8),
                                _buildStep('2', 'Open Android Settings'),
                                const SizedBox(height: 8),
                                _buildStep('3', 'Go to Bluetooth'),
                                const SizedBox(height: 8),
                                _buildStep('4', 'Pair with your printer'),
                                const SizedBox(height: 8),
                                _buildStep('5', 'Come back and tap Scan'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (printerService.devices.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bluetooth_disabled, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No printers found',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tap "Scan for Printers" to start',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bluetooth_searching, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Paired Bluetooth Printers',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Obx(() => Text(
                                printerService.isScanning.value
                                    ? 'Scanning paired devices...'
                                    : '${printerService.devices.length} paired devices found',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: printerService.devices.length,
                        itemBuilder: (context, index) {
                          final device = printerService.devices[index];
                          final isSelected = printerService.selectedPrinter.value?.macAdress == device.macAdress;

                          return Card(
                            color: isSelected ? Colors.blue.shade50 : null,
                            child: ListTile(
                              leading: Icon(
                                Icons.print,
                                color: isSelected ? Colors.blue : Colors.grey,
                              ),
                              title: Text(
                                device.name ?? 'Unknown Device',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              subtitle: Text(device.macAdress),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle, color: Colors.blue)
                                  : null,
                              onTap: () async {
                                await printerService.selectPrinter(device);
                                // Only close dialog if connection was successful
                                if (printerService.isConnected.value) {
                                  Get.back();
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),

            // Selected printer info
            Obx(() {
              if (printerService.selectedPrinter.value != null) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.blue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Printer',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              printerService.selectedPrinter.value!.name ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
