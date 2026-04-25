import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import 'package:mauzo/controllers/bought_controller.dart';
import 'package:mauzo/models/expences.dart';
import 'package:mauzo/ui/widgets/funds_summary.dart';

class LedgerHistoryScreen extends StatefulWidget {
  const LedgerHistoryScreen({Key? key}) : super(key: key);

  @override
  State<LedgerHistoryScreen> createState() => _LedgerHistoryScreenState();
}

class _LedgerHistoryScreenState extends State<LedgerHistoryScreen> {
  final BusinessController _businessController = Get.find();

  // Simple client-side filters
  String _selectedSource = 'all'; // all | cash | bank | mobile
  String _selectedType = 'all'; // all | sale | purchase | expense | supplier_payment
  DateTimeRange? _dateRange; // filter by postedAt

  @override
  void initState() {
    super.initState();
    // Do NOT set _dateRange here; when null we will use exact reset_time -> now in the query
    // Ensure we have the latest business data (and reset_time) when this screen opens
    Future.microtask(() async {
      await _businessController.updateBusinessData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BusinessController>(builder: (_) {
      final String? businessId = _businessController.business['id'] ?? _businessController.businessId.value;
      if (businessId == null || businessId.isEmpty) {
        return Scaffold(
          backgroundColor: Preferences.getTheme() ? darkGrayColor : const Color(0xFFF5F6FA),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text('Transaction History'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          body: const Center(child: Text('Business not selected')),
        );
      }

      final baseCurrency = _businessController.business['mainCurrency'] ?? 'TZS';

      // Determine effective range: use explicit picker if set, otherwise fallback to business reset_time -> now
      final Timestamp? resetTimeTs = _businessController.business['reset_time'];
      final DateTime? effectiveStart = _dateRange?.start ?? resetTimeTs?.toDate();
      final DateTime effectiveEnd = _dateRange?.end ?? DateTime.now();

      // Build query, applying postedAt range if a start is available
      Query<Map<String, dynamic>> ledgerQuery = FirebaseFirestore.instance
          .collection('ledger')
          .doc(businessId)
          .collection('entries')
          .orderBy('postedAt', descending: true);
      if (effectiveStart != null) {
        final Timestamp startTs = _dateRange != null
            ? Timestamp.fromDate(DateUtils.dateOnly(effectiveStart))
            : Timestamp.fromDate(effectiveStart); // use exact reset_time when no explicit range
        final Timestamp endTs = _dateRange != null
            ? Timestamp.fromDate(DateUtils.dateOnly(effectiveEnd).add(const Duration(days: 1)))
            : Timestamp.fromDate(effectiveEnd);
        ledgerQuery = ledgerQuery
            .where('postedAt', isGreaterThanOrEqualTo: startTs)
            .where('postedAt', isLessThan: endTs);
      }
      ledgerQuery = ledgerQuery.limit(200);

      return Scaffold(
        backgroundColor: Preferences.getTheme() ? darkGrayColor : const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Transaction History'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: 'Summary'.tr,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () => _showFundsSummarySheet(context),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ledgerQuery.snapshots(),
          builder: (context, snap) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Preferences.getTheme() ? mediumGrayColor : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list_rounded, color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Filters'.tr,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Preferences.getTheme() ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Preferences.getTheme() ? darkGrayColor : const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Obx(() {
                          final sources =
                              _businessController.effectiveFundSources;
                          final fundItems = sources
                              .map((e) {
                                final v = e['value']?.toString() ?? '';
                                if (v.isEmpty) return null;
                                return DropdownMenuItem<String>(
                                  value: v,
                                  child: Text(
                                      e['label']?.toString() ?? v),
                                );
                              })
                              .whereType<DropdownMenuItem<String>>()
                              .toList();
                          final validValues = {
                            'all',
                            ...sources
                                .map((e) => e['value']?.toString() ?? '')
                                .where((v) => v.isNotEmpty),
                          };
                          final safeSource = validValues.contains(_selectedSource)
                              ? _selectedSource
                              : 'all';
                          if (safeSource != _selectedSource) {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() => _selectedSource = safeSource);
                              }
                            });
                          }
                          return DropdownButtonFormField<String>(
                            value: safeSource,
                            decoration: InputDecoration(
                              labelText: 'Account',
                              prefixIcon: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.transparent,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            dropdownColor: Preferences.getTheme()
                                ? mediumGrayColor
                                : Colors.white,
                            items: [
                              const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Accounts')),
                              ...fundItems,
                            ],
                            onChanged: (v) => setState(
                                () => _selectedSource = v ?? 'all'),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Preferences.getTheme() ? darkGrayColor : const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _selectedType,
                          decoration: InputDecoration(
                            labelText: 'Type',
                            prefixIcon: const Icon(Icons.category_outlined, size: 20),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          dropdownColor: Preferences.getTheme() ? mediumGrayColor : Colors.white,
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Types')),
                            DropdownMenuItem(value: 'sale', child: Text('Sales')),
                            DropdownMenuItem(value: 'purchase', child: Text('Purchases')),
                            DropdownMenuItem(value: 'expense', child: Text('Expenses')),
                            DropdownMenuItem(value: 'supplier_payment', child: Text('Supplier Payments')),
                          ],
                          onChanged: (v) => setState(() => _selectedType = v ?? 'all'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(now.year - 5),
                      lastDate: DateTime(now.year + 5),
                      initialDateRange: _dateRange,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: primaryColor,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setState(() => _dateRange = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Preferences.getTheme() ? darkGrayColor : const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.date_range_rounded, color: primaryColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _dateRange != null
                                ? '${_fmtDate(_dateRange!.start)} - ${_fmtDate(_dateRange!.end)}'
                                : (resetTimeTs != null
                                    ? '${_fmtDate(resetTimeTs.toDate())} - ${_fmtDate(DateTime.now())}'
                                    : 'Select Date Range'),
                            style: TextStyle(
                              color: (_dateRange != null || resetTimeTs != null)
                                  ? (Preferences.getTheme() ? Colors.white : Colors.black87)
                                  : Colors.grey,
                            ),
                          ),
                        ),
                        if (_dateRange != null)
                          IconButton(
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _dateRange = null),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
                  ),
                ),
                ..._buildLedgerTailSlivers(context, snap, baseCurrency, resetTimeTs),
                SliverToBoxAdapter(
                  child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ),
              ],
            );
          },
        ),
      );
    });
  }

  void _showFundsSummarySheet(BuildContext context) {
    final media = MediaQuery.of(context);
    final double sheetHeight = media.size.height * 0.64;
    final bool dark = Preferences.getTheme();
    final Color sheetBase = dark ? const Color(0xFF2C2E33) : const Color(0xFFF7F8FC);
    final Color onSurface = dark ? Colors.white : const Color(0xFF1A1C1E);
    final Color onMuted = dark ? Colors.white70 : const Color(0xFF5F6368);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(top: media.padding.top + 12),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: Container(
              height: sheetHeight,
              decoration: BoxDecoration(
                color: sheetBase,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 32,
                    offset: const Offset(0, -12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: dark ? Colors.white24 : Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      physics: const BouncingScrollPhysics(),
                      child: FundsSummary(
                        sheetLayout: true,
                        sheetBetweenTotalAndAccounts: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(dark ? 0.28 : 0.14),
                                primaryUltraLightColor.withOpacity(dark ? 0.12 : 0.55),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: primaryColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(dark ? 0.12 : 0.85),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withOpacity(0.15),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.insights_rounded, color: primaryColor, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Summary'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 22,
                                        letterSpacing: -0.5,
                                        color: onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Summary balance hint'.tr,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        fontWeight: FontWeight.w500,
                                        color: onMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  style: IconButton.styleFrom(
                                    foregroundColor: onSurface,
                                    backgroundColor: dark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.7),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.close_rounded, size: 22),
                                  onPressed: () => Navigator.pop(ctx),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sliver list / empty / loading below filters.
  List<Widget> _buildLedgerTailSlivers(
    BuildContext context,
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snap,
    String baseCurrency,
    Timestamp? resetTimeTs,
  ) {
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (!snap.hasData) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('No data')),
        ),
      ];
    }

    List<Map<String, dynamic>> rows = snap.data!.docs
        .map((d) {
          final data = d.data();
          final m = Map<String, dynamic>.from(data);
          m['__id'] = d.id;
          return m;
        })
        .toList();

    rows = rows.where((m) {
      final String fs = (m['fundSourceId'] ?? '').toString();
      final String type = (m['transactionType'] ?? '').toString();
      final Timestamp ts = m['postedAt'] is Timestamp
          ? m['postedAt'] as Timestamp
          : Timestamp.fromDate(DateTime.tryParse(m['postedAt'].toString()) ?? DateTime.now());

      bool ok = true;
      if (_selectedSource != 'all') ok &= fs == _selectedSource;
      if (_selectedType != 'all') ok &= type == _selectedType;
      final DateTime? clientStart = _dateRange?.start ?? resetTimeTs?.toDate();
      final DateTime? clientEnd = _dateRange?.end;
      if (clientStart != null) {
        final dt = ts.toDate();
        final DateTime startBound = _dateRange != null
            ? DateUtils.dateOnly(clientStart).subtract(const Duration(seconds: 1))
            : clientStart;
        final DateTime endBound = _dateRange != null
            ? DateUtils.dateOnly(clientEnd ?? DateTime.now()).add(const Duration(days: 1))
            : DateTime.now();
        ok &= dt.isAfter(startBound) && dt.isBefore(endBound);
      }
      return ok;
    }).toList();

    if (rows.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions found',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your filters',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ];
    }

    double totalIn = 0;
    double totalOut = 0;
    for (final row in rows) {
      final dir = (row['direction'] ?? 'in').toString();
      final amt = (row['baseAmount'] is int)
          ? (row['baseAmount'] as int).toDouble()
          : ((row['baseAmount'] ?? 0.0) as num).toDouble();
      if (dir == 'in') {
        totalIn += amt;
      } else {
        totalOut += amt;
      }
    }

    return [
      SliverToBoxAdapter(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Preferences.getTheme() ? mediumGrayColor : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Money In',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(totalIn, baseCurrency),
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Money Out',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(totalOut, baseCurrency),
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey.shade300,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Net',
                      style: TextStyle(
                        color: (totalIn - totalOut) >= 0 ? Colors.blue.shade700 : Colors.orange.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(totalIn - totalOut, baseCurrency),
                      style: TextStyle(
                        color: (totalIn - totalOut) >= 0 ? Colors.blue.shade700 : Colors.orange.shade700,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final m = rows[i];
                          final String direction = (m['direction'] ?? 'in').toString();
                          final String fs = (m['fundSourceId'] ?? '').toString();
                          final String paymentDisplayLabel = (() {
                            final pl = m['paymentMethodLabel']?.toString();
                            if (pl != null && pl.isNotEmpty) return pl;
                            final pv = m['paymentMethodValue']?.toString();
                            if (pv != null && pv.isNotEmpty) {
                              return _businessController
                                  .paymentMethodLabelForValue(pv);
                            }
                            return _titleCase(fs);
                          })();
                          final String type = (m['transactionType'] ?? '').toString();
                          final String counterpartyName = (m['counterpartyName'] ?? '').toString();
                          final double baseAmount = (m['baseAmount'] is int)
                              ? (m['baseAmount'] as int).toDouble()
                              : ((m['baseAmount'] ?? 0.0) as num).toDouble();
                          final String baseCurr = (m['baseCurrency'] ?? baseCurrency).toString();
                          final Timestamp ts = m['postedAt'] is Timestamp
                              ? m['postedAt'] as Timestamp
                              : Timestamp.fromDate(DateTime.tryParse(m['postedAt'].toString()) ?? DateTime.now());

                          final isIn = direction == 'in';
                          final color = isIn ? Colors.green.shade600 : Colors.red.shade600;
                          
                          // Get icon and label for transaction type
                          IconData typeIcon;
                          String typeLabel;
                          Color iconBgColor;
                          switch (type) {
                            case 'sale':
                              typeIcon = Icons.shopping_cart_rounded;
                              typeLabel = 'Sale';
                              iconBgColor = Colors.green;
                              break;
                            case 'purchase':
                              typeIcon = Icons.shopping_bag_rounded;
                              typeLabel = 'Purchase';
                              iconBgColor = Colors.orange;
                              break;
                            case 'expense':
                              typeIcon = Icons.receipt_rounded;
                              typeLabel = 'Expense';
                              iconBgColor = Colors.red;
                              break;
                            case 'supplier_payment':
                              typeIcon = Icons.payments_rounded;
                              typeLabel = 'Supplier Payment';
                              iconBgColor = Colors.purple;
                              break;
                            default:
                              typeIcon = Icons.swap_horiz_rounded;
                              typeLabel = _titleCase(type);
                              iconBgColor = Colors.blue;
                          }

                          // Get fund source icon
                          String fundIcon;
                          switch (fs) {
                            case 'cash':
                              fundIcon = '💵';
                              break;
                            case 'bank':
                              fundIcon = '🏦';
                              break;
                            case 'mobile':
                              fundIcon = '📱';
                              break;
                            default:
                              fundIcon = '💰';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Preferences.getTheme() ? mediumGrayColor : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _openTransaction(m),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Icon
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: iconBgColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          typeIcon,
                                          color: iconBgColor,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  typeLabel,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 15,
                                                    color: Preferences.getTheme() ? Colors.white : Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  fundIcon,
                                                  style: const TextStyle(fontSize: 14),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  paymentDisplayLabel,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  size: 14,
                                                  color: Colors.grey.shade500,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  DateFormat('MMM d, y • h:mm a').format(ts.toDate()),
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (counterpartyName.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                counterpartyName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade500,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      // Amount
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Row(
                                            children: [
                                              if (isIn) 
                                                Icon(
                                                  Icons.add_circle_outline,
                                                  size: 16,
                                                  color: color,
                                                )
                                              else
                                                Icon(
                                                  Icons.remove_circle_outline,
                                                  size: 16,
                                                  color: color,
                                                ),
                                              const SizedBox(width: 4),
                                              Text(
                                                formatCurrency(baseAmount, baseCurr),
                                                style: TextStyle(
                                                  color: color,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
            },
            childCount: rows.length,
          ),
        ),
      ),
    ];
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Future<void> _openTransaction(Map<String, dynamic> m) async {
    final String type = (m['transactionType'] ?? '').toString();
    final String refId = (m['referenceId'] ?? '').toString();
    if (type.isEmpty) return;

    switch (type) {
      case 'sale':
        try {
          Get.find<SaleController>().filterSalesById(refId);
        } catch (_) {}
        if (mounted) Navigator.pushNamed(context, '/sales');
        break;
      case 'purchase':
        try {
          Get.find<BoughtController>().filterSalesById(refId);
        } catch (_) {}
        if (mounted) Navigator.pushNamed(context, '/bought');
        break;
      case 'expense':
        // Go to expense list and filter by particular expense id
        if (mounted) {
          Navigator.pushNamed(context, '/expenses', arguments: {
            'filterExpenseId': refId,
          });
        }
        break;
      case 'supplier_payment':
        final role = (Get.find<ProfileController>().user['role'] ?? '').toString();
        if (!_businessController.isPurchasesAllowedForRole(role)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Open supplier debts from the owner account, or enable Allow Purchases for staff.',
                ),
              ),
            );
          }
          break;
        }
        if (mounted) {
          Navigator.pushNamed(context, '/supplier-debt', arguments: {
            'filterDebtId': refId,
          });
        }
        break;
      default:
        // Unknown type: no-op
        break;
    }
  }

  Future<void> _openExpenseById(String expenseId) async {
    try {
      final String? businessId = _businessController.business['id'] ?? _businessController.businessId.value;
      if (businessId == null || businessId.isEmpty) return;
      final doc = await FirebaseFirestore.instance
          .collection('expenses')
          .doc(businessId)
          .collection('userExpenses')
          .doc(expenseId)
          .get();
      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense not found')),
          );
        }
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final Expense exp = Expense(
        id: doc.id,
        title: (data['title'] ?? '').toString(),
        amount: (data['amount'] is int)
            ? (data['amount'] as int).toDouble()
            : ((data['amount'] ?? 0.0) as num).toDouble(),
        date: data['date'] is Timestamp ? data['date'] as Timestamp : Timestamp.now(),
        category: (data['category'] ?? '').toString(),
        addedBy: (data['addedBy'] ?? '').toString(),
        addedByName: (data['addedByName'] ?? '').toString(),
        fundSource: (data['fundSource'] ?? 'cash').toString(),
        fundSourceNote: (data['fundSourceNote'] ?? '').toString(),
      );
      if (mounted) Navigator.pushNamed(context, '/edit-expense', arguments: exp);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open expense: $e')),
        );
      }
    }
  }
}
