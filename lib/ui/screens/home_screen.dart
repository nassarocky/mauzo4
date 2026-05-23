import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/business_list_controller.dart';
import 'package:mauzo/controllers/bought_controller.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/employee_controller.dart';
import 'package:mauzo/controllers/expence_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/sale_controller.dart';
import 'package:mauzo/controllers/supplier_controller.dart';
import 'package:mauzo/controllers/supplier_debt_controller.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/debt_history_controller.dart';
import 'package:mauzo/controllers/invoice_controller.dart';
import 'package:mauzo/controllers/transaction_controller.dart';
import 'package:mauzo/controllers/closed_books_controller.dart';
import 'package:mauzo/controllers/inventory_loss_controller.dart';
import 'package:mauzo/models/business_model.dart';
import 'package:mauzo/ui/widgets/tiles/drawer_tile.dart';
import 'package:mauzo/ui/widgets/drawer/expandable_drawer_section.dart';
import 'package:mauzo/ui/widgets/drawer/shop_location_drawer_banner.dart';
import 'package:mauzo/ui/widgets/dialogs/add_business_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/shop_location_dialog.dart';
import 'package:mauzo/utils/business_shop_location.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/product_transfer_controller.dart';
import '../../controllers/store_controller.dart';
import '../../utils/preferences.dart';
import '../widgets/dialogs/payment_dialog.dart';
import '../widgets/screens_card.dart';
import '../widgets/tiles/info_tile.dart';
import '../widgets/subscription_expiry_banner.dart';
import 'package:mauzo/services/fund_source_service.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProfileController _profileController =Get.put(ProfileController());
  final BusinessController _businessController = Get.put(BusinessController());
  String accountName = 'Customer service / Huduma kwa wateja';
  String accountEmail = '+255698720225/+255781282076';
  bool isAccountActive = true;
  bool isInitialized = false;
  bool isBuyingStock = Preferences.getStockDisplayPreference();
  String _appVersion = '';
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  User? user = FirebaseAuth.instance.currentUser;


  @override
  void initState() {
    super.initState();
    if (!isInitialized) {
      _initialize();
    }
  }
  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }


  void _initialize() async {

    await _profileController.updateUserEmail(Preferences.getEmail());
    await _businessController.updateBusinessId(Preferences.getBusiness());
    final info = await PackageInfo.fromPlatform();
    _appVersion = 'v${info.version}+${info.buildNumber}';

    // Ensure default fund sources exist (idempotent); checkout "payment methods" use this list.
    try {
      final bid = _businessController.businessId.value;
      if (bid.isNotEmpty) {
        await FundSourceService().seedDefaults(bid);
      }
    } catch (e) {
      print('Fund source seeding failed: $e');
    }

    // Initialize controllers
    Get.put(SupplierController());

    // Additional logic after ensuring all controllers are initialized
    if (_businessController.businessId.value.isNotEmpty) {
      await checkAccountStatus();
    }
    // Mark initialization as complete
    setState(() {
      isInitialized = true;
    });
    // Start necessary operations
    startTimer();
    _listenToUserChanges();
  }


  void _listenToUserChanges() {
    // Ensure businessId is not empty before setting up the listener
    if (_businessController.businessId.value.isNotEmpty) {
      _userSubscription = FirebaseFirestore.instance
          .collection('businesses')
          .doc(_businessController.businessId.value)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists) {
          // Get the current and previous values of 'reset_time'
          var currentResetTime = snapshot.data()?['reset_time'] as Timestamp?;
          var previousResetTime = _businessController.business['reset_time'] as Timestamp?;

          // Check if 'reset_time' has changed
          if (currentResetTime != previousResetTime) {
            // Update only if 'reset_time' has changed
            await _businessController.updateBusinessData();
          }

          // Check for 'subscriptionStatus' changes
          var currentSubscriptionStatus = snapshot.data()?['subscriptionStatus'];
          var previousSubscriptionStatus = _businessController.business['subscriptionStatus'];

          if (currentSubscriptionStatus != previousSubscriptionStatus) {
            await _businessController.updateBusinessData();
            await checkAccountStatus();
          }
        }
      });
    } else {
      print("Business ID is empty. Firestore listener not initialized.");
    }
  }




  int time = 0;
  void startTimer() {
    Timer.periodic(const Duration(seconds: 25), (timer) {
      if (mounted) {
        setState(() {
          time = time + 25;
        });
      }
    });
  }




  /// Only these statuses mean "must pay / renew" — show the blocking modal.
  /// Empty, unknown, or other inactive values are treated as non-payment issues (do not block).
  static bool _statusRequiresPaymentBlock(String statusStr) {
    final s = statusStr.trim();
    return s == 'subscription_ended' || s == 'trial_expired';
  }

  Future<void> checkAccountStatus() async {
    final active = await _businessController.isAccountActive();
    final rawStatus = _businessController.business['subscriptionStatus'];
    final statusStr = rawStatus?.toString().trim() ?? '';

    if (active) {
      if (mounted) {
        setState(() => isAccountActive = true);
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }
      return;
    }

    // Inactive: block only when backend explicitly says payment is required.
    if (_statusRequiresPaymentBlock(statusStr)) {
      if (mounted) setState(() => isAccountActive = false);
      showAccountStatusDialog(statusStr);
    } else {
      // Sync/data/unknown issue — do not lock the app behind payment UI.
      if (mounted) {
        setState(() => isAccountActive = true);
        Navigator.of(context, rootNavigator: true)
            .popUntil((route) => route.isFirst);
      }
    }
  }

  bool _isBusinessOwner() {
    return (_profileController.user['role'] ?? '').toString() == 'owner';
  }

  /// Message for subscription / access dialog (only for payment-required statuses).
  String _accountStatusMessage(String? status, {required bool isOwner}) {
    final s = status?.toString().trim() ?? '';
    if (!isOwner) {
      return 'subscription_employee_access_body'.tr;
    }
    if (s == 'subscription_ended') {
      return 'Your subscription has ended.'.tr;
    }
    if (s == 'trial_expired') {
      return 'Your trial has expired.'.tr;
    }
    return 'Your subscription has ended.'.tr;
  }

  void showAccountStatusDialog(String? status) {
    final isOwner = _isBusinessOwner();
    final message = _accountStatusMessage(status, isOwner: isOwner);
    final showPayment = isOwner;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext dialogContext) {
          return WillPopScope(
            onWillPop: () async => false,
            child: AlertDialog(
              title: Text(
                showPayment
                    ? 'subscription_dialog_payment_title'.tr
                    : 'subscription_dialog_access_title'.tr,
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!showPayment) ...[
                      Icon(
                        Icons.info_outline,
                        size: 40,
                        color: Theme.of(dialogContext).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(message),
                    if (showPayment) ...[
                      const SizedBox(height: 16),
                      const PaymentDialogContent(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    });
  }

  double getFontSize(BuildContext context, double baseFontSize) {
    // Adjust font size based on screen width
    double screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > 600 ? baseFontSize * 1.5 : baseFontSize; // Larger for tablets
  }

  IconData _ledgerTypeIconForAnalytics(String ledgerType) {
    switch (ledgerType) {
      case 'bank':
        return Icons.account_balance;
      case 'mobile':
        return Icons.phone_android;
      default:
        return Icons.payments;
    }
  }

  Color _ledgerTypeColorForAnalytics(String ledgerType) {
    switch (ledgerType) {
      case 'bank':
        return Colors.blue.shade600;
      case 'mobile':
        return Colors.orange.shade600;
      default:
        return Colors.green.shade600;
    }
  }

  /// Amount shown for one fund source key (legacy unallocated sales roll into [cash] when [treatMissingAsCash]).
  double _displayedAmountForAnalyticsSource(
    String key,
    Map<String, double> itemizedTotals,
    double legacyAggregated,
    bool treatMissingAsCash,
  ) {
    double v = itemizedTotals[key] ?? 0.0;
    if (key == 'cash' && treatMissingAsCash) {
      v += legacyAggregated;
    }
    return v;
  }

  /// Keys with a positive displayed amount, ordered catalog-first then remaining alphabetically.
  List<String> _paymentMethodKeysForAnalyticsBar(
    Map<String, double> itemizedTotals,
    double legacyAggregated,
    bool treatMissingAsCash,
  ) {
    final candidates = <String>{...itemizedTotals.keys};
    candidates.add('cash');
    candidates.removeWhere((k) =>
        _displayedAmountForAnalyticsSource(
              k,
              itemizedTotals,
              legacyAggregated,
              treatMissingAsCash,
            ) <=
            0);
    final seen = <String>{};
    final ordered = <String>[];
    for (final e in _businessController.effectiveFundSources) {
      final v = (e['value'] ?? e['id'] ?? '').toString();
      if (v.isNotEmpty && candidates.contains(v) && seen.add(v)) {
        ordered.add(v);
      }
    }
    final rest = candidates.where((k) => !seen.contains(k)).toList()..sort();
    ordered.addAll(rest);
    return ordered;
  }

  /// Resolves a human-readable label when the catalog cache missed (e.g. stale list) but Firestore has the row.
  Future<String?> _fetchFundSourceLabelFromFirestore(String businessId, String fundKey) async {
    final id = fundKey.trim();
    if (businessId.isEmpty || id.isEmpty) return null;
    try {
      final doc = await firestore
          .collection('fundSources')
          .doc(businessId)
          .collection('userFundSources')
          .doc(id)
          .get();
      if (!doc.exists) return null;
      final d = doc.data();
      if (d == null) return null;
      final t = (d['label'] ?? d['name'] ?? d['value'])?.toString().trim();
      if (t == null || t.isEmpty) return null;
      return t;
    } catch (_) {
      return null;
    }
  }

  Future<void> _showTotalSalesDialog(BuildContext context, SaleController _saleController,DebtHistoryController _debtHistoryController,BoughtController _boughtController, ExpenseController expenseController, Timestamp resetTime) async {
    // double totalSales = _saleController.getTotalSalesFromTimestamp(resetTime);
    double totalPayments = _saleController.getTotalPaymentFromTimestamp(resetTime,Timestamp.now());
    double purchases = _boughtController.getTotalPurchasePaidFromTimestamp(resetTime,Timestamp.now());
    //  double debtCollected = _debtHistoryController.getTotalDebtPaymentsBackTimestamp(resetTime);
    double totalExpenses = expenseController.getTotalExpensesFromTimestamp(resetTime,Timestamp.now());
    final String mainCurrency = _businessController.business['mainCurrency'];
    
    final Timestamp _endTs = Timestamp.now();
    double totalExpensesExclusive = 0.0;
    for (final exp in expenseController.expenses) {
      final Timestamp expTs = exp.date;
      if (expTs.compareTo(resetTime) > 0 && expTs.compareTo(_endTs) < 0) {
        final dynamic rawAmt = exp.amount;
        final double amt = rawAmt is int
            ? rawAmt.toDouble()
            : (rawAmt is num ? rawAmt.toDouble() : 0.0);
        totalExpensesExclusive += amt;
      }
    }
    double purchasesExclusive = 0.0;
    for (final purchase in _boughtController.sales) {
      final dynamic rawDate = purchase.date;
      Timestamp? pTs;
      if (rawDate is Timestamp) {
        pTs = rawDate;
      } else if (rawDate is DateTime) {
        pTs = Timestamp.fromDate(rawDate);
      }
      if (pTs != null && pTs.compareTo(resetTime) > 0 && pTs.compareTo(_endTs) < 0) {
        if (purchase.payments.isNotEmpty) {
          for (final p in purchase.payments) {
            final dynamic rawAmount = p['amount'];
            final double amt = rawAmount is int
                ? rawAmount.toDouble()
                : (rawAmount is num ? rawAmount.toDouble() : 0.0);
            final String currency = (p['currency'] ?? mainCurrency).toString();
            final double amtMain = currency == mainCurrency
                ? amt
                : amt * Preferences.getExchangeRateResult();
            purchasesExclusive += amtMain;
          }
        } else {
          purchasesExclusive += purchase.payment;
        }
      }
    }
    // Compute payment totals per fund source / payment method (supports custom catalog rows).
    final Map<String, double> itemizedMethodTotals = {};
    double aggregatedTotal = 0.0; // Old sales without payment breakdown
    double debtCollectedExclusive = 0.0;
    // mainCurrency already defined above

    for (final sale in _saleController.sales) {
      final dynamic rawDate = sale.date;
      Timestamp? saleTs;
      if (rawDate is Timestamp) {
        saleTs = rawDate;
      } else if (rawDate is DateTime) {
        saleTs = Timestamp.fromDate(rawDate);
      }

      if (saleTs != null) {
        if (saleTs.compareTo(resetTime) > 0 && saleTs.compareTo(Timestamp.now()) < 0) {
          if (sale.payments.isNotEmpty) {
            for (final p in sale.payments) {
              final dynamic rawAmount = p['amount'];
              final double amt = rawAmount is int
                  ? rawAmount.toDouble()
                  : (rawAmount is num ? rawAmount.toDouble() : 0.0);
              final String currency = (p['currency'] ?? mainCurrency).toString();
              // Treat missing, null, or empty method as 'cash' for backward compatibility
              final String method = (p['method'] ?? 'cash').toString().trim();
              final String methodNormalized = method.isEmpty ? 'cash' : method;
              final double amtMain = currency == mainCurrency
                  ? amt
                  : amt * Preferences.getExchangeRateResult();

              itemizedMethodTotals[methodNormalized] =
                  (itemizedMethodTotals[methodNormalized] ?? 0.0) + amtMain;

              if (sale.saleType == 'debt_repayment') {
                debtCollectedExclusive += amtMain;
              }
            }
          } else {
            // Old sales without payment breakdown (backward compatibility)
            if (sale.payment > 0) {
              aggregatedTotal += sale.payment;
            }
            if (sale.saleType == 'debt_repayment') {
              debtCollectedExclusive += sale.payment;
            }
          }
        }
      }
    }

    final String bid = _businessController.businessId.value;
    final Map<String, String> labelOverrides = <String, String>{};
    if (bid.isNotEmpty) {
      try {
        final list = await FundSourceService().loadFundSources(bid);
        _businessController.reloadFundSources(list);
      } catch (_) {}
      for (final k in itemizedMethodTotals.keys) {
        final resolved = _businessController.paymentMethodLabelForValue(k);
        if (resolved != k) continue;
        final fetched = await _fetchFundSourceLabelFromFirestore(bid, k);
        if (fetched != null && fetched.isNotEmpty) {
          labelOverrides[k] = fetched;
        }
      }
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(builder: (context, setState) {
          bool treatMissingAsCash = true; // toggle to include/exclude old sales without breakdown
          final double itemizedSum = itemizedMethodTotals.values.fold<double>(
            0.0,
            (a, b) => a + b,
          );
          final double totalInflowsAll =
              itemizedSum + (treatMissingAsCash ? aggregatedTotal : 0.0);
          final double netTotalLocal =
              totalInflowsAll - totalExpensesExclusive - purchasesExclusive;
          final paymentBarKeys = _paymentMethodKeysForAnalyticsBar(
            itemizedMethodTotals,
            aggregatedTotal,
            treatMissingAsCash,
          );

          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade50,
                    Colors.white,
                    Colors.green.shade50,
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade800],
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.analytics, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Sales and Expenses Analysis'.tr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Switch: Treat missing breakdown as cash
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Treat missing breakdown as cash',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: treatMissingAsCash,
                                  onChanged: (v) => setState(() => treatMissingAsCash = v),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Total Sales Card
                          _buildAnalyticsCard(
                            icon: Icons.trending_up,
                            iconColor: Colors.green,
                            title: 'TOTAL PAYMENTS (Cash In + Debt Collected)'.tr,
                            amount: formatCurrency(totalInflowsAll, _businessController.business['mainCurrency']),
                            gradient: [Colors.green.shade50, Colors.green.shade100],
                          ),

                          const SizedBox(height: 16),

                          // Payment Methods Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.payment, color: Colors.blue.shade600, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Payment Methods Breakdown'.tr,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                for (var i = 0; i < paymentBarKeys.length; i++) ...[
                                  if (i > 0) const SizedBox(height: 8),
                                  _buildPaymentMethodRow(
                                    icon: _ledgerTypeIconForAnalytics(
                                      _businessController.getLedgerTypeForMethod(paymentBarKeys[i]),
                                    ),
                                    iconColor: _ledgerTypeColorForAnalytics(
                                      _businessController.getLedgerTypeForMethod(paymentBarKeys[i]),
                                    ),
                                    method: labelOverrides[paymentBarKeys[i]] ??
                                        _businessController.paymentMethodLabelForValue(paymentBarKeys[i]),
                                    amount: formatCurrency(
                                      _displayedAmountForAnalyticsSource(
                                        paymentBarKeys[i],
                                        itemizedMethodTotals,
                                        aggregatedTotal,
                                        treatMissingAsCash,
                                      ),
                                      _businessController.business['mainCurrency'],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                _buildPaymentMethodRow(
                                  icon: Icons.assignment_turned_in,
                                  iconColor: Colors.teal.shade600,
                                  method: 'Debt Collected',
                                  amount: formatCurrency(debtCollectedExclusive, _businessController.business['mainCurrency']),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Other Metrics
                          Obx(() {
                            final double debtOutstanding = _debtHistoryController.getTotalDebt();
                            return _buildAnalyticsCard(
                              icon: Icons.account_balance_wallet,
                              iconColor: Colors.orange,
                              title: 'DEBT'.tr,
                              amount: formatCurrency(debtOutstanding, _businessController.business['mainCurrency']),
                              gradient: [Colors.orange.shade50, Colors.orange.shade100],
                            );
                          }),

                          const SizedBox(height: 12),

                          _buildAnalyticsCard(
                            icon: Icons.shopping_cart,
                            iconColor: Colors.purple,
                            title: 'PURCHASES PAID'.tr,
                            amount: formatCurrency(purchasesExclusive, _businessController.business['mainCurrency']),
                            gradient: [Colors.purple.shade50, Colors.purple.shade100],
                          ),

                          const SizedBox(height: 12),

                          _buildAnalyticsCard(
                            icon: Icons.receipt_long,
                            iconColor: Colors.red,
                            title: 'EXPENSES'.tr,
                            amount: formatCurrency(totalExpensesExclusive, _businessController.business['mainCurrency']),
                            gradient: [Colors.red.shade50, Colors.red.shade100],
                          ),

                          const SizedBox(height: 16),

                          // Net Total - Special styling
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: netTotalLocal >= 0
                                    ? [Colors.green.shade600, Colors.green.shade800]
                                    : [Colors.red.shade600, Colors.red.shade800],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (netTotalLocal >= 0 ? Colors.green : Colors.red).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    netTotalLocal >= 0 ? Icons.account_balance : Icons.warning,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Available balance'.tr,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatCurrency(netTotalLocal, _businessController.business['mainCurrency']),
                                        style: const TextStyle(
                                          color: Colors.white,
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Widget _buildAnalyticsCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String amount,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  amount,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodRow({
    required IconData icon,
    required Color iconColor,
    required String method,
    required String amount,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            method,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Text(
          amount,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    //  loadDeveloperInfo();
    final bool canEditHome = _profileController.hasPermission('edit_home');
    final bool canEditBusiness = _profileController.hasPermission('edit_business');

    return GetBuilder<BusinessController>(
      builder: (controller) {

        if (controller.business.isEmpty) {
          return Scaffold(
            body: Center(
              child: time < 25
                  ? const CircularProgressIndicator()
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Something went wrong'.tr),
                  TextButton(
                    child: Text(
                      'Login'.tr,
                      style: h5(
                        Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    onPressed: () {
                      Get.toNamed('/login');
                    },
                  ),
                ],
              ),
            ),
          );
        }




        final BusinessListController businessListController = Get.put(BusinessListController());
        final InvoiceController invoiceController = Get.put(InvoiceController());
        final ProductController productController = Get.put(ProductController());
        final ExpenseController expenceController = Get.put(ExpenseController());
        final StoreController storeController = Get.put(StoreController());
        final ClientController clientController = Get.put(ClientController());

        final SaleController _saleController = Get.put(SaleController());
        final ProductTransferController _transferController = Get.put(ProductTransferController());
        final CartController cartController = Get.put(CartController());
        final EmployeeController _employeeController = Get.put(EmployeeController());
        final DebtHistoryController _debtHistoryController = Get.put(DebtHistoryController());
        final SupplierDebtController _supplierDebtController = Get.put(SupplierDebtController());
        final ClosedBooksController closedBooksController = Get.put(ClosedBooksController());
        final BoughtController _boughtController = Get.put(BoughtController());
        final TransactionController transactionController = Get.put(TransactionController());
        // Lazy load - only create when screen is opened
        Get.lazyPut(() => InventoryLossController());

        void restartAllControllers() {
          // Delete all controllers
          Get.delete<ProductTransferController>(force: true);
          Get.delete<StoreController>(force: true);
          Get.delete<BusinessListController>(force: true);
          Get.delete<BoughtController>(force: true);
          Get.delete<DebtHistoryController>(force: true);
          Get.delete<BoughtController>(force: true);
          Get.delete<InvoiceController>(force: true);
          Get.delete<ProductController>(force: true);
          Get.delete<TransactionController>(force: true);
          Get.delete<ClientController>(force: true);
          Get.delete<SaleController>(force: true);
          Get.delete<ExpenseController>(force: true);
          Get.delete<CartController>(force: true);
          Get.delete<EmployeeController>(force: true);
          Get.delete<SupplierController>(force: true);
          Get.delete<SupplierDebtController>(force: true);
          Get.delete<StoreController>(force: true);
          Get.delete<ClosedBooksController>(force: true);
          Get.delete<InventoryLossController>(force: true);
          // Recreate controllers - ORDER MATTERS: Dependencies must be initialized first
          Get.put<ProductTransferController>(ProductTransferController());
          Get.put<StoreController>(StoreController());
          Get.put<BusinessListController>(BusinessListController());
          Get.put<InvoiceController>(InvoiceController());
          Get.put<DebtHistoryController>(DebtHistoryController());
          Get.put<SupplierDebtController>(SupplierDebtController());
          Get.put<ProductController>(ProductController());
          Get.put<ExpenseController>(ExpenseController()); // Must be before BoughtController
          Get.put<ClientController>(ClientController());
          // Initialize TransactionController after BusinessController is ready
          try {
            if (_businessController.businessId.value.isNotEmpty) {
              Get.put<TransactionController>(TransactionController());
            }
          } catch (e) {
            print('TransactionController restart failed: $e');
          }
          Get.put<SupplierController>(SupplierController());
          Get.put<SaleController>(SaleController());
          Get.put<CartController>(CartController());
          Get.put<EmployeeController>(EmployeeController());
          Get.put<BoughtController>(BoughtController()); // Depends on ExpenseController
          Get.put<ClosedBooksController>(ClosedBooksController());
          // Lazy load - only create when screen is opened
          Get.lazyPut(() => InventoryLossController());
        }

        _businessController.business['categories'].sort();
        void showAddBusinessDialog(BuildContext context) {
          showAddBusinessEditorDialog(
            context,
            onCreate: ({
              required String name,
              required String shopCountry,
              required String shopCity,
              required String shopStreet,
            }) async {
              await businessListController.addNewBusiness(
                name,
                shopCountry: shopCountry,
                shopCity: shopCity,
                shopStreet: shopStreet,
              );
              await _profileController.updateUserData();
              restartAllControllers();
            },
          );
        }

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            title: Obx(() {
              return Row(
                mainAxisSize: MainAxisSize.min, // Keeps the row as small as possible
                children: [
                  // Display the selected business name
                  GestureDetector(
                    onTap: () {
                      // Trigger dropdown manually when tapping on the business name
                      // if needed in future, currently it only shows the name
                    },
                    child: Text(
                      _businessController.business['name'] ?? 'Select Business',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),

                  SizedBox(width: 8),
                  // Allow business switching for gmanusers with edit_business permission OR multi-business employees
                  if(canEditBusiness || ((_profileController.user['business'] as List<dynamic>?)?.length ?? 0) > 1)
                    GestureDetector(
                      onTap: () {
                        // Simulate a DropdownButton by showing the menu when the icon is clicked
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(100, 100, 0, 0), // Adjust this for proper positioning
                          items: [
                            ...businessListController.businesses.map((business) {
                              return PopupMenuItem<BusinessModel>(
                                value: business,
                                child: Text(business.name),
                              );
                            }).toList(),
                            // Add the "Add New Business" option
                            PopupMenuItem<BusinessModel>(
                              value: null,
                              child: Row(
                                children: [
                                  Icon(Icons.add, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('add_new_business'.tr),
                                ],
                              ),
                            ),
                          ],
                        ).then((newBusiness) async {
                          // Check if "Add New Business" was clicked (returns null)
                          if (newBusiness == null) {
                            // Show dialog to add a new business
                            if (_profileController.user['maxBusiness'] > ((_profileController.user['business'] as List<dynamic>?)?.length ?? 0)) {
                              showAddBusinessDialog(context);
                            } else {
                              print("Exceeded max business limit");
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: Text('business_limit_reached'.tr),
                                    content: Text( '${'max_business_reached_message'.tr} (${_profileController.user['maxBusiness']})',),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          print("Dialog closed");
                                          Navigator.of(context).pop();
                                        },
                                        child: Text('ok_caps'.tr),
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          } else {
                            // A business was selected - Update the business ID and restart controllers
                            await _businessController.updateBusinessId(newBusiness.id);
                            await Preferences.setBusiness(newBusiness.id);
                            restartAllControllers();
                          }
                        });
                      },
                      child: Icon(Icons.arrow_drop_down, color: Colors.white),
                    ),
                ],
              );
            }),
            actions: _appVersion.isEmpty
                ? null
                : [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        _appVersion,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
          ),


          drawer: isAccountActive
              ? SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: Drawer(
              child: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    UserAccountsDrawerHeader(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                      ),
                      margin: EdgeInsets.zero,
                      accountName: Text(
                        accountName,
                        style:  TextStyle(
                          fontSize:getFontSize(context, 20),
                          fontWeight: FontWeight.w500,
                        ),
                        softWrap: true,
                        overflow: TextOverflow.visible,
                      ),
                      accountEmail: Text(
                        accountEmail,
                        style:  TextStyle(
                          color: Colors.white, // Set the phone number color to red
                          fontSize: getFontSize(context, 10), // You can adjust the font size as needed
                        ),
                      ),
                    ),

                    GetBuilder<BusinessController>(
                      builder: (bc) {
                        final role =
                            (_profileController.user['role'] ?? '').toString();
                        final line =
                            BusinessShopLocation.displayLine(bc.business);
                        final children = <Widget>[];

                        if (line.isNotEmpty) {
                          children.add(
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 18,
                                    color: Colors.grey[700],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      line,
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.25,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        if (role == 'owner' &&
                            !BusinessShopLocation.isComplete(bc.business)) {
                          children.add(
                            ShopLocationDrawerBanner(
                              onTap: () {
                                Navigator.pop(context);
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!context.mounted) return;
                                  showShopLocationEditorDialog(context);
                                });
                              },
                            ),
                          );
                        }

                        if (children.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: children,
                        );
                      },
                    ),

                    // GENERATE REPORTS - Independent item at the top
                    if(canEditBusiness)
                      DrawerTile(
                        title: 'Generate Reports'.tr,
                        icon: Icons.description,
                        route: 'reports',
                      ),

                    if(canEditBusiness)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.0),
                        child: Divider(),
                      ),

                    // TOP LEVEL ITEMS - Frequently accessed
                    DrawerTile(
                      title: 'expenses'.tr,
                      icon: Icons.account_balance_wallet,
                      route: 'expenses',
                    ),
                    
                    if (_businessController.isPurchasesAllowedForRole(
                        (_profileController.user['role'] ?? '').toString()))
                      DrawerTile(
                        title: 'Purchases'.tr,
                        icon: Icons.import_export,
                        route: 'bought',
                      ),
                    
                    DrawerTile(
                      title: 'Debt Records'.tr,
                      icon: Icons.money,
                      route: 'debt',
                    ),
                    
                    if(canEditBusiness)
                      DrawerTile(
                        title: 'Employees'.tr,
                        icon: Icons.person_add,
                        route: 'addemployee',
                      ),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Divider(),
                    ),

                    // STATISTICS - Independent item
                    if(canEditBusiness)
                      DrawerTile(
                        title: 'Statistics'.tr,
                        icon: Icons.bar_chart,
                        route: 'statistics',
                      ),

                    // MORE SECTION - Contains advanced features
                    _buildMoreSection(context, canEditBusiness),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Divider(),
                    ),

                    // SETTINGS & SUPPORT (Direct items)
                    DrawerTile(
                      title: 'Settings'.tr,
                      icon: Icons.settings,
                      route: 'settings',
                    ),
                    DrawerTile(
                      title: 'Support'.tr,
                      icon: Icons.help_outline,
                      route: 'support',
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                      child: Divider(),
                    ),
                    
                    // ACCOUNT STATUS
                    DrawerTile(
                      title: 'Account Status'.tr,
                      icon: Icons.card_membership,
                      route: 'subscription',
                    ),
                  ],
                ),
              ),
            ),
          )
              : null,
          body: SingleChildScrollView(
            child: Column(
              children: [
                SubscriptionExpiryBanner(),
                Container(
                  padding: const EdgeInsets.all(20),
                  color: primaryColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 25),
                      if (canEditBusiness)
                        InfoTile(
                          onTap: () async {
                            isBuyingStock = !isBuyingStock; // Toggle the value
                            await Preferences.setStockDisplayPreference(isBuyingStock); // Save the new preference

                            // Display the appropriate snackbar
                            Get.snackbar(
                              'Switched'.tr,
                              isBuyingStock
                                  ? 'Displaying STOCK by BUYING PRICE'.tr
                                  : 'Displaying STOCK by SELLING PRICE'.tr,
                              snackPosition: SnackPosition.TOP,
                              backgroundColor: Colors.green,
                              colorText: Colors.white,
                            );

                            // Update the UI or recalculate stock values
                            setState(() {});
                          },
                          title: "total_stock".tr,
                          trailing: formatCurrency(
                            isBuyingStock
                                ? productController.calculateTotalStockBuying()
                                : productController.calculateTotalStock(),
                            _businessController.business['mainCurrency'],
                          ),
                        ),
                      InfoTile(
                        onTap: () async {
                          await _showTotalSalesDialog(
                            context,
                            _saleController,
                            _debtHistoryController,
                            _boughtController,
                            expenceController,
                            _businessController.business['reset_time'],
                          );
                        },
                        title: "total_sales".tr,
                        trailing: formatCurrency(
                          _saleController.getTotalPaymentFromTimestamp(
                              _businessController.business['reset_time'],Timestamp.now()),
                          _businessController.business['mainCurrency'],
                        ),
                      ),
                      // Backend aggregates / "Available balance (Backend)" — hidden (test mode only).
                      // Only show service sales InfoTile if value > 0
                      Builder(
                        builder: (context) {
                          final serviceSales = _saleController.getTotalServiceSalesFromTimestamp(
                              _businessController.business['reset_time'], Timestamp.now());
                          if (serviceSales > 0) {
                            return InfoTile(
                              onTap: () {},
                              title: "service_sales".tr,
                              trailing: formatCurrency(
                                serviceSales,
                                _businessController.business['mainCurrency'],
                              ),
                            );
                          } else {
                            return SizedBox.shrink();
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      InfoTile(
                        onTap: () {
                          DateTimeRange range = DateTimeRange(
                            start: DateUtils.dateOnly(DateTime.now()),
                            end: DateTime.now(),
                          );
                          _saleController.setSelectedDateRange(range);
                          Navigator.pushNamed(context, '/sales');
                        },
                        title: "today_sales".tr,
                        trailing: formatCurrency(
                          _saleController.getTodaySales(),
                          _businessController.business['mainCurrency'],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),

                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ScreensCard(
                              title: 'all_sales'.tr,
                              backgroundColor: const Color(0xFFFDF0D6),
                              route: '/sales',
                              child: const Icon(
                                Icons.receipt,
                                color: Color(0xFFE49639),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ScreensCard(
                              title: 'products'.tr,
                              backgroundColor: const Color(0xFFFCE2E6),
                              route: '/products',
                              child: Image.asset(
                                'assets/images/products.png',
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ScreensCard(
                              title: 'clients'.tr,
                              backgroundColor: const Color(0xFFDFF7FF),
                              route: '/clients',
                              child: const Icon(
                                Icons.people,
                                color: Color(0xFF00C2FF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ScreensCard(
                              title: 'New Sale'.tr,
                              backgroundColor: const Color(0xFFDAF9DA),
                              route: '/sale/add',
                              child: const Icon(
                                Icons.shopping_basket,
                                color: Color(0xFF64BE62),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: ScreensCard(
                              title: 'all_invoices'.tr,
                              backgroundColor: const Color(0xFFFDF0D6),
                              route: '/invoices',
                              child: const Icon(
                                Icons.receipt,
                                color: Color(0xFFE49639),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Obx(() {
                              final pendingCount = _transferController.incomingTransferRequests
                                  .where((request) => request.status == 'pending')
                                  .length;
                              return Stack(
                                children: [
                                  ScreensCard(
                                    title: 'Transfer Requests'.tr,
                                    backgroundColor: const Color(0xFFE8F4FD),
                                    route: '/transfer_requests',
                                    child: const Icon(
                                      Icons.swap_horiz,
                                      color: Color(0xFF2196F3),
                                    ),
                                  ),
                                  if (pendingCount > 0)
                                    Positioned(
                                      top: 20,
                                      right: 20,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        child: Text(
                                          pendingCount.toString(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreSection(BuildContext context, bool canEditBusiness) {
    return _MoreExpandableSection(
      canEditBusiness: canEditBusiness,
      profileController: _profileController,
      businessController: _businessController,
    );
  }
}

class _MoreExpandableSection extends StatefulWidget {
  final bool canEditBusiness;
  final ProfileController profileController;
  final BusinessController businessController;

  const _MoreExpandableSection({
    Key? key,
    required this.canEditBusiness,
    required this.profileController,
    required this.businessController,
  }) : super(key: key);

  @override
  State<_MoreExpandableSection> createState() => _MoreExpandableSectionState();
}

class _MoreExpandableSectionState extends State<_MoreExpandableSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.more_horiz,
                    color: Theme.of(context).primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'More'.tr,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Container(
            padding: const EdgeInsets.only(left: 8),
            child: Column(
              children: [
                // HR & PAYROLL SUBSECTION
                if (widget.canEditBusiness && widget.profileController.hasPermission('manage_payroll'))
                  ExpandableDrawerSection(
                    title: 'HR & Payroll'.tr,
                    icon: Icons.people,
                    initiallyExpanded: false,
                    items: [
                      DrawerMenuItem(
                        title: 'Pay Roles'.tr,
                        icon: Icons.payment,
                        route: 'pay-roles',
                      ),
                      DrawerMenuItem(
                        title: 'Payment Management'.tr,
                        icon: Icons.account_balance,
                        route: 'payment-management',
                      ),
                    ],
                  ),

                // INVENTORY & PRODUCTS SUBSECTION
                ExpandableDrawerSection(
                  title: 'Inventory & Products'.tr,
                  icon: Icons.inventory,
                  initiallyExpanded: false,
                  items: [
                    if (widget.canEditBusiness)
                      DrawerMenuItem(
                        title: 'Products in Store'.tr,
                        icon: Icons.production_quantity_limits_rounded,
                        route: 'store/add',
                      ),
                    DrawerMenuItem(
                      title: 'Transfer Requests'.tr,
                      icon: Icons.swap_horiz,
                      route: 'transfer_requests',
                    ),
                    if (widget.canEditBusiness)
                      DrawerMenuItem(
                        title: 'Inventory Losses'.tr,
                        icon: Icons.warning_amber_rounded,
                        route: 'inventory-losses',
                      ),
                  ].where((item) => item != null).cast<DrawerMenuItem>().toList(),
                ),

                // FINANCE & ACCOUNTING SUBSECTION
                ExpandableDrawerSection(
                  title: 'Finance & Accounting'.tr,
                  icon: Icons.account_balance,
                  initiallyExpanded: false,
                  items: [
                    DrawerMenuItem(
                      title: 'Ledger'.tr,
                      icon: Icons.receipt_long,
                      route: 'ledger',
                    ),
                    if (widget.canEditBusiness)
                      DrawerMenuItem(
                        title: 'Assets'.tr,
                        icon: Icons.business_center,
                        route: 'assets',
                      ),
                    if (widget.businessController.isPurchasesAllowedForRole(
                        (widget.profileController.user['role'] ?? '').toString()))
                      ...[
                        DrawerMenuItem(
                          title: 'Supplier Debts'.tr,
                          icon: Icons.account_balance_wallet,
                          route: 'supplier-debt',
                        ),
                        DrawerMenuItem(
                          title: 'Suppliers'.tr,
                          icon: Icons.local_shipping,
                          route: 'suppliers',
                        ),
                      ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}