import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/ui/screens/sale/edit_sale.screen.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/supplier_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/business_controller.dart';
import '../../controllers/supplier_debt_controller.dart';
import '../../models/supplier_model.dart';
import '../../utils/constants.dart';
import '../../utils/preferences.dart';
import '../widgets/bottomsheets/comment_bottom_sheet.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/dashed_seperator.dart';
import '../widgets/dialogs/add_to_buy_dialog.dart';
import 'package:intl/intl.dart';
import '../../services/ledger_service.dart';
import '../../models/stock_transaction.dart';
import '../../constants/transaction_constants.dart';

class BuyProductCartScreen extends StatefulWidget {
  final UserData? userData; // Optional user data for flexibility
  const BuyProductCartScreen({Key? key,this.userData}) : super(key: key);

  @override
  State<BuyProductCartScreen> createState() => _BuyProductCartScreenState();
}

class _BuyProductCartScreenState extends State<BuyProductCartScreen> {
  final CartController _cartController = Get.find();
  final SupplierController _supplierController = Get.find();
  final ProductController _productController = Get.find();
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();
  final SupplierDebtController _supplierDebtController = Get.find();
  final TextEditingController _paidController = TextEditingController();
  final FocusNode _paidFocusNode = FocusNode();

  bool _isLoading = false;
  Map<String, dynamic>? _originalPurchaseData;
  DateTime? selectedDate;
  // Purchase fund source state
  String _fundSource = 'cash'; // cash | bank | mobile | other
  String _fundSourceOtherNote = '';
  
  // Purchase destination state
  String _purchaseDestination = 'shop'; // shop | store
  
  // Track manual edits and total changes
  bool _userEditedPaid = false;
  double _lastProductsTotal = 0.0;

  @override
  void initState() {
    super.initState();
    // If editing, fetch original purchase data
    if (_cartController.passedArgument != 'NOT') {
      _fetchOriginalPurchaseData();
    }
  }

  void _fetchOriginalPurchaseData() {
    final String? businessId = _businessController.business['id'];
    if (businessId == null) return;

    firestore
        .collection('recovered')
        .doc(businessId)
        .collection('userRecovered')
        .doc(_cartController.passedArgument)
        .get()
        .then((doc) {
      if (doc.exists) {
        setState(() {
          _originalPurchaseData = doc.data() as Map<String, dynamic>;
          selectedDate = (_originalPurchaseData!['date'] as Timestamp).toDate();
          _fundSource = (_originalPurchaseData!['fundSource'] as String?) ?? 'cash';
          _fundSourceOtherNote = (_originalPurchaseData!['fundSourceNote'] as String?) ?? '';
          _purchaseDestination = (_originalPurchaseData!['purchaseDestination'] as String?) ?? 'shop';
        });
      }
    }).catchError((error) {
      print('Error fetching original purchase data: $error');
    });
  }

  @override
  void dispose() {
    Timer.run(() {
      clearCartData();
    });
    _paidController.dispose();
    _paidFocusNode.dispose();
    super.dispose();
  }

  String get chosenCurrency => _businessController.business['mainCurrency'] ?? 'USD';

  /// Same flag as cart/sale screens; used in nested closures (e.g. Paid field [onChanged]).
  bool get _purchaseMultiFundEnabled =>
      (_businessController.business['multiFundEnabled'] ?? false) == true;

  @override
  Widget build(BuildContext context) {
    // CRITICAL SECURITY CHECK: Verify user has permission to buy products
    final bool purchasesOk = _businessController.isPurchasesAllowedForRole(
        (_profileController.user['role'] ?? '').toString());
    if (!_profileController.hasPermission('buy_products') || !purchasesOk) {
      final String deniedBody = !_profileController.hasPermission('buy_products')
          ? 'You do not have permission to access the product buying cart'
          : 'Purchases are disabled for this business. Contact the owner to enable.';
      return Scaffold(
        appBar: AppBar(
          title: Text('Access Denied'),
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock,
                size: 64,
                color: Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              SizedBox(height: 8),
              Text(
                deniedBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
    
    return WillPopScope(
      onWillPop: () async => _isLoading ? false : true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              Preferences.getTheme() ? darkGrayColor : primaryUltraLightColor,
          foregroundColor:
              Preferences.getTheme() ? primaryUltraLightColor : textDarkColor,
          title: Text('Buy Products'.tr),
          elevation: 0,
          leading: _isLoading
              ? Container()
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
        ),
        
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : Obx(
              () {
                // Ensure a default payment exists so amount is auto-filled
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_purchaseMultiFundEnabled && _fundSource != 'cash') {
                    setState(() {
                      _fundSource = 'cash';
                    });
                    if (_cartController.payments.length > 0) {
                      final existing = _cartController.payments[0];
                      _cartController.clearPayments();
                      _cartController.addPayment(existing.amount, existing.currency, method: 'cash');
                    }
                  }
                  // Payment `method` must be the fund source catalog `value` (custom = doc id),
                  // not ledger bucket — so ledger/sales lists show the label the user configured.
                  final String defaultMethod =
                      !_purchaseMultiFundEnabled ? 'cash' : _fundSource;
                  
                  // Calculate current total
                  final double currentTotal = _cartController.productsPrice - _cartController.discount.value;
                  final double calcAmount = currentTotal < 0 ? 0 : currentTotal;
                  
                  // Check if total changed (product added/removed or discount changed)
                  if ((_lastProductsTotal - currentTotal).abs() > 0.0001) {
                    _lastProductsTotal = currentTotal;
                    _userEditedPaid = false; // Reset user edit flag when total changes
                  }
                  
                  if (_cartController.payments.length == 0 && _cartController.productsPrice > 0) {
                    _cartController.addPayment(calcAmount, chosenCurrency, method: defaultMethod);
                    _paidController.text = formatCurrencyWithoutSymbol(calcAmount);
                  } else if (_cartController.payments.length == 1 && _cartController.payments[0].method != defaultMethod) {
                    // If the fund source changed, update only the method and preserve amount and currency
                    final existing = _cartController.payments[0];
                    _cartController.clearPayments();
                    _cartController.addPayment(existing.amount, existing.currency, method: defaultMethod);
                  }
                  
                  // Only auto-fill if user hasn't manually edited AND field is not focused
                  if (!_userEditedPaid && _cartController.payments.length == 1 && !_paidFocusNode.hasFocus) {
                    final existing = _cartController.payments[0];
                    if ((existing.amount - calcAmount).abs() > 0.0001) {
                      _cartController.clearPayments();
                      _cartController.addPayment(calcAmount, existing.currency, method: existing.method);
                      _paidController.text = formatCurrencyWithoutSymbol(calcAmount);
                    }
                  }
                });
                
                // Supplier selector field
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                    height: 44,
                    child: TextField(
                      onTap: () {
                        Navigator.pushNamed(context, '/supplier/select')
                            .then(
                              (value) {
                                if (value != null && value is Supplier) {
                                  _cartController.setSupplier(value as Supplier);
                                }
                                setState(() {});
                              },
                        );
                      },
                      readOnly: true,
                      decoration: InputDecoration(
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        hintText: _cartController.supplier?.name ??
                            'select_supplier_optional'.tr,
                        hintStyle: bodyText(
                            _cartController.supplier != null
                                ? Theme.of(context).textTheme.bodyLarge!.color
                                : textPlaceholderColor),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Preferences.getTheme()
                                ? mediumGrayColor
                                : borderColor,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        suffixIcon:
                        const Icon(Icons.keyboard_arrow_right),
                        prefixIcon: const Icon(Icons.business),
                      ),
                    ),
                        ),
                      ),
                      const SizedBox(height: 16),
                
                // Source of Funds Selector (visible only if multi-fund is enabled)
                if ((_businessController.business['multiFundEnabled'] ?? false) == true)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Obx(() {
                          final sources = _businessController
                              .paymentMethodsForDropdown(
                                  currentValue: _fundSource);
                          if (sources.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final values = sources
                              .map((e) => e['value']?.toString() ?? '')
                              .where((v) => v.isNotEmpty)
                              .toList();
                          if (values.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          final safe = values.contains(_fundSource)
                              ? _fundSource
                              : values.first;
                          if (safe != _fundSource) {
                            WidgetsBinding.instance
                                .addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _fundSource = safe;
                                  if (_fundSource != 'other') {
                                    _fundSourceOtherNote = '';
                                  }
                                });
                              }
                            });
                          }
                          return DropdownButtonFormField<String>(
                            value: safe,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              labelText: 'Source of Funds',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Preferences.getTheme()
                                      ? mediumGrayColor
                                      : borderColor,
                                ),
                              ),
                            ),
                            items: sources
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
                                .toList(),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _fundSource = val;
                                if (_fundSource != 'other') {
                                  _fundSourceOtherNote = '';
                                }
                              });
                            },
                          );
                        }),
                        if (_fundSource == 'other') ...[
                          const SizedBox(height: 8),
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Describe other source (optional)'.tr,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Preferences.getTheme() ? mediumGrayColor : borderColor,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                            onChanged: (v) => _fundSourceOtherNote = v,
                          ),
                        ]
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // Date Picker Field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: () => _selectPurchaseDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Preferences.getTheme()
                              ? mediumGrayColor
                              : borderColor,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Date: ${selectedDate != null ? DateFormat("dd.MM.yyyy hh:mm a").format(selectedDate!) : 'Select Date'}',
                            style: bodyText(
                              Theme.of(context).textTheme.bodyLarge!.color,
                            ),
                          ),
                          const Icon(Icons.edit, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Purchase Destination Selector
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Products To:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodyLarge!.color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Preferences.getTheme()
                                ? mediumGrayColor
                                : borderColor,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Opacity(
                                opacity: _cartController.passedArgument != 'NOT' ? 0.5 : 1.0,
                                child: InkWell(
                                  onTap: _cartController.passedArgument != 'NOT' ? null : () {
                                    setState(() {
                                      _purchaseDestination = 'shop';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: _purchaseDestination == 'shop'
                                          ? primaryColor.withOpacity(0.1)
                                          : Colors.transparent,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(4),
                                        bottomLeft: Radius.circular(4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.business,
                                          color: _purchaseDestination == 'shop'
                                              ? primaryColor
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Shop/Business',
                                          style: TextStyle(
                                            color: _purchaseDestination == 'shop'
                                                ? primaryColor
                                                : Theme.of(context).textTheme.bodyLarge!.color,
                                            fontWeight: _purchaseDestination == 'shop'
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 44,
                              color: Preferences.getTheme()
                                  ? mediumGrayColor
                                  : borderColor,
                            ),
                            Expanded(
                              child: Opacity(
                                opacity: _cartController.passedArgument != 'NOT' ? 0.5 : 1.0,
                                child: InkWell(
                                  onTap: _cartController.passedArgument != 'NOT' ? null : () {
                                    setState(() {
                                      _purchaseDestination = 'store';
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: _purchaseDestination == 'store'
                                          ? primaryColor.withOpacity(0.1)
                                          : Colors.transparent,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(4),
                                        bottomRight: Radius.circular(4),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.store,
                                          color: _purchaseDestination == 'store'
                                              ? primaryColor
                                              : Colors.grey,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Store',
                                          style: TextStyle(
                                            color: _purchaseDestination == 'store'
                                                ? primaryColor
                                                : Theme.of(context).textTheme.bodyLarge!.color,
                                            fontWeight: _purchaseDestination == 'store'
                                                ? FontWeight.w600
                                                : FontWeight.normal,
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
                      const SizedBox(height: 4),
                      Text(
                        _purchaseDestination == 'shop'
                            ? 'Products will be added to business inventory'
                            : 'Products will be added directly to store',
                        style: TextStyle(
                          fontSize: 12,
                          color: textMutedColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Preferences.getTheme()
                        ? mediumGrayColor
                        : gray100Color,
                    border: Border.all(
                      color: Preferences.getTheme()
                          ? mediumGrayColor
                          : const Color(0xFFE0E0E0),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                        _cartController.getUniqueProducts().length,
                        itemBuilder: (context, index) {
                          final product =
                          _cartController.getUniqueProducts()[index];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: bodyText(
                                          Theme.of(context)
                                              .textTheme
                                              .bodyLarge!
                                              .color,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatCurrency(
                                            _cartController
                                                .getPrice(product.id),
                                            _businessController
                                                .business['mainCurrency']),
                                        style: const TextStyle(
                                          color: Color(0xFF999999),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      barrierDismissible: false,
                                      context: context,
                                      builder: (context) =>
                                          AddToBuyDialog(
                                            product: product,
                                            itemCounter: _cartController
                                                .singleProductQuantity(
                                              product.id,
                                            ),
                                          ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Preferences.getTheme()
                                            ? mediumGrayColor
                                            : const Color(0xFFE0E0E0),
                                        width: 1,
                                      ),
                                      borderRadius:
                                      BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${_cartController.singleProductQuantity(product.id)}x',
                                      style: h6(
                                        Preferences.getTheme()
                                            ? primaryLightColor
                                            : primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Preferences.getTheme()
                                ? mediumGrayColor
                                : const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        height: 36,
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/buy');
                          },
                          child: Text(
                            "add_product".tr,
                            style: bodyText(textMutedColor),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const DashedSeperator(width: 2),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'total'.tr}:',
                            style: bodyText(
                              Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color,
                            ),
                          ),
                          Text(
                            chosenCurrency ==
                                _businessController
                                    .business['mainCurrency']
                                ? formatCurrency(
                                _cartController.productsPrice,
                                chosenCurrency)
                                : formatCurrency(
                                _cartController.productsPrice /
                                    Preferences
                                        .getExchangeRateResult(),
                                chosenCurrency),
                            style: h6(
                              Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _paidController,
                          focusNode: _paidFocusNode,
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            // Mark that user has manually edited the paid field
                            _userEditedPaid = true;
                            final String v = value.trim();
                            double amt = 0.0;
                            if (v.isNotEmpty) {
                              try {
                                amt = double.parse(v.replaceAll(',', ''));
                              } catch (_) {
                                amt = 0.0;
                              }
                            }
                            if (_cartController.payments.length == 0) {
                              final String method = !_purchaseMultiFundEnabled
                                  ? 'cash'
                                  : _fundSource;
                              _cartController.addPayment(amt, chosenCurrency, method: method);
                            } else {
                              final existing = _cartController.payments[0];
                              _cartController.clearPayments();
                              _cartController.addPayment(amt, existing.currency, method: existing.method);
                            }
                          },
                          decoration: InputDecoration(
                            contentPadding: inputPadding,
                            labelText: 'paid'.tr,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: Preferences.getTheme() ? mediumGrayColor : primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${'remaining'.tr}: ${chosenCurrency == _businessController.business['mainCurrency'] ? formatCurrency(_cartController.remaining, chosenCurrency) : formatCurrency(_cartController.remaining / Preferences.getExchangeRateResult(), chosenCurrency)}',
                        style: bodyText(
                          _cartController.remaining > 0 ? warningColor : textPlaceholderColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      onTap: () {
                        showModalBottomSheet(
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          context: context,
                          builder: (BuildContext context) {
                            return const CommentBottomSheet();
                          },
                        );
                      },
                      readOnly: true,
                      decoration: InputDecoration(
                        contentPadding: inputPadding,
                        hintText: _cartController.comment != ''
                            ? _cartController.comment
                            : 'add_comment'.tr,
                        hintStyle: bodyText(
                          _cartController.comment != ''
                              ? Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .color
                              : textPlaceholderColor,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Preferences.getTheme()
                                ? mediumGrayColor
                                : borderColor,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: PrimaryButton(
                            color: greenColor,
                            text: 'confirm'.tr,
                            onPressed: () async {
                              if (_cartController.remaining > 0) {
                                // Check if supplier is selected when there's debt
                                if (_cartController.supplier == null || _cartController.supplier?.id == null || _cartController.supplier?.id == '') {
                                  // Show error snackbar if supplier is not selected
                                  Get.snackbar(
                                    'Error',
                                    'select_supplier_for_debt'.tr,
                                    duration: Duration(seconds: 6),
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  showModalBottomSheet(
                                    context: context,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                    builder: (context) {
                                      return Container(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.business,
                                              size: 48,
                                              color: warningColor,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'supplier_required'.tr,
                                              style: h5(textDarkColor),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'supplier_debt_explanation'.tr,
                                              textAlign: TextAlign.center,
                                              style: bodyText(textMutedColor),
                                            ),
                                            const SizedBox(height: 20),
                                            PrimaryButton(
                                              text: 'select_supplier'.tr,
                                              onPressed: () {
                                                Navigator.pop(context);
                                                Navigator.pushNamed(context, '/supplier/select')
                                                    .then((value) => setState(() {}));
                                              },
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                  return; // Stop the function from proceeding
                                }

                                // Check if the comment is missing
                                if (_cartController.comment == null || _cartController.comment!.isEmpty) {
                                  // Show error snackbar for 6 seconds if the comment is not added
                                  Get.snackbar(
                                    'Error',
                                    'add_debt_description'.tr,
                                    duration: Duration(seconds: 6),
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  return; // Stop the function from proceeding
                                }
                              }

// Continue with the sale logic if no errors

                              if (_cartController.products.length == 0) {
                                errorSnackbar('no_products_in_cart'.tr);
                                return;
                              }
                              List products = [];
                              for (var item in _cartController
                                  .getUniqueProducts()) {
                                products.add({
                                  'id': item.id,
                                  'quantity': _cartController
                                      .singleProductQuantity(item.id),
                                  'price':
                                  _cartController.getPrice(item.id),
                                  'name': item.name,
                                });
                              }
                              

                                  setState(() {
                                    _isLoading = true;
                                  });
                                  try {
                                    // Check if we are updating an existing purchase
                                    if (_cartController.passedArgument != 'NOT') {
                                      if (_purchaseDestination == 'shop') {
                                        await _commitEditPurchaseShop(products);
                                      } else {
                                        await _commitEditPurchaseStore(products);
                                      }
                                    } else {
                                      await addSale(products);
                                    }
                                   
                                    // clear cart
                                    clearCartData();
                                    // navigate to home
                                    Navigator.pushNamedAndRemoveUntil(
                                        context, '/home', (route) => false);
                                    // show success snackbar
                                    successSnackbar(
                                      _cartController.passedArgument != 'NOT' ? 'purchase_updated'.tr : 'order_created'.tr,
                                    );
                                  } catch (e) {
                                    errorSnackbar(e.toString());
                                  }
                                  setState(() {
                                    _isLoading = false;
                                  });
                                },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ); // end return SingleChildScrollView
      }, // end Obx builder
    ), // end Obx
  ), // end Scaffold
); // end WillPopScope
  }

  void _selectPurchaseDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2015, 8),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> addSale(List<dynamic> products) async {
    final String? businessId = _businessController.business['id'];
    if (businessId == null) {
      errorSnackbar('Business ID is null');
      throw Exception('Business ID is null');
    }

    final newSaleRef = firestore
        .collection('recovered')
        .doc(businessId)
        .collection('userRecovered')
        .doc();

    final saleData = <String, dynamic>{
      'client': "",
      'supplier': _cartController.supplier == null ? "" : _cartController.supplier!.id,
      'supplierName': _cartController.supplier?.name ?? "",
      'employeeId': _profileController.user['id'] ?? "",
      'employeeName': _profileController.user['name'] ?? "",
      'products': products,
      'owner': businessId,
      'price': _cartController.productsPrice,
      'buyingPrice': _cartController.productsBuyingPrice,
      'payment': _cartController.payment,
      'payments': _cartController.payments.map((p) => p.toMap()).toList(),
      'debt': _cartController.remaining,
      'discount': _cartController.discount.value,
      'comment': _cartController.comment,
      'date': selectedDate ?? DateTime.now(),
      'fundSource': _fundSource,
      'fundSourceNote': _fundSource == 'other' ? _fundSourceOtherNote : '',
      'purchaseDestination': _purchaseDestination,
      'id': newSaleRef.id,
    };

    final capturedSupplier = _cartController.supplier;
    final double capturedRemaining = _cartController.remaining;
    final String? capturedComment = _cartController.comment;
    final List<Map<String, dynamic>> capturedDebtProducts = products.map<Map<String, dynamic>>((p) {
      return {
        'id': p['id'],
        'name': p['name'],
        'quantity': p['quantity'],
        'price': p['price'],
      };
    }).toList();

    if (_purchaseDestination == 'shop') {
      await _commitNewPurchaseShop(newSaleRef, saleData, businessId);
    } else {
      final String? storeId = _businessController.business['owner'];
      if (storeId == null) {
        errorSnackbar('Business or Store ID is null');
        throw Exception('Store ID is null');
      }
      await _commitNewPurchaseStore(newSaleRef, saleData, businessId, storeId);
    }

    await _finalizePurchaseSideEffects(
      newSaleRef,
      saleData,
      supplierAtPurchase: capturedSupplier,
      remainingAtPurchase: capturedRemaining,
      commentAtPurchase: capturedComment,
      debtProductsAtPurchase: capturedDebtProducts,
    );
  }

  Timestamp _coerceFirestoreTimestamp(dynamic d) {
    if (d is Timestamp) return d;
    if (d is DateTime) return Timestamp.fromDate(d);
    return Timestamp.now();
  }

  Map<String, dynamic> _buildUpdatedPurchaseFields(List<dynamic> products) {
    return {
      'supplier': _cartController.supplier == null ? "" : _cartController.supplier!.id,
      'supplierName': _cartController.supplier?.name ?? "",
      'products': products,
      'price': _cartController.productsPrice,
      'buyingPrice': _cartController.productsBuyingPrice,
      'payment': _cartController.payment,
      'payments': _cartController.payments.map((p) => p.toMap()).toList(),
      'debt': _cartController.remaining,
      'discount': _cartController.discount.value,
      'comment': _cartController.comment,
      'date': _coerceFirestoreTimestamp(selectedDate ?? DateTime.now()),
      'fundSource': _fundSource,
      'fundSourceNote': _fundSource == 'other' ? _fundSourceOtherNote : '',
      'purchaseDestination': _purchaseDestination,
    };
  }

  Future<void> _commitNewPurchaseShop(
    DocumentReference<Map<String, dynamic>> saleRef,
    Map<String, dynamic> saleData,
    String businessId,
  ) async {
    final unique = _cartController.getUniqueProducts();
    await firestore.runTransaction((fireTx) async {
      final ts = Timestamp.now();
      final reads = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final p in unique) {
        if (p.itemType == 'service') continue;
        final pref = firestore.collection('products').doc(businessId).collection('userProducts').doc(p.id);
        reads.add(await fireTx.get(pref));
      }
      var ri = 0;
      final persistedSale = Map<String, dynamic>.from(saleData);
      persistedSale['id'] = saleRef.id;
      persistedSale['date'] = _coerceFirestoreTimestamp(saleData['date']);
      fireTx.set(saleRef, persistedSale);
      final employeeName = (_profileController.user['name'] ?? '').toString();
      for (final p in unique) {
        if (p.itemType == 'service') continue;
        final snap = reads[ri++];
        if (!snap.exists) {
          throw Exception('Product not found in shop: ${p.name}');
        }
        final cur = (snap.data()?['quantity'] ?? 0.0);
        final curD = cur is num ? cur.toDouble() : 0.0;
        final delta = _cartController.singleProductBaseQuantity(p.id);
        if (delta <= 0) continue;
        final next = curD + delta;
        final rawP = snap.data()?['price'] ?? p.price;
        final pr = rawP is num ? rawP.toDouble() : p.price;
        fireTx.update(snap.reference, {'quantity': next});
        final tRef = firestore.collection('transactions').doc(businessId).collection('usersTransactions').doc();
        fireTx.set(tRef, StockTransaction(
          transactionId: tRef.id,
          productId: p.id,
          quantity: delta,
          previousQuantity: curD,
          newQuantity: next,
          transactionType: TransactionTypes.addition,
          transactionOrigin: TransactionOrigins.purchase,
          timestamp: ts,
          userId: businessId,
          price: pr,
          referenceId: saleRef.id,
          referenceType: TransactionReferenceTypes.purchase,
          employeeName: employeeName,
          notes: TransactionOrigins.purchase,
          totalValue: delta * pr,
        ).toMap());
      }
    });
  }

  Future<void> _commitNewPurchaseStore(
    DocumentReference<Map<String, dynamic>> saleRef,
    Map<String, dynamic> saleData,
    String businessId,
    String storeId,
  ) async {
    final unique = _cartController.getUniqueProducts();
    await firestore.runTransaction((fireTx) async {
      final ts = Timestamp.now();
      final reads = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final p in unique) {
        if (p.itemType == 'service') continue;
        final sref = firestore.collection('store').doc(storeId).collection('userStore').doc(p.id);
        reads.add(await fireTx.get(sref));
      }
      var ri = 0;
      final persistedSale = Map<String, dynamic>.from(saleData);
      persistedSale['id'] = saleRef.id;
      persistedSale['date'] = _coerceFirestoreTimestamp(saleData['date']);
      fireTx.set(saleRef, persistedSale);
      final employeeName = (_profileController.user['name'] ?? '').toString();
      for (final p in unique) {
        if (p.itemType == 'service') continue;
        final snap = reads[ri++];
        final delta = _cartController.singleProductBaseQuantity(p.id);
        if (delta <= 0) continue;
        final sref = firestore.collection('store').doc(storeId).collection('userStore').doc(p.id);
        double prev = 0.0;
        if (snap.exists) {
          final q = snap.data()?['quantity'] ?? 0;
          prev = q is num ? q.toDouble() : 0.0;
          final next = prev + delta;
          fireTx.update(sref, {'quantity': next, 'total': next});
        } else {
          fireTx.set(sref, {
            'id': p.id,
            'storeId': storeId,
            'owner': businessId,
            'businessId': businessId,
            'name': p.name,
            'price': p.price,
            'buyingPrice': p.buyingPrice,
            'quantity': delta,
            'total': delta,
            'category': p.category,
            'image': p.image,
            'storeQuantity': 0,
            'understock': p.understock,
            'code': p.code,
            'details': p.details,
            'manufacturer': p.manufacturer,
            'location': p.location,
            'reserveString1': p.reserveString1,
            'reserveString2': '',
            'reserveDouble1': 0.0,
            'reserveDouble2': 0.0,
            'reserveList1': <String>[],
            'reserveList2': <String>[],
          });
        }
        final tRef = firestore.collection('transactions').doc(businessId).collection('usersTransactions').doc();
        fireTx.set(tRef, StockTransaction(
          transactionId: tRef.id,
          productId: p.id,
          quantity: delta,
          previousQuantity: prev,
          newQuantity: prev + delta,
          transactionType: TransactionTypes.addition,
          transactionOrigin: 'Purchase to Store',
          timestamp: ts,
          userId: businessId,
          price: p.price,
          referenceId: saleRef.id,
          referenceType: TransactionReferenceTypes.purchase,
          employeeName: employeeName,
          notes: 'Purchase to Store',
          totalValue: delta * p.price,
        ).toMap());
      }
    });
  }

  Future<void> _finalizePurchaseSideEffects(
    DocumentReference<Map<String, dynamic>> saleRef,
    Map<String, dynamic> saleData, {
    Supplier? supplierAtPurchase,
    required double remainingAtPurchase,
    String? commentAtPurchase,
    required List<Map<String, dynamic>> debtProductsAtPurchase,
  }) async {
    try {
      final List<dynamic> payments = List<dynamic>.from(saleData['payments'] ?? []);
      final dynamic d = saleData['date'];
      final Timestamp postedAt = d is Timestamp ? d : Timestamp.fromDate(d as DateTime);
      await LedgerService().postPurchaseOut(
        purchaseId: saleRef.id,
        payments: payments,
        postedAt: postedAt,
        supplierId: supplierAtPurchase?.id,
        supplierName: supplierAtPurchase?.name,
      );
    } catch (e) {
      print('⚠️ Ledger postPurchaseOut failed for purchase ${saleRef.id}: $e');
    }

    if (remainingAtPurchase > 0 && supplierAtPurchase != null) {
      await _supplierController.updateDebt(
        supplierAtPurchase,
        supplierAtPurchase.debt + remainingAtPurchase,
      );
      await _supplierDebtController.createSupplierDebt(
        supplierId: supplierAtPurchase.id,
        supplierName: supplierAtPurchase.name,
        debtAmount: remainingAtPurchase,
        comment: (commentAtPurchase == null || commentAtPurchase.isEmpty)
            ? 'Purchase debt from transaction ${saleRef.id}'
            : commentAtPurchase,
        purchaseId: saleRef.id,
        products: debtProductsAtPurchase,
      );
    }
  }

  Future<void> _commitEditPurchaseShop(List<dynamic> products) async {
    if (_originalPurchaseData == null) {
      throw Exception('Original purchase data not loaded; try again in a moment.');
    }
    final String? businessId = _businessController.business['id'];
    if (businessId == null) {
      errorSnackbar('Business ID is null');
      throw Exception('Business ID is null');
    }
    final originalProducts = _originalPurchaseData!['products'] as List<dynamic>;
    final currentProducts = _cartController.getUniqueProducts();
    final purchaseRef = firestore
        .collection('recovered')
        .doc(businessId)
        .collection('userRecovered')
        .doc(_cartController.passedArgument);
    final updatedData = _buildUpdatedPurchaseFields(products);
    final origQty = <String, double>{};
    for (final o in originalProducts) {
      origQty[o['id'] as String] = (o['quantity'] as num).toDouble();
    }
    final ids = <String>{};
    for (final o in originalProducts) {
      ids.add(o['id'] as String);
    }
    for (final c in currentProducts) {
      ids.add(c.id);
    }
    final purchaseId = _cartController.passedArgument;

    await firestore.runTransaction((fireTx) async {
      final ts = Timestamp.now();
      final purchaseSnap = await fireTx.get(purchaseRef);
      if (!purchaseSnap.exists) {
        throw Exception('Purchase record not found.');
      }
      final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in ids) {
        final ref = firestore.collection('products').doc(businessId).collection('userProducts').doc(id);
        snaps[id] = await fireTx.get(ref);
      }
      fireTx.update(purchaseRef, updatedData);
      final employeeName = (_profileController.user['name'] ?? '').toString();

      void writeTxnLine(String productId, double prev, double next, double price, String origin) {
        if ((next - prev).abs() < 1e-12) return;
        final tRef = firestore.collection('transactions').doc(businessId).collection('usersTransactions').doc();
        final isAdd = next >= prev;
        final change = (next - prev).abs();
        fireTx.set(tRef, StockTransaction(
          transactionId: tRef.id,
          productId: productId,
          quantity: change,
          previousQuantity: prev,
          newQuantity: next,
          transactionType: isAdd ? TransactionTypes.addition : TransactionTypes.removal,
          transactionOrigin: origin,
          timestamp: ts,
          userId: businessId,
          price: price,
          referenceId: purchaseId,
          referenceType: TransactionReferenceTypes.purchase,
          employeeName: employeeName,
          notes: origin,
          totalValue: change * price,
        ).toMap());
      }

      for (final c in currentProducts) {
        if (c.itemType == 'service') continue;
        final snap = snaps[c.id];
        if (snap == null || !snap.exists) continue;
        final productMeta = _productController.getProduct(c.id);
        if (productMeta.id == '') continue;
        final q = snap.data()?['quantity'] ?? 0.0;
        final snapQty = q is num ? q.toDouble() : 0.0;
        final orig = origQty[c.id] ?? 0.0;
        final newQty = _cartController.singleProductQuantity(c.id).toDouble();
        final adjusted = snapQty - orig + newQty;
        final finalQty = adjusted < 0 ? 0.0 : adjusted;
        final rawP = snap.data()?['price'] ?? productMeta.price;
        final price = rawP is num ? rawP.toDouble() : productMeta.price;
        fireTx.update(snap.reference, {'quantity': finalQty});
        writeTxnLine(c.id, snapQty, finalQty, price, TransactionOrigins.purchaseEdit);
      }

      for (final o in originalProducts) {
        final id = o['id'] as String;
        if (currentProducts.any((p) => p.id == id)) continue;
        final snap = snaps[id];
        if (snap == null || !snap.exists) continue;
        final productMeta = _productController.getProduct(id);
        if (productMeta.id == '' || productMeta.itemType == 'service') continue;
        final q = snap.data()?['quantity'] ?? 0.0;
        final snapQty = q is num ? q.toDouble() : 0.0;
        final orig = (o['quantity'] as num).toDouble();
        final adjusted = snapQty - orig;
        final finalQty = adjusted < 0 ? 0.0 : adjusted;
        final rawP = snap.data()?['price'] ?? productMeta.price;
        final price = rawP is num ? rawP.toDouble() : productMeta.price;
        fireTx.update(snap.reference, {'quantity': finalQty});
        writeTxnLine(id, snapQty, finalQty, price, TransactionOrigins.purchaseEdit);
      }
    });
  }

  Future<void> _commitEditPurchaseStore(List<dynamic> products) async {
    if (_originalPurchaseData == null) {
      throw Exception('Original purchase data not loaded; try again in a moment.');
    }
    final String? businessId = _businessController.business['id'];
    final String? storeId = _businessController.business['owner'];
    if (businessId == null || storeId == null) {
      errorSnackbar('Business or Store ID is null');
      throw Exception('Business or Store ID is null');
    }
    final originalProducts = _originalPurchaseData!['products'] as List<dynamic>;
    final currentProducts = _cartController.getUniqueProducts();
    final purchaseRef = firestore
        .collection('recovered')
        .doc(businessId)
        .collection('userRecovered')
        .doc(_cartController.passedArgument);
    final updatedData = _buildUpdatedPurchaseFields(products);
    final origQty = <String, double>{};
    for (final o in originalProducts) {
      origQty[o['id'] as String] = (o['quantity'] as num).toDouble();
    }
    final ids = <String>{};
    for (final o in originalProducts) {
      ids.add(o['id'] as String);
    }
    for (final c in currentProducts) {
      ids.add(c.id);
    }
    final purchaseId = _cartController.passedArgument;

    await firestore.runTransaction((fireTx) async {
      final ts = Timestamp.now();
      final purchaseSnap = await fireTx.get(purchaseRef);
      if (!purchaseSnap.exists) {
        throw Exception('Purchase record not found.');
      }
      final snaps = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final id in ids) {
        final ref = firestore.collection('store').doc(storeId).collection('userStore').doc(id);
        snaps[id] = await fireTx.get(ref);
      }
      fireTx.update(purchaseRef, updatedData);
      final employeeName = (_profileController.user['name'] ?? '').toString();

      void writeTxnLine(String productId, double prev, double next, double price, String origin) {
        if ((next - prev).abs() < 1e-12) return;
        final tRef = firestore.collection('transactions').doc(businessId).collection('usersTransactions').doc();
        final isAdd = next >= prev;
        final change = (next - prev).abs();
        fireTx.set(tRef, StockTransaction(
          transactionId: tRef.id,
          productId: productId,
          quantity: change,
          previousQuantity: prev,
          newQuantity: next,
          transactionType: isAdd ? TransactionTypes.addition : TransactionTypes.removal,
          transactionOrigin: origin,
          timestamp: ts,
          userId: businessId,
          price: price,
          referenceId: purchaseId,
          referenceType: TransactionReferenceTypes.purchase,
          employeeName: employeeName,
          notes: origin,
          totalValue: change * price,
        ).toMap());
      }

      for (final c in currentProducts) {
        if (c.itemType == 'service') continue;
        final snap = snaps[c.id];
        if (snap == null) continue;
        final productMeta = _productController.getProduct(c.id);
        if (productMeta.id == '') continue;
        final newQty = _cartController.singleProductQuantity(c.id).toDouble();
        final orig = origQty[c.id] ?? 0.0;
        final sref = firestore.collection('store').doc(storeId).collection('userStore').doc(c.id);

        if (snap.exists) {
          final q = snap.data()?['quantity'] ?? 0.0;
          final curStore = q is num ? q.toDouble() : 0.0;
          final adjusted = curStore - orig + newQty;
          final finalQty = adjusted < 0 ? 0.0 : adjusted;
          final rawP = snap.data()?['price'] ?? productMeta.price;
          final price = rawP is num ? rawP.toDouble() : productMeta.price;
          fireTx.update(sref, {'quantity': finalQty, 'total': finalQty});
          writeTxnLine(c.id, curStore, finalQty, price, TransactionOrigins.purchaseEdit);
        } else if (newQty > 0) {
          fireTx.set(sref, {
            'id': productMeta.id,
            'storeId': storeId,
            'owner': businessId,
            'businessId': businessId,
            'name': productMeta.name,
            'price': productMeta.price,
            'buyingPrice': productMeta.buyingPrice,
            'quantity': newQty,
            'total': newQty,
            'category': productMeta.category,
            'image': productMeta.image,
            'storeQuantity': 0,
            'understock': productMeta.understock,
            'code': productMeta.code,
            'details': productMeta.details,
            'manufacturer': productMeta.manufacturer,
            'location': productMeta.location,
          });
          writeTxnLine(c.id, 0.0, newQty, productMeta.price, TransactionOrigins.purchaseEdit);
        }
      }

      for (final o in originalProducts) {
        final id = o['id'] as String;
        if (currentProducts.any((p) => p.id == id)) continue;
        final snap = snaps[id];
        if (snap == null || !snap.exists) continue;
        final productMeta = _productController.getProduct(id);
        if (productMeta.id == '' || productMeta.itemType == 'service') continue;
        final q = snap.data()?['quantity'] ?? 0.0;
        final curStore = q is num ? q.toDouble() : 0.0;
        final orig = (o['quantity'] as num).toDouble();
        final adjusted = curStore - orig;
        final finalQty = adjusted < 0 ? 0.0 : adjusted;
        final sref = firestore.collection('store').doc(storeId).collection('userStore').doc(id);
        final rawP = snap.data()?['price'] ?? productMeta.price;
        final price = rawP is num ? rawP.toDouble() : productMeta.price;
        fireTx.update(sref, {'quantity': finalQty, 'total': finalQty});
        writeTxnLine(id, curStore, finalQty, price, TransactionOrigins.purchaseEdit);
      }
    });
  }

  void clearCartData() {
    _cartController.clearCart();
    _cartController.clearClient();
    _cartController.clearSupplier();
    _cartController.clearComment();
    _cartController.clearDiscount();
    _cartController.clearPayments();
    _cartController.passedArgument='NOT';
  }
}