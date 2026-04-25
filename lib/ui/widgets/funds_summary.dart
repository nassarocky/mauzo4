import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';

class FundsSummary extends StatelessWidget {
  FundsSummary({
    Key? key,
    this.start,
    this.end,
    this.compact = false,
    this.sheetLayout = false,
    this.sheetBetweenTotalAndAccounts,
  }) : super(key: key);
  final DateTime? start;
  final DateTime? end;
  /// Tighter padding and spacing when embedded above scrollable content (e.g. ledger).
  final bool compact;
  /// Card-less tiles with larger touch targets (e.g. ledger summary bottom sheet).
  final bool sheetLayout;
  /// When [sheetLayout] is true, inserted after the total strip and before per-account rows.
  final Widget? sheetBetweenTotalAndAccounts;
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

    final hPad = sheetLayout ? 0.0 : (compact ? 16.0 : 20.0);
    final vPad = sheetLayout ? 0.0 : (compact ? 8.0 : 12.0);
    final innerPad = sheetLayout ? 0.0 : (compact ? 12.0 : 16.0);
    final Widget streamSection = StreamBuilder<QuerySnapshot>(
      stream: fundSourcesRef.snapshots(),
      builder: (context, fundSourcesSnap) {
        final double loadingH = sheetLayout ? 140 : (compact ? 36 : 40);
        if (!fundSourcesSnap.hasData) {
          return SizedBox(
            height: loadingH,
            child: const Center(
              child: SizedBox(
                height: 36,
                width: 36,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final fundSources = fundSourcesSnap.data!.docs.map((d) {
          final m = Map<String, dynamic>.from(d.data() as Map);
          m['id'] = d.id;
          final v = (m['value'] ?? m['id'] ?? d.id).toString();
          m['value'] = v.isNotEmpty ? v : d.id;
          m['label'] = (m['label'] ?? m['name'] ?? m['value'] ?? d.id).toString();
          m['ledgerType'] = m['ledgerType'] ?? m['type'] ?? 'cash';
          return m;
        }).toList();

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
              return SizedBox(
                height: loadingH,
                child: const Center(
                  child: SizedBox(
                    height: 36,
                    width: 36,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

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
              if (rowBaseCurrency != baseCurrency) continue;
              final delta = direction == 'out' ? -baseAmount : baseAmount;
              balances[fsId] = (balances[fsId] ?? 0.0) + delta;
            }

            final rows = fundSources.map((fs) {
              final String id = (fs['value'] ?? fs['id'] ?? 'cash').toString();
              final String name = (fs['label'] ?? fs['name'] ?? id).toString();
              final String type = (fs['ledgerType'] ?? fs['type'] ?? 'cash').toString();
              final double bal = balances[id] ?? 0.0;
              return _fundSourceRow(
                context,
                name,
                type,
                bal,
                baseCurrency,
                compact: compact,
                sheetLayout: sheetLayout,
              );
            }).toList();

            if (sheetLayout) {
              double sumDisplayed = 0;
              for (final fs in fundSources) {
                final String id = (fs['value'] ?? fs['id'] ?? 'cash').toString();
                sumDisplayed += balances[id] ?? 0;
              }
              final Widget totalStrip = _sheetTotalRow(context, sumDisplayed, baseCurrency);
              final Widget? mid = sheetBetweenTotalAndAccounts;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  totalStrip,
                  if (mid != null) ...[
                    const SizedBox(height: 16),
                    mid,
                    const SizedBox(height: 16),
                  ],
                  ...rows.map((w) => Padding(padding: const EdgeInsets.only(bottom: 10), child: w)),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            );
          },
        );
      },
    );

    if (sheetLayout) {
      return streamSection;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      child: Card(
        elevation: compact ? 2 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(innerPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [streamSection],
          ),
        ),
      ),
    );
  }

  String _typeShortLabel(String type) {
    switch (type) {
      case 'cash':
        return 'Cash'.tr;
      case 'bank':
        return 'Bank'.tr;
      case 'mobile':
        return 'Mobile'.tr;
      default:
        return 'Other'.tr;
    }
  }

  Widget _sheetTotalRow(BuildContext context, double total, String currency) {
    final bool dark = Preferences.getTheme();
    final Color fg = dark ? Colors.white : const Color(0xFF1A1C1E);
    final Color muted = dark ? Colors.white70 : const Color(0xFF5F6368);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            primaryColor.withOpacity(dark ? 0.22 : 0.12),
            primaryLightColor.withOpacity(dark ? 0.12 : 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: primaryColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded, color: primaryColor, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'total'.tr,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: muted,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatCurrency(total, currency),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: fg,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fundSourceRow(
    BuildContext context,
    String name,
    String type,
    double balance,
    String currency, {
    bool compact = false,
    bool sheetLayout = false,
  }) {
    final Color chipColor = type == 'cash'
        ? const Color(0xFF1B8736)
        : (type == 'bank'
            ? const Color(0xFF1565C0)
            : (type == 'mobile' ? const Color(0xFFE65100) : const Color(0xFF6A1B9A)));
    final IconData icon = type == 'cash'
        ? Icons.payments_rounded
        : (type == 'bank'
            ? Icons.account_balance_rounded
            : (type == 'mobile' ? Icons.phone_android_rounded : Icons.account_balance_wallet_rounded));

    if (sheetLayout) {
      final bool dark = Preferences.getTheme();
      final Color tileBg = dark ? const Color(0xFF3A3D44) : Colors.white;
      final Color border = dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06);
      final Color titleC = dark ? Colors.white : const Color(0xFF1A1C1E);
      final Color subC = dark ? Colors.white60 : const Color(0xFF5F6368);

      return Container(
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(dark ? 0.28 : 0.07),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: chipColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: chipColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: titleC,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _typeShortLabel(type),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: subC,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCurrency(balance, currency),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: titleC,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 3 : 6),
      child: Row(
        children: [
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: chipColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(icon, size: compact ? 12 : 14, color: chipColor),
                  SizedBox(width: compact ? 4 : 6),
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: chipColor,
                        fontWeight: FontWeight.w600,
                        fontSize: compact ? 12 : 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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
