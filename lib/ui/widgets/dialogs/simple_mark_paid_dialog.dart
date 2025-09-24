import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mauzo/models/payment_record_model.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class SimpleMarkPaidDialog extends StatefulWidget {
  final PaymentRecord payment;

  const SimpleMarkPaidDialog({
    Key? key,
    required this.payment,
  }) : super(key: key);

  @override
  State<SimpleMarkPaidDialog> createState() => _SimpleMarkPaidDialogState();
}

class _SimpleMarkPaidDialogState extends State<SimpleMarkPaidDialog> {
  final ProfileController _profileController = Get.find();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();

  PaymentMethod selectedPaymentMethod = PaymentMethod.cash;
  bool isLoading = false;

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 550),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mark Payment as Paid',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.headlineSmall!.color,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Payment Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Employee: ${widget.payment.employeeName}'),
                  Text('Business: ${widget.payment.businessName}'),
                  Text('Amount: ${widget.payment.getFormattedAmount('TZS')}'),
                  Text('Due Date: ${widget.payment.formatDate(widget.payment.dueDate)}'),
                  Text('Pay Period: ${widget.payment.getFormattedPayPeriod()}'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Method
            Text('Payment Method *'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<PaymentMethod>(
                  value: selectedPaymentMethod,
                  isExpanded: true,
                  items: PaymentMethod.values.map((method) {
                    return DropdownMenuItem<PaymentMethod>(
                      value: method,
                      child: Text(_getPaymentMethodLabel(method)),
                    );
                  }).toList(),
                  onChanged: (PaymentMethod? value) {
                    if (value != null) {
                      setState(() {
                        selectedPaymentMethod = value;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Reference Number
            Text('Reference Number'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _referenceController,
              decoration: InputDecoration(
                hintText: 'Transaction ID, Receipt number, etc.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Notes
            Text('Notes (Optional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Payment notes...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: isLoading ? null : () {
                      print('=== BUTTON TAPPED ===');
                      _markAsPaidDirect();
                    },
                    child: Text(
                      isLoading ? 'Processing...' : 'Mark as Paid',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPaymentMethodLabel(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.bank_transfer:
        return 'Bank Transfer';
      case PaymentMethod.mobile_money:
        return 'Mobile Money';
      case PaymentMethod.check:
        return 'Check';
    }
  }

  Future<void> _markAsPaidDirect() async {
    print('=== DIRECT MARK AS PAID STARTED ===');
    
    setState(() {
      isLoading = true;
    });

    try {
      final currentUserId = _profileController.user['id'] ?? '';
      print('Current user ID: $currentUserId');
      
      if (currentUserId.isEmpty) {
        throw Exception('User not logged in');
      }

      final updateData = {
        'status': 'paid',
        'paymentMethod': selectedPaymentMethod.toString().split('.').last,
        'referenceNumber': _referenceController.text.isNotEmpty 
            ? _referenceController.text : null,
        'paidDate': FieldValue.serverTimestamp(),
        'paidBy': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
        'notes': _notesController.text.isNotEmpty 
            ? _notesController.text : null,
      };

      print('Updating payment ${widget.payment.id} with data: $updateData');

      // Direct Firestore update
      await FirebaseFirestore.instance
          .collection('paymentRecords')
          .doc(widget.payment.id)
          .update(updateData);

      print('Firestore update completed successfully');

      // Show success message
      Get.snackbar(
        'Success',
        'Payment marked as paid successfully',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      // Close dialog
      Navigator.of(context).pop(true);

    } catch (e) {
      print('Error updating payment: $e');
      Get.snackbar(
        'Error',
        'Failed to mark payment as paid: $e',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }
}
