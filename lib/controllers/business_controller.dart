import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';
import 'profile_controller.dart';
import '../services/fund_source_service.dart';
import '../utils/constants.dart';
import '../utils/firestore_auth_retry.dart';
import '../utils/preferences.dart';
import '../utils/receipt_footer.dart';
import '../utils/business_shop_location.dart';
import '../utils/sms_settings.dart';

class BusinessController extends GetxController {
  final Rx<Map<String, dynamic>> _business = Rx<Map<String, dynamic>>({});
  Map<String, dynamic> get business => _business.value;
  final Rx<String> businessId = "".obs;

  /// From Firestore `debtEnabled` (Allow Debt in Settings). When false, sales cannot record client debt.
  bool get isDebtEnabled => _business.value['debtEnabled'] == true;

  /// Updates local state and prefs immediately when the owner toggles Allow Debt.
  Future<void> setDebtEnabled(bool value) async {
    final b = Map<String, dynamic>.from(_business.value);
    b['debtEnabled'] = value;
    _business.value = b;
    await Preferences.setEnabletDebt(value);
    update();
  }

  /// Keeps [business.invoicePaymentDetails] in sync for receipts without waiting for Firestore refetch.
  /// Call after editing payment methods locally (e.g. invoice payment settings).
  void syncInvoicePaymentDetails(List<Map<String, dynamic>> rows) {
    final next = List<Map<String, dynamic>>.from(
      rows.map((e) => paymentDetailMapFromFirestore(e)),
    );
    final b = Map<String, dynamic>.from(_business.value);
    b['invoicePaymentDetails'] = next;
    _business.value = b;
    update();
  }

  /// Merge shop address keys after Firestore write so the drawer banner updates immediately.
  void mergeShopLocationPatch(Map<String, dynamic> patch) {
    final b = Map<String, dynamic>.from(_business.value);
    for (final key in [
      BusinessShopLocation.firestoreCountryKey,
      BusinessShopLocation.firestoreCityKey,
      BusinessShopLocation.firestoreStreetKey,
    ]) {
      if (patch.containsKey(key)) {
        b[key] = patch[key];
      }
    }
    _business.value = b;
    update();
  }

  @override
  void onInit() {
    super.onInit();
    // Avoid Firestore reads with a stale business id while signed out
    // (desktop/web often surfaces that as permission-denied).
    if (!Preferences.isLoggedIn()) return;
    final id = Preferences.getBusiness();
    if (id.isNotEmpty) {
      businessId.value = id;
      Future.microtask(() => updateBusinessData());
    }
  }

  final RxList<Map<String, dynamic>> _fundSources =
      <Map<String, dynamic>>[].obs;

  List<Map<String, dynamic>> get allFundSources => _fundSources.toList();

  /// Allow Purchases (Firestore `additionalString1` → [business]['purchases']).
  /// Applies to all roles including owner.
  bool get isPurchasesEnabled =>
      (_business.value['purchases']?.toString() ?? 'false') == 'true';

  SmsSettings get smsSettings =>
      SmsSettings.fromMap(_business.value['smsSettings']);

  /// Allow Multiple Fund Sources (`multiFundEnabled` on business).
  bool get isMultiFundEnabled =>
      (_business.value['multiFundEnabled'] ?? false) == true;

  Future<void> setMultiFundEnabled(bool value) async {
    final b = Map<String, dynamic>.from(_business.value);
    b['multiFundEnabled'] = value;
    _business.value = b;
    update();
  }

  /// Default fund source when multi-fund is disabled (single cash bucket).
  static const String singleFundSourceValue = 'cash';

  /// Business setting + role (Sales Person / Agent always denied).
  bool isPurchasesAllowedForRole(String userRole) {
    final r = userRole == 'employee' ? 'sales_person' : userRole;
    if (ProfileController.purchaseExcludedRoles.contains(r)) return false;
    return isPurchasesEnabled;
  }

  Future<void> setPurchasesEnabled(bool value) async {
    final flag = value ? 'true' : 'false';
    final b = Map<String, dynamic>.from(_business.value);
    b['purchases'] = flag;
    _business.value = b;
    await Preferences.setEnablePurchases(flag);
    update();
  }

  void reloadFundSources(List<Map<String, dynamic>> list) {
    _fundSources.assignAll(list);
    update();
  }

  /// Checkout / payroll / debt UIs say "payment method" but use the same catalog as fund sources.
  List<Map<String, dynamic>> get effectivePaymentMethods =>
      effectiveFundSources;

  List<Map<String, dynamic>> _fundSourceRowsForLookup() {
    if (businessId.value.isEmpty || _fundSources.isEmpty) {
      return List<Map<String, dynamic>>.from(FundSourceService.defaultFundSources);
    }
    return List<Map<String, dynamic>>.from(_fundSources);
  }

  /// Old sales/payroll used payment-method `value` strings; map to default fund source ids.
  static String? _legacyPaymentMethodValueAlias(String v) {
    switch (v) {
      case 'bank_transfer':
      case 'check':
        return 'bank';
      case 'mobile_money':
        return 'mobile';
      default:
        return null;
    }
  }

  static bool _entryIsActive(Map<String, dynamic> e) {
    final v = e['isActive'];
    if (v == null) return true;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    if (s == 'false' || s == '0' || s == 'no') return false;
    if (s == 'true' || s == '1' || s == 'yes') return true;
    return true;
  }

  List<Map<String, dynamic>> get effectiveFundSources {
    if (businessId.value.isEmpty) {
      return List.from(FundSourceService.defaultFundSources);
    }
    if (_fundSources.isEmpty) {
      return List.from(FundSourceService.defaultFundSources);
    }
    final active = _fundSources.where((e) => _entryIsActive(e)).toList();
    // Use Firestore rows only — do not replace with hardcoded defaults when we have data
    return active.isNotEmpty ? active : List<Map<String, dynamic>>.from(_fundSources);
  }

  /// Rows for payment / fund-source dropdowns: [effectiveFundSources], plus the row for
  /// [currentValue] if it exists in the full catalog but was dropped (e.g. inactive), so we
  /// do not reset the selection to [values.first] (usually **cash**).
  List<Map<String, dynamic>> _cashOnlyFundSourceRows(
    List<Map<String, dynamic>> catalog,
  ) {
    for (final e in catalog) {
      final v = e['value']?.toString() ?? '';
      final lt = e['ledgerType']?.toString() ?? '';
      if (v == singleFundSourceValue || lt == singleFundSourceValue) {
        return [Map<String, dynamic>.from(e)];
      }
    }
    for (final e in FundSourceService.defaultFundSources) {
      if (e['value'] == singleFundSourceValue) {
        return [Map<String, dynamic>.from(e)];
      }
    }
    return [
      Map<String, dynamic>.from(FundSourceService.defaultFundSources.first),
    ];
  }

  List<Map<String, dynamic>> paymentMethodsForDropdown({String? currentValue}) {
    var base = List<Map<String, dynamic>>.from(effectiveFundSources);
    if (!isMultiFundEnabled) {
      return _cashOnlyFundSourceRows(base);
    }
    final cv = (currentValue ?? '').trim();
    if (cv.isEmpty) return base;

    bool containsKey(List<Map<String, dynamic>> rows, String key) {
      for (final e in rows) {
        if (e['value']?.toString() == key || e['id']?.toString() == key) {
          return true;
        }
      }
      return false;
    }

    if (containsKey(base, cv)) return base;

    for (final e in allFundSources) {
      if (e['value']?.toString() == cv || e['id']?.toString() == cv) {
        return [...base, Map<String, dynamic>.from(e)];
      }
    }
    for (final e in FundSourceService.defaultFundSources) {
      if (e['value']?.toString() == cv) {
        return [...base, Map<String, dynamic>.from(e)];
      }
    }
    return base;
  }

  /// True if [key] matches a catalog row's `value` or document `id` (custom sources use id as value).
  bool isKnownFundSourceKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    for (final e in _fundSourceRowsForLookup()) {
      final ev = e['value']?.toString().trim();
      final ei = e['id']?.toString().trim();
      if (ev == k || ei == k) {
        return true;
      }
    }
    return false;
  }

  String getLedgerTypeForMethod(String value) {
    final rows = _fundSourceRowsForLookup();
    String? ledgerTypeForValue(String key) {
      final k = key.trim();
      if (k.isEmpty) return null;
      for (final e in rows) {
        final ev = e['value']?.toString().trim();
        final ei = e['id']?.toString().trim();
        if (ev == k || ei == k) {
          return e['ledgerType']?.toString();
        }
      }
      return null;
    }

    var lt = ledgerTypeForValue(value.trim());
    if (lt != null && lt.isNotEmpty) return lt;

    final aliased = _legacyPaymentMethodValueAlias(value.trim());
    if (aliased != null) {
      lt = ledgerTypeForValue(aliased);
      if (lt != null && lt.isNotEmpty) return lt;
      if (aliased == 'bank') return 'bank';
      if (aliased == 'mobile') return 'mobile';
    }
    return 'cash';
  }

  /// Display name for a stored payment `method` value (fund source `value` or legacy payment ids).
  String paymentMethodLabelForValue(String? methodValue) {
    final v = (methodValue ?? 'cash').toString().trim();
    final rows = _fundSourceRowsForLookup();
    String? labelForValue(String key) {
      final k = key.trim();
      if (k.isEmpty) return null;
      for (final e in rows) {
        final ev = e['value']?.toString().trim();
        final ei = e['id']?.toString().trim();
        if (ev == k || ei == k) {
          final lab = (e['label'] ?? e['name'])?.toString().trim();
          if (lab != null && lab.isNotEmpty) return lab;
        }
      }
      return null;
    }

    final directLabel = labelForValue(v);
    if (directLabel != null) return directLabel;

    final aliased = _legacyPaymentMethodValueAlias(v);
    if (aliased != null) {
      final aliasedLabel = labelForValue(aliased);
      if (aliasedLabel != null) return aliasedLabel;
    }
    if (v == 'bank') return 'Bank';
    if (v == 'mobile') return 'Lipa Namba (Mobile)';
    if (v == 'cash') return 'Cash';
    if (v == 'bank_transfer') return 'Bank Transfer';
    if (v == 'mobile_money') return 'Mobile Money';
    if (v == 'check') return 'Check';
    return v;
  }

  Future<void> updateBusinessId(String businessIdd) async {
    if (businessIdd.isNotEmpty) {
      print('Updating businessId to: $businessIdd'); // Debugging
      businessId.value = businessIdd; // Update the reactive businessId
      await Preferences.setBusiness(businessIdd); // Persist the business ID
      await updateBusinessData(); // Fetch and update the business data
      print('businessId updated to: ${businessId.value}'); // Confirm update
    } else {
      print('Business ID is empty, skipping update.');
    }
  }
  void clearBusiness() {
   _business.value.clear(); // Clear the contents of the reactive map
    businessId.value = '';   // Reset the reactive businessId
  }
/*
  Future<bool> hasInternetConnection({int timeoutSeconds = 6}) async {
    // Step 1: Check if Wi-Fi or mobile data is turned on
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      return false; // No network connection
    }

    // Step 2: Check if internet is reachable with a timeout
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          return [];
        },
      );
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true; // Internet is accessible
      }
    } catch (e) {
      return false;
    }

    return false; // Internet is not accessible
  }*/
  Future<void> updateBusinessData() async {
    try {
      if (businessId.value.isNotEmpty) {
        print('Fetching business data for ID: ${businessId.value}'); // Debugging

        var snapshot = await firestoreGetWithAuthRetry(
          firestore.collection('businesses').doc(businessId.value),
        );

        if (snapshot.exists) {
          final rawData = snapshot.data() as Map<String, dynamic>;
          var business = BusinessModel.fromSnapshot(snapshot);

          _business.value = {
            'name': business.name,
            'categories': business.categories,
            'expenseCategories': business.expenseCategories,
            'units': business.additionalList1,
            'manufacturer': business.manufacturer,
            'location': business.location,
            'email': business.email,
            'logo': business.logo,
            'expireWarning': business.expireWarning,
            'allowSalesView': business.allowSalesView,
            'discountPercent': business.discountPercent,
            'phone': business.phone,
            'tin': business.tin,
            'debtEnabled': business.debtEnabled,
            'multiFundEnabled': business.multiFundEnabled,
            'reset_time': business.reset_time,
            'subscriptionStatus': business.subscriptionStatus,
            'id': business.id,
            'owner': business.ownerId,
            'storeId': business.additionalString2,
            'purchases': business.additionalString1,
            'mainCurrency': business.mainCurrency,
            'secondaryCurrency': business.secondaryCurrency,
            'date': business.date,
            'trialStart': business.trialStart,
            'paymentStart': business.paymentStart,
            'paymentLast': business.paymentLast,
            'smsCredits': (rawData['smsCredits'] as num?)?.toInt() ?? 0,
            'smsCreditsUsed': (rawData['smsCreditsUsed'] as num?)?.toInt() ?? 0,
            'smsCreditsTotalPurchased':
                (rawData['smsCreditsTotalPurchased'] as num?)?.toInt() ?? 0,
            'smsSettings': rawData['smsSettings'] is Map
                ? Map<String, dynamic>.from(rawData['smsSettings'] as Map)
                : <String, dynamic>{},
            'invoicePaymentDetails': rawData['invoicePaymentDetails'] != null
                ? List<Map<String, dynamic>>.from(
                    (rawData['invoicePaymentDetails'] as List)
                        .map((e) => paymentDetailMapFromFirestore(e)),
                  )
                : <Map<String, dynamic>>[],
            'installReferrerCode': rawData['installReferrerCode']?.toString() ?? '',
            'receiptFooterMessage':
                rawData['receiptFooterMessage']?.toString() ?? '',
            // Optional business-level names (invoices / PDFs) if not on each payment row
            'paymentAccountName':
                rawData['paymentAccountName']?.toString() ?? '',
            'accountsName': rawData['accountsName']?.toString() ?? '',
            'invoiceAccountName':
                rawData['invoiceAccountName']?.toString() ?? '',
            BusinessShopLocation.firestoreCountryKey:
                rawData[BusinessShopLocation.firestoreCountryKey]
                        ?.toString() ??
                    BusinessShopLocation.defaultCountry,
            BusinessShopLocation.firestoreCityKey:
                rawData[BusinessShopLocation.firestoreCityKey]?.toString() ??
                    '',
            BusinessShopLocation.firestoreStreetKey:
                rawData[BusinessShopLocation.firestoreStreetKey]?.toString() ??
                    '',
          };

          print('Business data updated: ${_business.value}');

          // Keep local toggles aligned with Firestore for Settings UI.
          final p = rawData['additionalString1']?.toString().trim() ?? '';
          await Preferences.setEnablePurchases(p == 'true' ? 'true' : 'false');
          await Preferences.setEnabletDebt(business.debtEnabled);

          // Fund sources: used for expenses and for all "payment method" pickers (sales, payroll, debts).
          try {
            final fs = await FundSourceService().loadFundSources(businessId.value);
            _fundSources.assignAll(fs);
          } catch (e, st) {
            print('loadFundSources failed: $e\n$st');
          }
        } else {
          print('No business found for ID: ${businessId.value}');
          _business.value = {};
        }

      } else {
        print('Business ID is empty, cannot fetch business data.');
      }
    } catch (e) {
      print('Error fetching business data: $e');
      errorSnackbar('Error fetching business data: $e');
    }
    update(); // Notify listeners of state changes
  }



  Future<void> copyProductsToNewBusiness() async {
    String oldBusinessId = 'zwj25mxWE2mg8Uo8zGzl';
    String newBusinessId = 'o1CkKYKjlvhXKnoII2lrYSUtAax1';
    try {
      // Reference to the original products collection
      final oldProductsRef = firestore
          .collection('products')
          .doc(oldBusinessId)
          .collection('userProducts');

      // Reference to the new store products collection
      final newStoreRef = firestore
          .collection('store')
          .doc(newBusinessId)
          .collection('userStore');

      // Get all products from the old business collection
      final oldProductsSnapshot = await oldProductsRef.get();

      // Loop through each product
      for (var oldProductDoc in oldProductsSnapshot.docs) {
        var oldProductData = oldProductDoc.data();
        String productId = oldProductDoc.id;  // Use the same ID as the original product

        // Prepare new product data with quantity explicitly set to zero
        final newProductData = {
          ...oldProductData,  // Copy existing fields
          'quantity': 0,  // Set the quantity to zero
        };

        // Use the same document ID for the store product in the new business
        final newProductRef = newStoreRef.doc(productId);

        // Set the new product data in the store collection with quantity set to zero
        await newProductRef.set(newProductData);
      }

      print("Products copied successfully to store with quantity set to zero!");
      successSnackbar("Products copied successfully to store with quantity set to zero!");
    } catch (e) {
      print("Failed to copy products: $e");
    }
  }


  // Method to add a new business


  Future<bool> isAccountActive() async {
    await updateBusinessData();
    return _business.value['subscriptionStatus'] == 'subscription_ok' || _business.value['subscriptionStatus'] == 'subscription_ontrial';
  }

  // Get subscription expiry date (works for both trial and paid)
  DateTime? getSubscriptionExpiryDate() {
    // PAID BUSINESS: Use paymentLast
    if (_business.value['paymentLast'] != null) {
      return (_business.value['paymentLast'] as Timestamp).toDate();
    }
    
    // TRIAL BUSINESS: Calculate trialStart + 30 days
    if (_business.value['trialStart'] != null) {
      final trialStart = (_business.value['trialStart'] as Timestamp).toDate();
      return trialStart.add(Duration(days: 30));
    }
    
    // NEW BUSINESS: No dates set yet
    return null;
  }

  // Calculate days until subscription expires
  int? getDaysUntilSubscriptionExpiry() {
    final expiryDate = getSubscriptionExpiryDate();
    if (expiryDate == null) return null;
    
    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    
    return difference.inDays;
  }

  // Check if should show subscription warning
  bool shouldShowSubscriptionWarning() {
    final daysLeft = getDaysUntilSubscriptionExpiry();
    if (daysLeft == null) return false;
    
    // Show warning 7 days before expiry
    const warningThreshold = 7;
    return daysLeft >= 0 && daysLeft <= warningThreshold;
  }

  // Get subscription type for display
  String getSubscriptionType() {
    if (_business.value['paymentLast'] != null) {
      return 'Paid';
    }
    if (_business.value['trialStart'] != null) {
      return 'Trial';
    }
    // Fallback: check subscriptionStatus if no date fields
    final status = _business.value['subscriptionStatus'];
    if (status == 'subscription_ontrial') {
      return 'Trial';
    }
    if (status == 'subscription_ok') {
      return 'Paid';
    }
    return 'Unknown';
  }

  // Get formatted expiry date string
  String? getFormattedExpiryDate() {
    final expiryDate = getSubscriptionExpiryDate();
    if (expiryDate == null) return null;
    
    return '${expiryDate.day.toString().padLeft(2, '0')}.${expiryDate.month.toString().padLeft(2, '0')}.${expiryDate.year}';
  }
}
