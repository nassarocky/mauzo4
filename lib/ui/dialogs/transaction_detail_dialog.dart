import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/product_model.dart';
import 'package:mauzo/models/stock_transaction.dart';
import 'package:mauzo/constants/transaction_constants.dart';
import 'package:mauzo/utils/constants.dart';

class TransactionDetailDialog extends StatelessWidget {
  final StockTransaction transaction;
  final Product product;

  const TransactionDetailDialog({
    Key? key,
    required this.transaction,
    required this.product,
  }) : super(key: key);

  String formatDateTime(DateTime dateTime) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
  }

  String formatCurrency(double amount, String currency) {
    final formatCurrency = NumberFormat.currency(
      symbol: currency,
      decimalDigits: 2,
    );
    return formatCurrency.format(amount);
  }

  Color getTransactionColor(String type, String origin) {
    if (origin == TransactionOrigins.saleDeleted) {
      return Colors.deepOrange;
    }
    // Sales should be blue (not red) since they're revenue-generating
    if (origin == 'Sale' || origin.contains('Sale')) {
      return Colors.blue;
    }
    // Additions are green
    if (type == 'addition') {
      return Colors.green;
    }
    // Other reductions (damaged, expired, stolen, etc.) are red
    return Colors.red;
  }

  IconData getTransactionIcon(String type, String origin) {
    if (origin == TransactionOrigins.saleDeleted) {
      return Icons.delete_sweep_outlined;
    }
    return type == 'addition'
        ? Icons.add_circle_outline
        : Icons.remove_circle_outline;
  }

  @override
  Widget build(BuildContext context) {
    final BusinessController businessController = Get.find();
    final currency = businessController.business['mainCurrency'] ?? 'TZS';

    final isAddition = transaction.delta != null
        ? transaction.delta! >= 0
        : transaction.transactionType == 'addition';
    final beforeQty = transaction.previousQuantity;

    final bool isCFTransferTransaction =
        transaction.transactionOrigin == 'Product Transfer Out' ||
        transaction.transactionOrigin == 'Product Transfer In' ||
        transaction.transactionOrigin == 'Batch Transfer Out' ||
        transaction.transactionOrigin == 'Batch Transfer In';

    final double quantityChange;
    final double afterQty;
    if (transaction.delta != null) {
      quantityChange = transaction.delta!.abs();
      afterQty = transaction.newQuantity ?? beforeQty + transaction.delta!;
    } else if (isCFTransferTransaction) {
      afterQty = transaction.newQuantity ?? transaction.quantity;
      quantityChange = (beforeQty - afterQty).abs();
    } else {
      quantityChange = transaction.quantity;
      afterQty =
          transaction.newQuantity ??
          (isAddition
              ? beforeQty + quantityChange
              : beforeQty - quantityChange);
    }

    final totalValue =
        transaction.totalValue ?? (quantityChange * transaction.price);
    final estimatePrefix = transaction.quantityEstimated ? '~' : '';
    final transactionColor = getTransactionColor(
      transaction.transactionType,
      transaction.transactionOrigin,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with close button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: transactionColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      getTransactionIcon(
                        transaction.transactionType,
                        transaction.transactionOrigin,
                      ),
                      color: transactionColor,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Transaction Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: transactionColor,
                            ),
                          ),
                          Text(
                            transaction.transactionOrigin.tr,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Product Info
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: product.image ?? '',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.inventory_2, size: 40),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.inventory_2, size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (product.code != null && product.code!.isNotEmpty)
                            Text(
                              'Code: ${product.code}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          Text(
                            'Category: ${product.category ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Quantity Change Visualization
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Quantity Change',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Before
                        Column(
                          children: [
                            Text(
                              'Before',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$estimatePrefix${beforeQty.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Arrow with change
                        Column(
                          children: [
                            Icon(
                              Icons.arrow_forward,
                              size: 32,
                              color: transactionColor,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: transactionColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${isAddition ? '+' : '-'}${quantityChange.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: transactionColor,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // After
                        Column(
                          children: [
                            Text(
                              'After',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: transactionColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: transactionColor,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                '$estimatePrefix${afterQty.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: transactionColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Transaction Details
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(
                      icon: Icons.receipt_long,
                      label: 'Transaction ID',
                      value: transaction.transactionId,
                      copyable: true,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.access_time,
                      label: 'Date & Time',
                      value: formatDateTime(transaction.timestamp.toDate()),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.attach_money,
                      label: 'Unit Price',
                      value: formatCurrency(transaction.price, currency),
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.calculate,
                      label: 'Total Value',
                      value: formatCurrency(totalValue, currency),
                      valueColor: transactionColor,
                    ),
                    if (transaction.employeeName != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.person,
                        label: 'Employee',
                        value: transaction.employeeName!,
                      ),
                    ],
                    if (transaction.referenceId != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.link,
                        label: 'Reference',
                        value:
                            '${transaction.referenceType ?? 'Document'} #${transaction.referenceId}',
                        copyable: true,
                      ),
                    ],
                    if (transaction.notes != null &&
                        transaction.notes!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        icon: Icons.note,
                        label: 'Notes',
                        value: transaction.notes!,
                      ),
                    ],
                  ],
                ),
              ),

              // Close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: transactionColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool copyable = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: valueColor ?? Colors.black87,
                      ),
                    ),
                  ),
                  if (copyable)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: value));
                        Get.snackbar(
                          'Copied',
                          'Copied to clipboard',
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 1),
                        );
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
