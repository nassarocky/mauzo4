import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../models/client_model.dart';
import '../../../utils/constants.dart';


class AdvanceTransactionsSheet extends StatelessWidget {
  final Client client;
  const AdvanceTransactionsSheet({Key? key, required this.client}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Assuming client.advanceTransactions is a List of maps with keys: 'amount' and 'time'
    // If they are stored as Firestore Timestamps, convert them to DateTime.
    List<Map<String, dynamic>> transactions = List<Map<String, dynamic>>.from(
      client.advanceTransactions,
    );

    // Sort transactions by time descending (latest first)
    transactions.sort((a, b) {
      Timestamp ta = a['time'] ?? Timestamp(0,0);
      Timestamp tb = b['time'] ?? Timestamp(0,0);
      return tb.compareTo(ta);
    });

    return Container(
      padding: const EdgeInsets.all(16),
      // Optionally set a height
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advance Transactions',
            style: h6(Theme.of(context).textTheme.titleLarge!.color),
          ),
          const SizedBox(height: 8),
          Text(
            'Current Advance: ${formatCurrency(client.advance, _getMainCurrency())}',
            style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
          ),
          const Divider(),
          Expanded(
            child: transactions.isNotEmpty
                ? ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final txn = transactions[index];
                final amount = txn['amount'] as num? ?? 0;
                final timestamp = txn['time'] as Timestamp?;
                final dateStr = timestamp != null
                    ? DateFormat('dd/MM/yyyy, hh:mm a').format(timestamp.toDate())
                    : 'Unknown date';
                return ListTile(
                  leading: Icon(
                    amount >= 0 ? Icons.add_circle : Icons.remove_circle,
                    color: amount >= 0 ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    '${amount >= 0 ? '+' : ''}${amount.toString()}',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(dateStr),
                );
              },
            )
                : Center(
              child: Text('No advance transactions available.'.tr),
            ),
          ),
        ],
      ),
    );
  }

  String _getMainCurrency() {
    // Replace with your actual logic to get main currency from your business controller.
    // For example:
    // final businessController = Get.find<BusinessController>();
    // return businessController.business['mainCurrency'];
    return "TZS";
  }
}
