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

  @override
  Widget build(BuildContext context) {
    // CRITICAL SECURITY CHECK: Verify user has permission to buy products
    if (!_profileController.hasPermission('buy_products')) {
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
                'You do not have permission to access the product buying cart',
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
                  final bool multiEnabled = (_businessController.business['multiFundEnabled'] ?? false) == true;
                  if (!multiEnabled && _fundSource != 'cash') {
                    setState(() {
                      _fundSource = 'cash';
                    });
                    if (_cartController.payments.length > 0) {
                      final existing = _cartController.payments[0];
                      _cartController.clearPayments();
                      _cartController.addPayment(existing.amount, existing.currency, method: 'cash');
                    }
                  }
                  final String defaultMethod = (!multiEnabled)
                      ? 'cash'
                      : (_fundSource == 'mobile'
                          ? 'mobile'
                          : (_fundSource == 'bank' ? 'bank' : 'cash'));
                  if (_cartController.payments.length == 0 && _cartController.productsPrice > 0) {
                    final double base = _cartController.productsPrice - _cartController.discount.value;
                    final double amount = base < 0 ? 0 : base;
                    _cartController.addPayment(amount, chosenCurrency, method: defaultMethod);
                    _paidController.text = formatCurrencyWithoutSymbol(amount);
                  } else if (_cartController.payments.length == 1 && _cartController.payments[0].method != defaultMethod) {
                    // If the fund source changed, update only the method and preserve amount and currency
                    final existing = _cartController.payments[0];
                    _cartController.clearPayments();
                    _cartController.addPayment(existing.amount, existing.currency, method: defaultMethod);
                  }
                  // Keep the text field synced with the current payment when not focused
                  if (!_paidFocusNode.hasFocus) {
                    final double currentAmt =
                        _cartController.payments.length > 0 ? _cartController.payments[0].amount : 0.0;
                    final String currentText = formatCurrencyWithoutSymbol(currentAmt);
                    if (_paidController.text != currentText) {
                      _paidController.text = currentText;
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
                        DropdownButtonFormField<String>(
                          value: _fundSource,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            labelText: 'Source of Funds',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: Preferences.getTheme() ? mediumGrayColor : borderColor,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'bank', child: Text('Bank')),
                            DropdownMenuItem(value: 'mobile', child: Text('Lipa Namba (Mobile)')),
                            DropdownMenuItem(value: 'other', child: Text('Other Source')),
                          ],
                          onChanged: (val) {
                            if (val == null) return;
                            setState(() {
                              _fundSource = val;
                              if (_fundSource != 'other') _fundSourceOtherNote = '';
                            });
                          },
                        ),
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
                              child: InkWell(
                                onTap: () {
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
                            Container(
                              width: 1,
                              height: 44,
                              color: Preferences.getTheme()
                                  ? mediumGrayColor
                                  : borderColor,
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: () {
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
                              final String method = _fundSource == 'mobile'
                                  ? 'mobile'
                                  : (_fundSource == 'bank' ? 'bank' : 'cash');
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
                                      // Update bought quantities first using original data
                                      updateBoughtQuantity();
                                      // Then update the purchase record
                                      updatePurchase(products);
                                    } else {
                                      await addSale(products);
                                      // Only increase bought quantity for new purchases
                                      if (_purchaseDestination == 'shop') {
                                        await increaseBoughtQuantity();
                                      } else {
                                        await addToStoreQuantity();
                                      }
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
      return;
    }

    final newSaleRef = firestore
        .collection('recovered')
        .doc(businessId)
        .collection('userRecovered')
        .doc(); // Create a DocumentReference with an auto-generated ID

    // Sale data to be added
    final saleData = {
      'client': "", // Purchases don't involve clients, only suppliers
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
      'purchaseDestination': _purchaseDestination, // shop | store
    };

    // Capture values needed for debt creation BEFORE any cart clearing occurs
    final capturedSupplier = _cartController.supplier; // may be null
    final double capturedRemaining = _cartController.remaining;
    final String? capturedComment = _cartController.comment;
    // Build debt products from products list to avoid dependency on controller later
    final List<Map<String, dynamic>> capturedDebtProducts = products.map<Map<String, dynamic>>((p) {
      return {
        'id': p['id'],
        'name': p['name'],
        'quantity': p['quantity'],
        'price': p['price'],
      };
    }).toList();

    // Call functions separately without `then`
    await createSale(
      newSaleRef,
      saleData,
      businessId,
      supplierAtPurchase: capturedSupplier,
      remainingAtPurchase: capturedRemaining,
      commentAtPurchase: capturedComment,
      debtProductsAtPurchase: capturedDebtProducts,
    );
  }

  Future<void> createSale(
    DocumentReference saleRef,
    Map<String, dynamic> saleData,
    String businessId, {
    Supplier? supplierAtPurchase,
    required double remainingAtPurchase,
    String? commentAtPurchase,
    required List<Map<String, dynamic>> debtProductsAtPurchase,
  }) async {
    await saleRef.set(saleData).then((_) async {
      // After the sale is successfully created, update the sale with its ID
      updateSaleId(saleRef);
      // Post purchase OUT ledger rows for each payment (paidAmount only)
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
      
      // Create supplier debt if there's remaining debt and a supplier is selected
      print('[DEBUG] Checking if supplier debt should be created');
      print('[DEBUG] Remaining amount (captured): $remainingAtPurchase');
      print('[DEBUG] Supplier (captured): ${supplierAtPurchase?.name ?? 'null'}');
      
      if (remainingAtPurchase > 0 && supplierAtPurchase != null) {
        print('[DEBUG] Creating supplier debt for ${supplierAtPurchase.name}');
        
        // Update supplier's debt using the SupplierController (similar to client debt)
        _supplierController.updateDebt(
          supplierAtPurchase,
          supplierAtPurchase.debt + remainingAtPurchase,
        );
        print('[DEBUG] Updated supplier debt via SupplierController');
        
        print('[DEBUG] Calling createSupplierDebt with:');
        print('[DEBUG]   - Supplier ID: ${supplierAtPurchase.id}');
        print('[DEBUG]   - Supplier Name: ${supplierAtPurchase.name}');
        print('[DEBUG]   - Debt Amount: $remainingAtPurchase');
        print('[DEBUG]   - Purchase ID: ${saleRef.id}');
        print('[DEBUG]   - Products: ${debtProductsAtPurchase.length} items');
        
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
      } else {
        print('[DEBUG] No supplier debt created - either no remaining amount or no supplier selected');
      }
    }).catchError((error) {
      errorSnackbar('Failed to create sale: $error');
    });
    return;
  }

  void updateSaleId(DocumentReference saleRef) {
    saleRef.update({'id': saleRef.id}).catchError((error) {
      errorSnackbar('Failed to update sale ID: $error');
      print('Failed to update sale ID: $error');
    });
  }
  
  void updatePurchase(List<dynamic> products) {
    final String? businessId = _businessController.business['id'];
    if (businessId == null) {
      errorSnackbar('Business ID is null');
      return;
    }

    final purchaseRef = firestore
        .collection('recovered')
        .doc(businessId)
        .collection('userRecovered')
        .doc(_cartController.passedArgument);

    final updatedData = {
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
      'date': selectedDate ?? DateTime.now(),
      'fundSource': _fundSource,
      'fundSourceNote': _fundSource == 'other' ? _fundSourceOtherNote : '',
    };

    purchaseRef.update(updatedData).then((_) {
      print('Purchase updated successfully');
    }).catchError((error) {
      errorSnackbar('Failed to update purchase: $error');
      print('Failed to update purchase: $error');
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
  


  Future<void>  increaseBoughtQuantity() async {
    // Batch all updates for better offline support
    final updates = <Future>[];
    
    for (var product in _cartController.getUniqueProducts()) {
      // Get the current quantity of the product
      double currentQuantity = product.quantity;

      // Calculate the quantity to reduce
      double boughtQuantity = _cartController.singleProductQuantity(product.id);

      // Determine the new quantity after the sale
      double newQuantity = currentQuantity + boughtQuantity;

      // Make sure that the quantity doesn't go below zero
      newQuantity = newQuantity < 0 ? 0 : newQuantity;

      // Add to batch - don't await yet
      updates.add(_productController.updateProductCount(
        product,
        newQuantity,'New Stock',
      ));
    }
    
    // Wait for all updates together
    await Future.wait(updates);
  }

  Future<void> addToStoreQuantity() async {
    final String? businessId = _businessController.business['id'];
    final String? storeId = _businessController.business['owner']; // Use owner ID as store ID
    
    if (businessId == null || storeId == null) {
      errorSnackbar('Business or Store ID is null');
      return;
    }

    for (var product in _cartController.getUniqueProducts()) {
      // Calculate the quantity purchased
      double purchasedQuantity = _cartController.singleProductQuantity(product.id);
      
      try {
        // Get current store product data
        final storeProductRef = firestore
            .collection('store')
            .doc(storeId)
            .collection('userStore')
            .doc(product.id);
            
        final storeProductDoc = await storeProductRef.get();
        double currentStoreQuantity = 0.0;
        
        if (storeProductDoc.exists) {
          // Update existing store product quantity
          currentStoreQuantity = (storeProductDoc.data()?['quantity'] ?? 0).toDouble();
          final newStoreQuantity = currentStoreQuantity + purchasedQuantity;
          
          await storeProductRef.update({
            'quantity': newStoreQuantity,
            'total': newStoreQuantity,
          });
        } else {
          // Create new store product entry with purchased quantity
          currentStoreQuantity = 0.0; // New product starts with 0
          final productData = {
            'id': product.id,
            'storeId': storeId,
            'owner': businessId,
            'businessId': businessId,
            'name': product.name,
            'price': product.price,
            'buyingPrice': product.buyingPrice,
            'quantity': purchasedQuantity,
            'total': purchasedQuantity,
            'category': product.category,
            'image': product.image,
            'storeQuantity': 0,
            'understock': product.understock,
            'code': product.code,
            'details': product.details,
            'manufacturer': product.manufacturer,
            'location': product.location,
            'reserveString1': product.reserveString1,
            'reserveString2': '',
            'reserveDouble1': 0.0,
            'reserveDouble2': 0.0,
            'reserveList1': [],
            'reserveList2': [],
          };
          
          await storeProductRef.set(productData);
        }
        
        // Create transaction record for store addition
        final transactionRef = firestore
            .collection('transactions')
            .doc(businessId)
            .collection('usersTransactions')
            .doc();

        final transactionData = {
          'transactionId': transactionRef.id,
          'productId': product.id,
          'quantity': purchasedQuantity,
          'previousQuantity': currentStoreQuantity,
          'transactionType': 'addition',
          'transactionOrigin': 'Purchase to Store',
          'timestamp': Timestamp.now(),
          'userId': _profileController.user['id'] ?? businessId,
          'price': product.price ?? 0.0,
        };

        await transactionRef.set(transactionData);
        
      } catch (e) {
        print('Error adding product ${product.id} to store: $e');
        errorSnackbar('Failed to add ${product.name} to store');
      }
    }
  }

  Future<void> updateBoughtQuantity() async {
    if (_originalPurchaseData == null) return;

    final originalProducts = _originalPurchaseData!['products'] as List<dynamic>;
    final currentProducts = _cartController.getUniqueProducts();

    // ✅ Batch all updates for better offline support
    final updates = <Future>[];

    // Create a map of original products for quick lookup
    Map<String, double> originalProductQuantities = {};
    for (var originalProduct in originalProducts) {
      originalProductQuantities[originalProduct['id']] = (originalProduct['quantity'] as num).toDouble();
    }

    // Process all current products in the cart
    for (var currentProduct in currentProducts) {
      final productId = currentProduct.id;
      final newQuantity = _cartController.singleProductQuantity(productId).toDouble();
      final originalQuantity = originalProductQuantities[productId] ?? 0.0; // 0 if new product
      
      final product = _productController.getProduct(productId);
      if (product.id != '') {
        // Calculate: current_quantity - original_quantity + new_quantity
        // This reverses the original purchase and applies the new purchase
        final adjustedQuantity = product.quantity! - originalQuantity + newQuantity;
        updates.add(_productController.updateProductCount(
          product,
          adjustedQuantity,
          'Edit Purchase',
        ));
      }
    }

    // Handle products that were removed from the purchase (in original but not in current)
    for (var originalProduct in originalProducts) {
      final productId = originalProduct['id'];
      final originalQuantity = (originalProduct['quantity'] as num).toDouble();
      
      // Check if this product is still in the current cart
      bool stillInCart = currentProducts.any((p) => p.id == productId);
      
      if (!stillInCart) {
        // Product was removed, so we need to subtract its original quantity
        final product = _productController.getProduct(productId);
        if (product.id != '') {
          final adjustedQuantity = product.quantity! - originalQuantity;
          updates.add(_productController.updateProductCount(
            product,
            adjustedQuantity,
            'Edit Purchase - Removed',
          ));
        }
      }
    }
    
    // ✅ Wait for all updates together
    await Future.wait(updates);
  }
}