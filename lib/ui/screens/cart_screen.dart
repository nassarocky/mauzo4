import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/ui/screens/sale/add_sale_screen.dart';
import 'package:mauzo/ui/screens/sale/edit_sale.screen.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/client_controller.dart';
import '../../controllers/business_controller.dart';
import '../../models/client_model.dart';
import '../../utils/constants.dart';
import '../../utils/preferences.dart';
import '../widgets/bottomsheets/comment_bottom_sheet.dart';
import '../widgets/bottomsheets/discount_bottom_sheet.dart';
import '../widgets/buttons/primary_button.dart';
import '../widgets/dashed_seperator.dart';
import '../widgets/dialogs/add_to_cart_dialog.dart';
import '../widgets/dialogs/double_action_dialog.dart';
import '../../controllers/product_transfer_controller.dart'; // Added import for ProductTransferController
import 'package:mauzo/services/ledger_service.dart';
import 'package:mauzo/services/fund_source_service.dart';
import '../../services/thermal_printer_service.dart';
import '../widgets/printer_selection_dialog.dart';
import '../../models/sale_model.dart';


class CartScreen extends StatefulWidget {
  final UserData? userData; // Optional user data for flexibility
  const CartScreen({Key? key,this.userData}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartController _cartController = Get.find();
  final ClientController _clientController = Get.find();
  final ProfileController _profileController = Get.find();
  final ProductController _productController = Get.find();
  static final BusinessController _businessController = Get.find();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  final FocusNode _paidFocusNode = FocusNode();
  bool _isLoading = false;
  // Payment method selection
  String _paymentMethod = 'cash'; // Payment method state variable
  late final ThermalPrinterService _thermalPrinter;
  // Track manual edits and total changes
  bool _userEditedPaid = false;
  double _lastProductsTotal = 0.0;

  @override
  void initState() {
    super.initState();
    
    // Initialize thermal printer service
    if (!Get.isRegistered<ThermalPrinterService>()) {
      Get.put(ThermalPrinterService());
    }
    _thermalPrinter = Get.find<ThermalPrinterService>();
    
    // Determine the context/purpose of this cart screen
    String from = 'new_sale';
    if (widget.userData != null) {
      from = widget.userData!.name;
    }
    
    // CRITICAL SECURITY CHECK: Context-aware permission verification
    String requiredPermission;
    String contextualMessage;
    
    switch (from) {
      case 'invoice':
        // Check if we're editing an existing invoice or creating a new one
        if (_cartController.editInvoice == 'edit') {
          requiredPermission = 'edit_invoices';
          contextualMessage = 'You do not have permission to edit invoices';
        } else {
          requiredPermission = 'create_invoices';
          contextualMessage = 'You do not have permission to create invoices';
        }
        break;
      case 'transfer':
        requiredPermission = 'transfer_products';
        contextualMessage = 'You do not have permission to transfer products';
        break;
      default:
        requiredPermission = 'make_sales';
        contextualMessage = 'You do not have permission to complete sales transactions';
        break;
    }
    
    if (!_profileController.hasPermission(requiredPermission)) {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: User tried to access CartScreen ($from) without $requiredPermission permission');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          contextualMessage,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }

    // Refresh fund sources so new custom accounts (e.g. "Salary") resolve before checkout.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final bid = _businessController.businessId.value;
        if (bid.isEmpty) return;
        final list = await FundSourceService().loadFundSources(bid);
        _businessController.reloadFundSources(list);
      } catch (_) {}
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

  String chosenCurrency = _businessController.business['mainCurrency'];

  String _cartScreenFrom() {
    if (widget.userData != null) return widget.userData!.name;
    return 'new_sale';
  }

  /// Sync selected fund source into [CartController.payments] before Firestore / ledger.
  void _flushFundSourceIntoPaymentsBeforePersist() {
    if (_cartScreenFrom() == 'transfer') return;
    _cartController.applyFundSourceToAllPayments(_paymentMethod);
    final double currentTotal =
        _cartController.productsPrice - _cartController.discount.value;
    final double calcAmount = currentTotal < 0 ? 0 : currentTotal;
    if (_cartController.payments.isEmpty && calcAmount >= 0.01) {
      _cartController.addPayment(calcAmount, chosenCurrency, method: _paymentMethod);
    }
  }

  @override
  Widget build(BuildContext context) {
    String from = 'new_sale';
    if (widget.userData != null) {
      from = widget.userData!.name; // Use null-safe operator
    }
    String appbartitle=from;
    if(from=='invoice'){
      appbartitle='Save Invoice';
    }
    if(from=='transfer'){
      appbartitle='Transfer Products';
    }
    return WillPopScope(
      onWillPop: () async => _isLoading ? false : true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
          Preferences.getTheme() ? darkGrayColor : primaryUltraLightColor,
          foregroundColor:
          Preferences.getTheme() ? primaryUltraLightColor : textDarkColor,
          title: Text(appbartitle.tr),
          elevation: 0,
          leading: _isLoading
              ? Container()
              : IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: _isLoading || from == 'invoice' || from == 'transfer'
              ? null
              : [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Print & Complete Sale',
              onPressed: () => _printAndSubmitSale(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : Obx(
              () {
                // Ensure a default payment is present so "Paid" appears automatically
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (from != 'invoice' && from != 'transfer') {
                    // Calculate current total
                    final double currentTotal = _cartController.productsPrice - _cartController.discount.value;
                    final double calcAmount = currentTotal < 0 ? 0 : currentTotal;
                    
                    // Check if total changed (product added/removed or discount changed)
                    if ((_lastProductsTotal - currentTotal).abs() > 0.0001) {
                      _lastProductsTotal = currentTotal;
                      // Do not clear "user chose partial pay / debt" when the net total changes — otherwise
                      // the next branch forces payment back to full and debt logic breaks.
                      final double paidMain = _cartController.payment;
                      final bool partialPay =
                          calcAmount >= 0.01 && paidMain + 1e-6 < calcAmount;
                      if (!partialPay) {
                        _userEditedPaid = false;
                      }
                    }
                    
                    // Prefill paid from net due (after discount), not gross productsPrice — services/discounts stay consistent.
                    if (_cartController.payments.length == 0 && calcAmount >= 0.01) {
                      _cartController.addPayment(calcAmount, chosenCurrency, method: _paymentMethod);
                      _paidController.text = formatCurrencyWithoutSymbol(calcAmount);
                    } else if (_cartController.payments.length == 1 && _cartController.payments[0].method != _paymentMethod) {
                      // Update existing payment method while preserving amount and currency
                      final existing = _cartController.payments[0];
                      _cartController.clearPayments();
                      _cartController.addPayment(existing.amount, existing.currency, method: _paymentMethod);
                    }

                    // Keep "Paid" text in sync with the payment model; only auto-change payment amount when
                    // paid exceeds net due (clamp). Never force payment up to full when underpaying (debt).
                    if (!_userEditedPaid && _cartController.payments.length == 1 && !_paidFocusNode.hasFocus) {
                      final existing = _cartController.payments[0];
                      final double diff = existing.amount - calcAmount;
                      if (diff.abs() <= 0.0001) {
                        if (_paidController.text.trim().isEmpty) {
                          _paidController.text =
                              formatCurrencyWithoutSymbol(existing.amount);
                        }
                      } else if (diff > 0.0001) {
                        _cartController.clearPayments();
                        _cartController.addPayment(calcAmount, existing.currency, method: _paymentMethod);
                        _paidController.text = formatCurrencyWithoutSymbol(calcAmount);
                      } else {
                        _paidController.text =
                            formatCurrencyWithoutSymbol(existing.amount);
                      }
                    }
                  }
                });

                return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (from != 'transfer')
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 44,
                                child: TextField(
                                  controller: TextEditingController(
                                    text: _cartController.client?.name ?? '',
                                  ),
                                  onChanged: (value) {
                                    Client updatedClient = Client(
                                      id: _cartController.client?.id ?? '',
                                      owner: _cartController.client?.owner ?? '',
                                      name: value,
                                      phone: _cartController.client?.phone ?? '',
                                      date: _cartController.client?.date ??
                                          Timestamp.now(),
                                      debt: _cartController.client?.debt ?? 0.0,
                                      note: _cartController.client?.note,
                                      image: _cartController.client?.image,
                                    );
                                    _cartController.setClient(updatedClient);
                                  },
                                  decoration: InputDecoration(
                                    contentPadding:
                                        const EdgeInsets.symmetric(horizontal: 10),
                                    hintText: 'Enter client name'.tr,
                                    hintStyle: bodyText(
                                      Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .color,
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
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 44,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/client/select')
                                      .then((value) => setState(() {}));
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                child: const Icon(Icons.keyboard_arrow_right),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Obx(
                          () => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'price_mode_label'.tr,
                                style: bodyText(
                                  Theme.of(context)
                                      .textTheme
                                      .bodyMedium!
                                      .color,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<int>(
                                segments: [
                                  ButtonSegment<int>(
                                    value: 0,
                                    label: Text('retail_price_short'.tr),
                                  ),
                                  ButtonSegment<int>(
                                    value: 1,
                                    label: Text('wholesale_price_short'.tr),
                                    enabled: _cartController
                                        .canEnableWholesalePricing,
                                  ),
                                ],
                                emptySelectionAllowed: false,
                                showSelectedIcon: false,
                                selected: {
                                  _cartController.useWholesalePricing.value
                                      ? 1
                                      : 0,
                                },
                                onSelectionChanged: (Set<int> next) {
                                  final v = next.first;
                                  if (v == 1 &&
                                      !_cartController
                                          .canEnableWholesalePricing) {
                                    return;
                                  }
                                  _cartController.setUseWholesalePricing(v == 1);
                                  setState(() {});
                                },
                              ),
                              if (!_cartController.canEnableWholesalePricing &&
                                  _cartController
                                      .getUniqueProducts()
                                      .isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'wholesale_threshold_hint'.tr,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                        ),
                                      ),
                                      if (_cartController
                                          .wholesalePricingShortfallDescription()
                                          .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _cartController
                                                .wholesalePricingShortfallDescription(),
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

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
                                          AddToCartDialog(
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
                                      () {
                                        final q = _cartController.singleProductQuantity(product.id);
                                        final qs = q == q.roundToDouble()
                                            ? q.toStringAsFixed(q == q.truncateToDouble() ? 0 : 2)
                                            : q.toStringAsFixed(2);
                                        return '${qs}x';
                                      }(),
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
                      if (MediaQuery.of(context).size.width <= 600)
                        if (from != 'transfer')
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
                              if (from=='invoice'){
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddSaleScreen(
                                        userData:
                                        UserData('invoice')), // Use named argument
                                  ),
                                );
                              }else{
                                Navigator.pushNamed(context, '/sale/add');}
                            },
                            child: Text(
                              "add_product".tr,
                              style: bodyText(textMutedColor),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Fund source / payment method (single row; multi-fund only adds split-payment UI elsewhere)
                      if (from != 'transfer')
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Obx(() {
                            final methods = _businessController
                                .paymentMethodsForDropdown(
                                    currentValue: _paymentMethod);
                            if (methods.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final values = methods
                                .map((m) => m['value']?.toString() ?? '')
                                .where((v) => v.isNotEmpty)
                                .toList();
                            if (values.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            final safeValue = values.contains(_paymentMethod)
                                ? _paymentMethod
                                : values.first;
                            if (safeValue != _paymentMethod) {
                              WidgetsBinding.instance
                                  .addPostFrameCallback((_) {
                                if (mounted) {
                                  setState(() => _paymentMethod = safeValue);
                                }
                              });
                            }
                            return DropdownButtonFormField<String>(
                              value: safeValue,
                              decoration: InputDecoration(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                labelText: 'Payment Method',
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
                              items: methods
                                  .map((m) {
                                    final v = m['value']?.toString() ?? '';
                                    if (v.isEmpty) return null;
                                    return DropdownMenuItem<String>(
                                      value: v,
                                      child: Text(
                                        m['label']?.toString() ?? v,
                                      ),
                                    );
                                  })
                                  .whereType<DropdownMenuItem<String>>()
                                  .toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() => _paymentMethod = val);
                                if (_cartScreenFrom() != 'transfer') {
                                  _cartController.applyFundSourceToAllPayments(val);
                                }
                              },
                            );
                          }),
                        ),
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
                      const SizedBox(height: 12),
                      const DashedSeperator(width: 2),
                      _cartController.discount > 0
                          ? Column(
                        children: [
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${'discounted_price'.tr}:',
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
                                    _cartController
                                        .productsPrice -
                                        _cartController
                                            .discount.value,
                                    chosenCurrency)
                                    : formatCurrency(
                                    (_cartController
                                        .productsPrice -
                                        _cartController
                                            .discount
                                            .value) /
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
                      )
                          : Container(),
                      const SizedBox(height: 12),
                      if (from != 'transfer')
                      SizedBox(
                        height: 36,
                        child: Container(
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
                              showModalBottomSheet(
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                                context: context,
                                builder: (BuildContext context) {
                                  return DiscountBottomSheet(
                                    chosenCurrency: chosenCurrency,
                                    defaultMethod: _paymentMethod,
                                  );
                                },
                              );
                            },
                            child: Text(
                              _cartController.discount > 0
                                  ? '${'discount'.tr}: ${chosenCurrency == _businessController.business['mainCurrency'] ? formatCurrency(_cartController.discount.value, chosenCurrency) : formatCurrency(_cartController.discount.value / Preferences.getExchangeRateResult(), chosenCurrency)}'
                                  : "add_discount".tr,
                              style: bodyText(textMutedColor),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                if (from != 'transfer')
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
                                _cartController.addPayment(amt, chosenCurrency, method: _paymentMethod);
                              } else {
                                final existing = _cartController.payments[0];
                                _cartController.clearPayments();
                                _cartController.addPayment(amt, existing.currency, method: _paymentMethod);
                              }
                            },
                            decoration: InputDecoration(
                              contentPadding: inputPadding,
                              labelText: (from=='invoice') ? 'not paid'.tr : 'paid'.tr,
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
                        if (from!='invoice') const SizedBox(height: 8),
                        if (from!='invoice') Text(
                          '${'remaining'.tr}: ${chosenCurrency == _businessController.business['mainCurrency'] ? formatCurrency(_cartController.remaining, chosenCurrency) : formatCurrency(_cartController.remaining / Preferences.getExchangeRateResult(), chosenCurrency)}',
                          style: bodyText(
                            _cartController.remaining > 0 ? warningColor : textPlaceholderColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                if (from != 'transfer')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _detailsController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        labelText:_cartController.comment != '' ? _cartController.comment : 'add_comment'.tr,
                        labelStyle: bodyText(textPlaceholderColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Preferences.getTheme()
                                ? mediumGrayColor
                                : borderColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (from != 'transfer')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: PrimaryButton(
                            color: greenColor,
                            onPressed: () async {
                              // Skip debt validation for invoices - invoices can have debt
                              if (_cartController.remaining > 0 && from != 'invoice') {
                                // Check if the client is unnamed or not set
                                if (_cartController.client == null || _cartController.client == "unnamed_client" || _cartController.client?.id == null || _cartController.client?.id == '') {
                                  // Show error snackbar for 6 seconds if the client name is not set
                                  Get.snackbar(
                                    'Error',
                                    'name_debt'.tr,
                                    duration: Duration(seconds: 6),
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  Navigator.pushNamed(context, '/client/select')
                                      .then(
                                        (value) => setState(() {}),
                                  );

                                  return; // Stop the function from proceeding
                                }

                                // Check if the comment is missing
                                if (_detailsController.text.isEmpty) {
                                  // Show error snackbar for 6 seconds if the comment is not added
                                  Get.snackbar(
                                    'Error',
                                    'debt_info'.tr,
                                    duration: Duration(seconds: 6),
                                    snackPosition: SnackPosition.TOP,
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
                              print('🛒 Building products array for sale');
                              for (var item in _cartController.getUniqueProducts()) {
                                final buyingPrice = _cartController.getBuyingPrice(item.id).toDouble();
                                final lineQty = _cartController.singleProductQuantity(item.id);
                                print('  📦 ${item.name}: buyingPrice=$buyingPrice, price=${_cartController.getPrice(item.id)}');
                                products.add({
                                  'id': item.id,
                                  'quantity': lineQty,
                                  'baseQuantity': lineQty,
                                  'price': (_cartController.getPrice(item.id).toDouble()),
                                  'buyingPrice': buyingPrice,
                                  'name': item.name,
                                  'itemType': item.itemType, // <-- Ensure itemType is included
                                });
                              }
                              print('📋 Products array built with ${products.length} items');

                              if(from=='invoice'){
                                /*
                                if (_cartController.client == null || _cartController.client == "unnamed_client") {
                                  // Show error snackbar for 6 seconds if the client name is not set
                                  Get.snackbar(
                                    'Error',
                                    'Weka jina la Mteja kuhifadhi invoice',
                                    duration: Duration(seconds: 6),
                                    snackPosition: SnackPosition.BOTTOM,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  return; // Stop the function from proceeding
                                }*/
                                if(_cartController.editInvoice=='edit'){
                                  updateInvoice(_cartController.passedArgument,products);
                                } else{
                                  addInvoice(products);}

                              } else {

                                if (_cartController.remaining > 0) {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return DoubleActionDialog(
                                        title: 'unpaid_amount'.tr,
                                        content: 'unpaid_amount_description'.tr,
                                        confirm: 'debt'.tr,
                                        cancel: 'cancel'.tr,
                                        onConfirm: () {
                                          setState(() {
                                            _isLoading = true;
                                          });
                                          try {
                                            successSnackbar('order_created'.tr);
                                            addSale(products);
                                            decreaseSoldQuantity();

                                            if (_cartController.client != null) {
                                              _clientController.updateDebt(
                                                _cartController.client!,
                                                _cartController.remaining + _cartController.client!.debt,
                                              );
                                            }
                                            if (_cartController.client != null && _cartController.client!.advance > 0) {
                                              double payment = _cartController.payment;

                                              // Ensure the advance value never goes negative
                                              if (payment > _cartController.client!.advance) {
                                                payment = _cartController.client!.advance; // Set payment to the advance value
                                              }

                                              _clientController.reduceAdvance(
                                                _cartController.client!,
                                                payment, // Pass the adjusted payment value
                                              );
                                            }
                                            if(_cartController.passedArgument != 'NOT'){
                                              updateInvoiceFromInvoice(_cartController.passedArgument);
                                            }



                                            Navigator.pushNamedAndRemoveUntil(
                                              context,
                                              '/home',
                                                  (route) => false,
                                            );



                                            clearCartData();


                                          } catch (e) {
                                            errorSnackbar(e.toString());
                                          } finally {
                                            setState(() {
                                              _isLoading = false;
                                            });
                                          }
                                        },
                                        onCancel: () {
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  );
                                }

                                else if (_cartController.remaining < 0) {
                                  if (chosenCurrency ==
                                      _businessController
                                          .business['mainCurrency']) {
                                    errorSnackbar(
                                      "${'overpaid'.tr}: ${formatCurrency(
                                        -_cartController.remaining,
                                        chosenCurrency,
                                      )}",
                                    );
                                  } else {
                                    errorSnackbar(
                                      "${'overpaid'.tr}: ${formatCurrency(
                                        -_cartController.remaining /
                                            Preferences
                                                .getExchangeRateResult(),
                                        chosenCurrency,
                                      )}",
                                    );
                                  }
                                } else {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  try {
                                    // create order
                                    addSale(products);
                                    // Decrease sold quantity
                                    decreaseSoldQuantity();

                                    if (_cartController.client != null && _cartController.client!.advance > 0) {
                                      double payment = _cartController.payment;

                                      // Ensure the advance value never goes negative
                                      if (payment > _cartController.client!.advance) {
                                        payment = _cartController.client!.advance; // Set payment to the advance value
                                      }

                                      _clientController.reduceAdvance(
                                        _cartController.client!,
                                        payment, // Pass the adjusted payment value
                                      );
                                    }
                                    if(_cartController.passedArgument != 'NOT'){
                                      updateInvoiceFromInvoice(_cartController.passedArgument);
                                    }
                                    // clear cart
                                    clearCartData();
                                    // navigate to home
                                    Navigator.pushNamedAndRemoveUntil(
                                        context, '/home', (route) => false);
                                    // show success snackbar
                                    successSnackbar(
                                      'order_created'.tr,
                                    );
                                  } catch (e) {
                                    errorSnackbar(e.toString());
                                  }
                                  setState(() {
                                    _isLoading = false;
                                  });
                                }
                              }


                            },
                            text: 'confirm'.tr,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Add Transfer Products button
                if (from == 'transfer') // Only show if not in transfer
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        color: Colors.orange,
                        text: 'Transfer Products',
                        onPressed: () async {
                          // print('[DEBUG] Transfer Products button pressed, transferMode=$transferMode');
                          // 1. Select target business
                          final businesses = _profileController.user['business'] as List<dynamic>? ?? [];
                          final currentBusinessId = _businessController.businessId.value;
                          final otherBusinessIds = businesses.where((id) => id != currentBusinessId).toList();
                          if (otherBusinessIds.isEmpty) {
                            Get.snackbar('No Businesses', 'No other businesses available for transfer.');
                            return;
                          }
                          // Fetch business names for dropdown
                          List<Map<String, String>> businessOptions = [];
                          for (var id in otherBusinessIds) {
                            var doc = await FirebaseFirestore.instance.collection('businesses').doc(id).get();
                            if (doc.exists) {
                              final data = doc.data() as Map<String, dynamic>;
                              businessOptions.add({'id': id, 'name': data['name'] ?? id});
                            }
                          }
                          String? selectedBusinessId = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              String? dropdownValue = businessOptions.first['id'];
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return AlertDialog(
                                    title: Text('select_target_business'.tr),
                                    content: DropdownButton<String>(
                                      value: dropdownValue,
                                      isExpanded: true,
                                      items: businessOptions.map((option) {
                                        return DropdownMenuItem<String>(
                                          value: option['id'],
                                          child: Text(option['name'] ?? option['id']!),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          dropdownValue = value;
                                        });
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, null),
                                        child: Text('cancel'.tr),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, dropdownValue),
                                        child: Text('next'.tr),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                          if (selectedBusinessId == null || selectedBusinessId.isEmpty) return;
                          // 2. Gather products and services from cart
                          List<Map<String, dynamic>> itemsToTransfer = [];
                          for (var item in _cartController.getUniqueProducts()) {
                            final quantity = item.itemType == 'service'
                                ? _cartController.singleProductQuantity(item.id)
                                : _cartController.singleProductBaseQuantity(item.id);
                            final name = (item.name != null && item.name.isNotEmpty) ? item.name : 'Unknown Item';
                            final itemType = (item.itemType != null && item.itemType.isNotEmpty) ? item.itemType : 'product';
                            if (quantity > 0) {
                              itemsToTransfer.add({
                                'id': item.id,
                                'name': name,
                                'quantity': quantity,
                                'itemType': itemType, // 'product' or 'service'
                              });
                            }
                          }
                          print('DEBUG: itemsToTransfer = ' + itemsToTransfer.toString());
                          if (itemsToTransfer.isEmpty) {
                            errorSnackbar('No products or services selected for transfer.');
                            return;
                          }
                          // 3. Create transfer request (pending)
                          final transferController = Get.find<ProductTransferController>();
                          await transferController.createBatchTransferRequest(
                            fromBusinessId: currentBusinessId,
                            toBusinessId: selectedBusinessId,
                            requestedByUserId: _profileController.user['id'],
                            products: itemsToTransfer,
                          );
                          Get.snackbar('Transfer Requested', 'Product/service transfer request sent.');
                          // Optionally clear cart
                          clearCartData();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
  }
  void addSale(List<dynamic> products) {
    final String? businessId = _businessController.business['id'];
    if (businessId == null) {
      errorSnackbar('Business ID is null');
      return;
    }

    _flushFundSourceIntoPaymentsBeforePersist();

    final newSaleRef = firestore
        .collection('sales')
        .doc(businessId)
        .collection('userSales')
        .doc(); // Create a DocumentReference with an auto-generated ID

    // Sale data to be added
    final saleData = {
      'client': _cartController.client == null ? "" : _cartController.client!.id,
      'clientname': _cartController.client?.name ?? "Unnamed Client",
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
      'comment': _detailsController.text.trim(),
      'date': DateTime.now(),
      'wholesalePricingAudit':
          _cartController.buildWholesalePricingAuditMap(),
    };

    print('💾 Saving sale with buyingPrice: ${saleData['buyingPrice']}');
    print('📦 Products count: ${products.length}');
    for (var p in products) {
      print('   - ${p['name']}: buyingPrice=${p['buyingPrice']}, qty=${p['quantity']}');
    }

    // Call functions separately without `then`
    createSale(newSaleRef, saleData, businessId);
  }

  void createSale(DocumentReference saleRef, Map<String, dynamic> saleData, String businessId) {
    saleRef.set(saleData).then((_) async {
      // After the sale is successfully created, update the sale with its ID
      updateSaleId(saleRef);
      // Post sale IN ledger rows for each payment (paidAmount only)
      try {
        final List<dynamic> payments = List<dynamic>.from(saleData['payments'] ?? []);
        final dynamic d = saleData['date'];
        final Timestamp postedAt = d is Timestamp ? d : Timestamp.fromDate(d as DateTime);
        await LedgerService().postSaleIn(
          saleId: saleRef.id,
          payments: payments,
          postedAt: postedAt,
          clientId: _cartController.client?.id,
          clientName: _cartController.client?.name,
        );
      } catch (e) {
        print('⚠️ Ledger postSaleIn failed for sale ${saleRef.id}: $e');
      }
    }).catchError((error) {
      errorSnackbar('Failed to create sale: $error');
    });

    // If debt exists, handle debt history
    if (_cartController.remaining > 0) {
      createDebtHistory(saleRef.id, businessId);
    }
  }

  void updateSaleId(DocumentReference saleRef) {
    saleRef.update({'id': saleRef.id}).catchError((error) {
      errorSnackbar('Failed to update sale ID: $error');
      print('Failed to update sale ID: $error');
    });
  }

  void createDebtHistory(String saleId, String businessId) {
    final debtHistoryRef = firestore
        .collection('debtHistory')
        .doc(businessId)
        .collection('clientDebtHistory')
        .doc(saleId); // Use the sale ID as the debtHistory ID

    final debtHistoryData = {
      'id': saleId,
      'client': _cartController.client == null ? "" : _cartController.client!.id,
      'name': _cartController.client == null ? "" : _cartController.client!.name,
      'owner': businessId,
      'saleId': saleId, // Same as sale ID
      'initialDebtAmount': _cartController.remaining, // Initial debt is the remaining amount
      'remainingDebtAmount': _cartController.remaining, // Same as initial since no payment made yet
      'paymentRecords': [], // No payments yet
      'dateIncurred': Timestamp.now(),
      'status': 'PENDING', // Initial status is 'pending'
      'comment': _detailsController.text.trim(),// Add any comment from the cart
    };

    debtHistoryRef.set(debtHistoryData).catchError((error) {
      errorSnackbar('Failed to record debt history: $error');
      return;
    });

    successSnackbar('Debt history recorded');

  }

  void clearCartData() {
    _cartController.clearCart();
    _cartController.clearClient();
    _cartController.clearComment();
    _detailsController.clear();
    _cartController.clearDiscount();
    _cartController.clearPayments();
    _paidController.clear();
    _userEditedPaid = false;
    _lastProductsTotal = 0.0;
    _cartController.passedArgument=='NOT';
    _cartController.editInvoice='NOT';
  }



  void addInvoice(List<dynamic> products) {
    _flushFundSourceIntoPaymentsBeforePersist();

    final newInvoiceRef = firestore
        .collection('invoices')
        .doc(_businessController.business['id'])
        .collection('userInvoices')
        .doc(); // Create a DocumentReference with an auto-generated ID

    newInvoiceRef.set({
      'client': _cartController.client == null ? "" : _cartController.client!.id,
      'clientname': _cartController.client?.name ?? "Unnamed Client",
      'products': products,
      'owner': _businessController.business['id'],
      'price': _cartController.productsPrice,
      'payment': _cartController.payment,
      'payments': _cartController.payments.map((p) => p.toMap()).toList(),
      'debt': _cartController.remaining,
      'discount': _cartController.discount.value,
      'comment': _cartController.comment,
      'date': DateTime.now(),
      'wholesalePricingAudit':
          _cartController.buildWholesalePricingAuditMap(),
    }).then((_) {
      // After successfully adding the document, update it with its ID
      newInvoiceRef.update({'id': newInvoiceRef.id});
      successSnackbar('Invoice created successfully');
      clearCartData();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/invoices',
            (route) => route.isFirst,  // Removes all but the first route in the stack
      );
    }).catchError((error) {
      errorSnackbar('Failed to create invoice: $error');
      clearCartData();
    });
  }

  void updateInvoiceFromInvoice(String invoiceId) {
    firestore
        .collection('invoices')
        .doc(_businessController.business['id'])
        .collection('userInvoices')
        .doc(invoiceId) // Use the passed invoiceId to update the specific document
        .update({
      'frominvoice': true,
    }).then((_) {
      successSnackbar('Invoice updated successfully');
    }).catchError((error) {
      errorSnackbar('Failed to update invoice: $error');
    });
  }

  void updateInvoice(String invoiceId, List<dynamic> products) {
    _flushFundSourceIntoPaymentsBeforePersist();

    firestore
        .collection('invoices')
        .doc(_businessController.business['id'])
        .collection('userInvoices')
        .doc(invoiceId) // Use the passed invoiceId to update the specific document
        .update({
      'client': _cartController.client == null ? "" : _cartController.client!.id,
      'products': products,
      'owner': _businessController.business['id'],
      'price': _cartController.productsPrice,
      'payment': _cartController.payment,
      'payments': _cartController.payments.map((p) => p.toMap()).toList(),
      'debt': _cartController.remaining,
      'discount': _cartController.discount.value,
      'comment':_detailsController.text.trim(),
      'date': DateTime.now(),
      'wholesalePricingAudit':
          _cartController.buildWholesalePricingAuditMap(),
    }).then((_) {
      successSnackbar('Invoice updated successfully');
      clearCartData();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/invoices',
            (route) => route.isFirst,  // Removes all but the first route in the stack
      );
    }).catchError((error) {
      errorSnackbar('Failed to update invoice: $error');
    });
  }

  Future<void> decreaseSoldQuantity() async {
    // Collect all updates first, then execute (better offline support)
    final updates = <Future>[];
    
    for (var product in _cartController.getUniqueProducts()) {
      // Skip stock reduction for services
      if (product.itemType == 'service') continue;

      double currentQuantity = product.quantity;
      double soldQuantity = _cartController.singleProductBaseQuantity(product.id);
      double newQuantity = currentQuantity - soldQuantity;
      newQuantity = newQuantity < 0 ? 0 : newQuantity;

      // Add to batch - don't await yet
      updates.add(_productController.updateProductCount(
        product,
        newQuantity,
        'Sale',
      ));
    }
    
    // Wait for all updates together (works great offline!)
    await Future.wait(updates);
  }

  Future<void> _printAndSubmitSale() async {
    // Validation checks
    if (_cartController.products.isEmpty) {
      errorSnackbar('no_products_in_cart'.tr);
      return;
    }

    if (_cartController.remaining < 0) {
      final chosenCurrency = _businessController.business['mainCurrency'];
      errorSnackbar(
        "${'overpaid'.tr}: ${formatCurrency(
          -_cartController.remaining,
          chosenCurrency,
        )}",
      );
      return;
    }

    _flushFundSourceIntoPaymentsBeforePersist();

    // On Windows desktop, skip Bluetooth selection and use system print dialog
    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    if (!isWindows && _thermalPrinter.selectedPrinter.value == null) {
      // Show printer selection dialog (Android only)
      await showDialog(
        context: context,
        builder: (context) => const PrinterSelectionDialog(),
      );
      // If still no printer selected, return
      if (_thermalPrinter.selectedPrinter.value == null) {
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Prepare products
      List products = [];
      print('🖨️ [printAndSave] Building products array');
      for (var item in _cartController.getUniqueProducts()) {
        final buyingPrice = _cartController.getBuyingPrice(item.id).toDouble();
        final lineQty = _cartController.singleProductQuantity(item.id);
        print('  📦 ${item.name}: buyingPrice=$buyingPrice');
        products.add({
          'id': item.id,
          'quantity': lineQty,
          'baseQuantity': lineQty,
          'price': (_cartController.getPrice(item.id).toDouble()),
          'buyingPrice': buyingPrice,
          'name': item.name,
          'itemType': item.itemType,
        });
      }
      print('💾 [printAndSave] Total buyingPrice for sale: ${_cartController.productsBuyingPrice}');

      // Build Sale object for printing (before saving to get data)
      final saleForPrint = Sale(
        id: '',
        client: _cartController.client?.id ?? '',
        clientname: _cartController.client?.name ?? "Walk-in Customer",
        employeeId: _profileController.user['id'] ?? "",
        employeeName: _profileController.user['name'] ?? "",
        owner: _businessController.business['id'] ?? '',
        frominvoice: false,
        date: Timestamp.now(),
        products: products,
        price: _cartController.productsPrice,
        buyingPrice: _cartController.productsBuyingPrice,
        payment: _cartController.payment,
        debt: _cartController.remaining,
        discount: _cartController.discount.value,
        comment: _detailsController.text.trim(),
        payments: List<Map<String, dynamic>>.from(
          _cartController.payments.map((p) => p.toMap())
        ),
        wholesalePricingAudit: _cartController.buildWholesalePricingAuditMap(),
      );

      // Print receipt FIRST (while we have all the data)
      await _thermalPrinter.printReceipt(
        sale: saleForPrint,
        client: _cartController.client ?? Client(
          id: '',
          name: saleForPrint.clientname,
          phone: '',
          owner: '',
          debt: 0,
          advance: 0,
          date: Timestamp.now(),
        ),
        business: _businessController.business,
      );

      // Then save the sale
      addSale(products);
      await decreaseSoldQuantity();

      // Handle unpaid amount
      if (_cartController.remaining > 0) {
        if (_cartController.client != null) {
          _clientController.updateDebt(
            _cartController.client!,
            _cartController.remaining + _cartController.client!.debt,
          );
        }
      }

      // Handle advance payment
      if (_cartController.client != null && _cartController.client!.advance > 0) {
        double payment = _cartController.payment;
        if (payment > _cartController.client!.advance) {
          payment = _cartController.client!.advance;
        }
        _clientController.reduceAdvance(_cartController.client!, payment);
      }

      if (_cartController.passedArgument != 'NOT') {
        updateInvoiceFromInvoice(_cartController.passedArgument);
      }

      // Clear cart and navigate
      clearCartData();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
      successSnackbar('order_created'.tr);
    } catch (e) {
      errorSnackbar('Failed to complete sale: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


}