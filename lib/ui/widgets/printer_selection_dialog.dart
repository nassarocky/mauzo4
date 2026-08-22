import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../services/thermal_printer_service.dart';

class PrinterSelectionDialog extends StatelessWidget {
  const PrinterSelectionDialog({Key? key}) : super(key: key);

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Widget build(BuildContext context) {
    final ThermalPrinterService printerService = Get.find();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isWindows
                      ? 'Select Printer (Windows)'
                      : 'Select Bluetooth Printer',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
            if (_isWindows) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    printerService.chooseSystemPrintDialog();
                    Get.back();
                  },
                  icon: const Icon(Icons.print),
                  label: const Text('Use Windows print dialog'),
                ),
              ),
            ],
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isWindows
                          ? 'Pair the thermal printer in Windows Bluetooth settings first, then scan here. Or use the Windows print dialog for USB printers.'
                          : 'First pair your printer in Android Bluetooth Settings, then scan here',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: Obx(() {
                if (printerService.devices.isEmpty &&
                    !printerService.isScanning.value) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.print_disabled,
                              size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text(
                            'No Bluetooth printers found',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
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
                                _buildStep(
                                  '2',
                                  _isWindows
                                      ? 'Open Windows Settings → Bluetooth'
                                      : 'Open Android Settings',
                                ),
                                const SizedBox(height: 8),
                                _buildStep(
                                  '3',
                                  _isWindows
                                      ? 'Pair with your printer'
                                      : 'Go to Bluetooth',
                                ),
                                const SizedBox(height: 8),
                                _buildStep(
                                  '4',
                                  _isWindows
                                      ? 'Come back and tap Scan'
                                      : 'Pair with your printer',
                                ),
                                if (!_isWindows) ...[
                                  const SizedBox(height: 8),
                                  _buildStep('5', 'Come back and tap Scan'),
                                ],
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
                        Icon(Icons.bluetooth_searching,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('Scanning…', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: printerService.devices.length,
                  itemBuilder: (context, index) {
                    final device = printerService.devices[index];
                    final isSelected = printerService
                            .selectedPrinter.value?.macAdress ==
                        device.macAdress;

                    return Card(
                      color: isSelected ? Colors.blue.shade50 : null,
                      child: ListTile(
                        leading: Icon(
                          Icons.print,
                          color: isSelected ? Colors.blue : Colors.grey,
                        ),
                        title: Text(
                          device.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(device.macAdress),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.blue)
                            : null,
                        onTap: () async {
                          await printerService.selectPrinter(device);
                          if (printerService.isConnected.value) {
                            Get.back();
                          }
                        },
                      ),
                    );
                  },
                );
              }),
            ),

            Obx(() {
              if (printerService.selectedPrinter.value != null) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(top: 12),
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
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            Text(
                              printerService.selectedPrinter.value!.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
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
