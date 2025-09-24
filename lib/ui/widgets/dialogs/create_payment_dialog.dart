import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/payment_controller.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/models/pay_role_model.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class CreatePaymentDialog extends StatefulWidget {
  const CreatePaymentDialog({Key? key}) : super(key: key);

  @override
  State<CreatePaymentDialog> createState() => _CreatePaymentDialogState();
}

class _CreatePaymentDialogState extends State<CreatePaymentDialog> {
  final PaymentController _paymentController = Get.find();
  final PayRoleController _payRoleController = Get.put(PayRoleController());

  PayRoleModel? selectedPayRole;
  DateTime payPeriodStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime payPeriodEnd = DateTime.now();
  DateTime dueDate = DateTime.now().add(const Duration(days: 5));
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Create Payment Record',
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

            // Employee Selection
            Text('Select Employee *', 
                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Obx(() {
                final activePayRoles = _payRoleController.payRoles
                    .where((pr) => pr.isActive)
                    .toList();

                return DropdownButtonHideUnderline(
                  child: DropdownButton<PayRoleModel>(
                    value: selectedPayRole,
                    hint: const Text('Choose employee...'),
                    isExpanded: true,
                    items: activePayRoles.map((payRole) {
                      return DropdownMenuItem<PayRoleModel>(
                        value: payRole,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(payRole.employeeName),
                            Text(
                              '${payRole.businessName} - ${payRole.getFormattedPayRate()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (PayRoleModel? value) {
                      setState(() {
                        selectedPayRole = value;
                      });
                    },
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Pay Period Start
            Text('Pay Period Start *', 
                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context, true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Text('${payPeriodStart.day}/${payPeriodStart.month}/${payPeriodStart.year}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pay Period End
            Text('Pay Period End *', 
                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context, false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Text('${payPeriodEnd.day}/${payPeriodEnd.month}/${payPeriodEnd.year}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Due Date
            Text('Due Date *', 
                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDueDate(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 20),
                    const SizedBox(width: 8),
                    Text('${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                  ],
                ),
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
                  child: PrimaryButton(
                    text: isLoading ? 'Creating...' : 'Create Payment',
                    onPressed: isLoading ? null : _createPayment,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? payPeriodStart : payPeriodEnd,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          payPeriodStart = picked;
        } else {
          payPeriodEnd = picked;
        }
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        dueDate = picked;
      });
    }
  }

  Future<void> _createPayment() async {
    if (selectedPayRole == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final success = await _paymentController.createPaymentRecord(
        payRole: selectedPayRole!,
        payPeriodStart: payPeriodStart,
        payPeriodEnd: payPeriodEnd,
        dueDate: dueDate,
      );

      if (success) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to create payment: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
