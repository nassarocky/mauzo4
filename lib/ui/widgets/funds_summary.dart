import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/utils/constants.dart';

class FundsSummary extends StatelessWidget {
  FundsSummary({Key? key, this.start, this.end}) : super(key: key);
  final DateTime? start;
  final DateTime? end;
  final BusinessController _businessController = Get.find();

  @override
  Widget build(BuildContext context) {
    final String? businessId = _businessController.business['id'] ?? _businessController.businessId.value;
    if (businessId == null || businessId.isEmpty) {
      return const SizedBox.shrink();
    }

    final String baseCurrency = _businessController.business['mainCurrency'] ?? 'TZS';

    final fundSourcesRef = FirebaseFirestore.instance
        .collection('fundSources')
        .doc(businessId)
        .collection('userFundSources');

    final ledgerRef = FirebaseFirestore.instance
        .collection('ledger')
        .doc(businessId)
        .collection('entries');

    // Determine effective time window: provided start/end or fallback to business reset_time -> now
    final Timestamp? resetTs = _businessController.business['reset_time'];
    final DateTime? effectiveStart = start ?? resetTs?.toDate();
    final DateTime effectiveEnd = end ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row removed per request; direct content below
              StreamBuilder<QuerySnapshot>(
                stream: fundSourcesRef.snapshots(),
                builder: (context, fundSourcesSnap) {
                  if (!fundSourcesSnap.hasData) {
                    return const Center(child: SizedBox(height: 40, width: 40, child: CircularProgressIndicator(strokeWidth: 2)));
                  }
                  final fundSources = fundSourcesSnap.data!.docs.map((d) => d.data() as Map<String, dynamic>).toList();

                  // Build ledger query with postedAt range if a start is available
                  return StreamBuilder<QuerySnapshot>(
                    stream: (() {
                      Query<Map<String, dynamic>> q = ledgerRef.orderBy('postedAt', descending: true);
                      if (effectiveStart != null) {
                        q = q
                            .where('postedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(effectiveStart))
                            .where('postedAt', isLessThan: Timestamp.fromDate(effectiveEnd));
                      }
                      return q.snapshots();
                    })(),
                    builder: (context, ledgerSnap) {
                      if (!ledgerSnap.hasData) {
                        return const Center(child: SizedBox(height: 40, width: 40, child: CircularProgressIndicator(strokeWidth: 2)));
                      }

                      // Compute balances per fundSourceId in base currency
                      final Map<String, double> balances = {};
                      for (final doc in ledgerSnap.data!.docs) {
                        final m = doc.data() as Map<String, dynamic>;
                        final String fsId = (m['fundSourceId'] ?? '').toString();
                        if (fsId.isEmpty) continue;
                        final String direction = (m['direction'] ?? 'in').toString();
                        final double baseAmount = (m['baseAmount'] is int)
                            ? (m['baseAmount'] as int).toDouble()
                            : ((m['baseAmount'] ?? 0.0) as num).toDouble();
                        final String rowBaseCurrency = (m['baseCurrency'] ?? baseCurrency).toString();
                        // Only aggregate rows that match current baseCurrency for clean display
                        if (rowBaseCurrency != baseCurrency) continue;
                        final delta = direction == 'out' ? -baseAmount : baseAmount;
                        balances[fsId] = (balances[fsId] ?? 0.0) + delta;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...fundSources.map((fs) {
                            final String id = (fs['type'] ?? 'cash').toString();
                            final String name = (fs['name'] ?? id).toString();
                            final String type = (fs['type'] ?? 'cash').toString();
                            final double bal = (balances[id] ?? 0.0);
                            return _fundSourceRow(context, name, type, bal, baseCurrency);
                          }),
                          // Removed Cash-in-hand row; cash balance is shown under cash fund source
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fundSourceRow(BuildContext context, String name, String type, double balance, String currency) {
    final Color chipColor = type == 'cash'
        ? Colors.green.shade600
        : (type == 'bank' ? Colors.blue.shade600 : (type == 'mobile' ? Colors.orange.shade600 : Colors.purple.shade600));
    final IconData icon = type == 'cash'
        ? Icons.payments
        : (type == 'bank' ? Icons.account_balance : (type == 'mobile' ? Icons.phone_android : Icons.account_balance_wallet));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: chipColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: chipColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 14, color: chipColor),
                const SizedBox(width: 6),
                Text(name, style: TextStyle(color: chipColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Spacer(),
          Text(
            formatCurrency(balance, currency),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          )
        ],
      ),
    );
  }
}
