import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/stock_transaction.dart';
import 'package:mauzo/models/product_model.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../constants/transaction_constants.dart';
import '../../../utils/constants.dart';
import '../../dialogs/transaction_detail_dialog.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    Key? key,
    required this.transaction, required this.product
  }) : super(key: key);

  final StockTransaction transaction;
  final Product product;

  String formatTimestamp(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    String formattedDate = DateFormat('yyyy-MM-dd – HH:mm').format(dateTime);
    return formattedDate;
  }

  String formatCurrency(double amount) {
    final formatCurrency = NumberFormat.currency(symbol: '', decimalDigits: 0);
    return formatCurrency.format(amount);
  }
  
  String getTimeAgo(Timestamp timestamp) {
    return timeago.format(timestamp.toDate(), locale: 'en_short');
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
    return type == 'addition' ? Icons.add_circle : Icons.remove_circle;
  }

  @override
  Widget build(BuildContext context) {
    final BusinessController businessController = Get.find();
    final currency = businessController.business['mainCurrency'] ?? 'TZS';
    
    // Calculate values
    final isAddition = transaction.transactionType == 'addition';
    final beforeQty = transaction.previousQuantity;

    // Cloud Function transactions store the new stock level in 'quantity' instead of the
    // change amount. Detect and recalculate for those origins.
    final bool isCFTransferTransaction =
        transaction.transactionOrigin == 'Product Transfer Out' ||
        transaction.transactionOrigin == 'Product Transfer In';

    final double quantityChange;
    final double afterQty;
    if (isCFTransferTransaction) {
      afterQty = transaction.newQuantity ?? transaction.quantity;
      quantityChange = (beforeQty - afterQty).abs();
    } else {
      quantityChange = transaction.quantity;
      afterQty = transaction.newQuantity ??
          (isAddition ? beforeQty + quantityChange : beforeQty - quantityChange);
    }

    final totalValue = transaction.totalValue ?? (quantityChange * transaction.price);
    final transactionColor = getTransactionColor(transaction.transactionType, transaction.transactionOrigin);
    
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => TransactionDetailDialog(
            transaction: transaction,
            product: product,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: transactionColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: product.image ?? '',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.inventory_2, size: 30),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.inventory_2, size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Transaction Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Before → After with arrow
                    Row(
                      children: [
                        Text(
                          'Before: ${beforeQty.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: transactionColor,
                        ),
                        Text(
                          'After: ${afterQty.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: transactionColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${isAddition ? '+' : '-'}${quantityChange.toStringAsFixed(1)})',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: transactionColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Transaction Origin & Reference
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: transactionColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            transaction.transactionOrigin.tr,
                            style: TextStyle(
                              fontSize: 11,
                              color: transactionColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (transaction.referenceId != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.link, size: 12, color: Colors.grey[600]),
                          const SizedBox(width: 2),
                          Text(
                            '#${transaction.referenceId!.substring(0, 6)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (transaction.employeeName != null || transaction.notes != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (transaction.employeeName != null) ...[
                            Icon(Icons.person, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 2),
                            Text(
                              transaction.employeeName!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                          if (transaction.notes != null) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.note, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                transaction.notes!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Right side - Value & Time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currency ${formatCurrency(totalValue)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: transactionColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    getTimeAgo(transaction.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    getTransactionIcon(transaction.transactionType, transaction.transactionOrigin),
                    color: transactionColor,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
