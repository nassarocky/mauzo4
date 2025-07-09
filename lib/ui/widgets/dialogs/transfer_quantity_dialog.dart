import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/models/product_model.dart';
import 'package:mauzo/ui/widgets/buttons/primary_button.dart';
import 'package:mauzo/ui/widgets/buttons/secondary_button.dart';

class TransferQuantityDialog extends StatefulWidget {
  final Product product;
  final String fromBusinessId;
  final String toBusinessId;
  final Function(String fromBusinessId, String toBusinessId, double quantity) onConfirm;

  const TransferQuantityDialog({
    Key? key,
    required this.product,
    required this.fromBusinessId,
    required this.toBusinessId,
    required this.onConfirm,
  }) : super(key: key);

  @override
  State<TransferQuantityDialog> createState() => _TransferQuantityDialogState();
}

class _TransferQuantityDialogState extends State<TransferQuantityDialog> {
  final TextEditingController _quantityController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set initial value to 1
    _quantityController.text = '1';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  void _handleConfirm() {
    final quantity = double.tryParse(_quantityController.text.trim());
    if (quantity == null || quantity <= 0) {
      Get.snackbar(
        'Error'.tr,
        'Please enter a valid quantity greater than 0'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final currentQuantity = widget.product.quantity ?? 0.0;
    if (quantity > currentQuantity) {
      Get.snackbar(
        'Error'.tr,
        'Transfer quantity cannot exceed available quantity (${currentQuantity.toStringAsFixed(2)})'.tr,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    widget.onConfirm(widget.fromBusinessId, widget.toBusinessId, quantity);
    
    setState(() {
      _isLoading = false;
    });
    
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  color: Colors.blue[700],
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Transfer Product'.tr,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Product info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Available: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${widget.product.quantity?.toStringAsFixed(2) ?? '0.00'}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Quantity input
            Text(
              'Transfer Quantity'.tr,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Enter quantity to transfer'.tr,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: Icon(Icons.inventory, color: Colors.grey[600]),
                suffixText: 'units',
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'Cancel'.tr,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    text: _isLoading ? 'Processing...'.tr : 'Transfer'.tr,
                    onPressed: _isLoading ? () {} : _handleConfirm,
                    color: Colors.blue[700] ?? Colors.blue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 