import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/business_controller.dart';
import '../../controllers/supplier_debt_controller.dart';
import '../../controllers/profile_controller.dart';
import '../../models/supplier_debt_model.dart';
import '../../utils/constants.dart';
import '../../utils/preferences.dart';
import '../widgets/buttons/primary_button.dart';

class SupplierDebtScreen extends StatefulWidget {
  const SupplierDebtScreen({Key? key}) : super(key: key);

  @override
  State<SupplierDebtScreen> createState() => _SupplierDebtScreenState();
}

class _SupplierDebtScreenState extends State<SupplierDebtScreen> {
  final SupplierDebtController _supplierDebtController = Get.find();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();
  final TextEditingController _searchController = TextEditingController();
  String? _filterDebtId; // when set, show only this specific debt

  @override
  void initState() {
    super.initState();
    // Set default filter to Pending
    _supplierDebtController.setFilterStatus(["PENDING"]);
    // Check for navigation argument to filter a specific debt id
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map && args['filterDebtId'] is String) {
        final String id = (args['filterDebtId'] as String).trim();
        if (id.isNotEmpty) {
          setState(() {
            _filterDebtId = id;
          });
          // Show all statuses to ensure the target debt is visible
          _supplierDebtController.setFilterStatus([]);
        }
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    _searchController.dispose();
    Timer.run(() {
      _supplierDebtController.filteredSupplierDebts.value =
          _supplierDebtController.supplierDebts;
    });
  }

  /// Build a row of filter buttons: All, Pending, Paid.
  Widget buildFilterButtons() {
    return Obx(() {
      final filter = _supplierDebtController.filterStatus;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: () => _supplierDebtController.setFilterStatus([]),
            style: ElevatedButton.styleFrom(
              backgroundColor: filter.isEmpty ? primaryColor : Colors.grey[300],
              foregroundColor: filter.isEmpty ? Colors.white : Colors.black,
            ),
            child: Text('All'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _supplierDebtController.setFilterStatus(["PENDING"]),
            style: ElevatedButton.styleFrom(
              backgroundColor: filter.contains("PENDING") ? primaryColor : Colors.grey[300],
              foregroundColor: filter.contains("PENDING") ? Colors.white : Colors.black,
            ),
            child: Text('Pending'),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _supplierDebtController.setFilterStatus(["PAID"]),
            style: ElevatedButton.styleFrom(
              backgroundColor: filter.contains("PAID") ? primaryColor : Colors.grey[300],
              foregroundColor: filter.contains("PAID") ? Colors.white : Colors.black,
            ),
            child: Text('Paid'),
          ),
        ],
      );
    });
  }

  /// Build a debt card for each supplier debt
  Widget buildSupplierDebtCard(SupplierDebt debt) {
    final currency = _businessController.business['mainCurrency'] ?? 'USD';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Supplier name and status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    debt.supplierName.isEmpty ? 'Unknown Supplier' : debt.supplierName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: debt.status == 'paid' 
                        ? Colors.green 
                        : debt.status == 'partially_paid'
                            ? Colors.orange
                            : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    debt.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Debt amounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Initial Debt',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      formatCurrency(debt.initialDebtAmount, currency),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Remaining',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      formatCurrency(debt.remainingDebtAmount, currency),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: debt.remainingDebtAmount > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Date and employee info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Date: ${DateFormat('dd/MM/yyyy').format(debt.dateIncurred.toDate())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (debt.employeeName.isNotEmpty)
                  Text(
                    'By: ${debt.employeeName}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            
            // Comment
            if (debt.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${debt.comment}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            
            // Payment button for pending debts
            if (debt.remainingDebtAmount > 0 && _profileController.hasPermission('manage_supplier_debt')) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  text: 'Make Payment',
                  color: primaryColor,
                  onPressed: () => _showPaymentDialog(debt),
                ),
              ),
            ],
            
            // Payment history
            if (debt.paymentRecords.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(),
              const Text(
                'Payment History:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...debt.paymentRecords.map((payment) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('dd/MM/yyyy').format((payment['date'] as Timestamp).toDate()),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      formatCurrency(payment['amount'], currency),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ],
        ),
      ),
    );
  }

  /// Show payment dialog
  void _showPaymentDialog(SupplierDebt debt) {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController noteController = TextEditingController();
    String selectedMethod = 'Cash';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pay ${debt.supplierName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Remaining debt: ${formatCurrency(debt.remainingDebtAmount, _businessController.business['mainCurrency'])}'),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Payment Amount',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedMethod,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                border: OutlineInputBorder(),
              ),
              items: ['Cash', 'Bank Transfer', 'Mobile Money', 'Check']
                  .map((method) => DropdownMenuItem(
                        value: method,
                        child: Text(method),
                      ))
                  .toList(),
              onChanged: (value) => selectedMethod = value ?? 'Cash',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Payment Note (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && amount > 0) {
                _supplierDebtController.makePayment(
                  debtId: debt.id,
                  paymentAmount: amount,
                  paymentMethod: selectedMethod,
                  paymentNote: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                );
                Navigator.pop(context);
              } else {
                errorSnackbar('Please enter a valid payment amount');
              }
            },
            child: const Text('Pay'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Preferences.getTheme()
          ? Theme.of(context).scaffoldBackgroundColor
          : const Color(0xFFE5E5E5),
      appBar: AppBar(
        title: const Text(
          'Supplier Debts',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search suppliers...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) => _supplierDebtController.searchSupplierDebtsByName(value),
            ),
          ),
          
          // Filter buttons
          buildFilterButtons(),
          const SizedBox(height: 16),
          
          // Total debt summary
          Obx(() {
            final totalDebt = _supplierDebtController.totalSupplierDebt;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Outstanding Debt:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatCurrency(totalDebt, _businessController.business['mainCurrency']),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: totalDebt > 0 ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          
          // Debt list
          Expanded(
            child: Obx(() {
              final debts = _supplierDebtController.filteredSupplierDebts;
              // If a specific debt id is requested, narrow down the list
              final displayDebts = (_filterDebtId != null && _filterDebtId!.isNotEmpty)
                  ? debts.where((d) => d.id == _filterDebtId).toList()
                  : debts;
              
              if (displayDebts.isEmpty) {
                return const Center(
                  child: Text(
                    'No supplier debts found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                );
              }
              
              return ListView.builder(
                itemCount: displayDebts.length,
                itemBuilder: (context, index) {
                  return buildSupplierDebtCard(displayDebts[index]);
                },
              );
            }),
          ),
        ],
      ),
    );
  }
}
