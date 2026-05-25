import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/ui/screens/sale/add_sale_screen.dart';
import 'package:mauzo/ui/widgets/dashed_seperator.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../models/sale_model.dart';
import '../../../utils/constants.dart';
import '../../../utils/sale_line_quantity.dart';
import '../../../utils/preferences.dart';
import '../../widgets/bottomsheets/comment_bottom_sheet.dart';
import '../../widgets/bottomsheets/discount_bottom_sheet.dart';
import '../../widgets/bottomsheets/payment_bottom_sheet.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/dialogs/add_to_cart_dialog.dart';



class EditSaleScreen extends StatefulWidget {
  final String title;
  final Sale sale;

  const EditSaleScreen({Key? key, required this.title, required this.sale})
      : super(key: key);

  @override
  State<EditSaleScreen> createState() => _EditSaleScreenState();
}

class UserData {
  final String name;

  UserData(this.name);
}

class _EditSaleScreenState extends State<EditSaleScreen> {
  final CartController _cartController = Get.find();
  final ProductController _productController = Get.find();
  final ClientController _clientController = Get.put(ClientController());
  static final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  String chosenCurrency = _businessController.business['mainCurrency'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // CRITICAL SECURITY CHECK: Verify user has permission to edit sales
    if (!_profileController.hasPermission('edit_sales')) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to edit sales',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return !_isLoading;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: h5(whiteColor),
          ),
          elevation: 0,
          actions: [
            hasSecondaryCurrency()
                ? PopupMenuButton(
              child: Row(
                children: [
                  Text(
                    chosenCurrency,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              onSelected: (String value) {
                setState(() {
                  chosenCurrency = value;
                });
              },
              itemBuilder: (BuildContext context) =>
              <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: _businessController.business['mainCurrency'],
                  child: Text(
                    _businessController.business['mainCurrency'],
                    style: bodyText(
                        Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                ),
                PopupMenuItem<String>(
                  value: _businessController.business['secondaryCurrency'],
                  child: Text(
                    _businessController.business['secondaryCurrency'],
                    style: bodyText(
                        Theme.of(context).textTheme.bodyLarge!.color),
                  ),
                ),
              ],
            )
                : Container(),
          ],
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
              () => SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hasSecondaryCurrency()
                    ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 7),
                  alignment: Alignment.centerLeft,
                  color: const Color(0xFFFFF2CC),
                  child: Text(
                    "1 ${_businessController.business['secondaryCurrency']}  = ${formatCurrency(Preferences.getExchangeRateResult(), _businessController.business['mainCurrency'])}",
                    style: bodyText(warningColor),
                  ),
                )
                    : Container(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      onTap: () {
                        Navigator.pushNamed(context, '/client/select')
                            .then(
                              (value) => setState(() {}),
                        );
                      },
                      readOnly: true,
                      decoration: InputDecoration(
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        hintText: _cartController.client?.name ??
                            'unnamed_client'.tr,
                        hintStyle: bodyText(Theme.of(context)
                            .textTheme
                            .bodyLarge!
                            .color),
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
                        suffixIcon: const Icon(Icons.keyboard_arrow_right),
                      ),
                    ),
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
                                                .color),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        formatCurrency(
                                          _cartController
                                              .getPrice(product.id),
                                          _businessController
                                              .business['mainCurrency'],
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF999999),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      hasSecondaryCurrency()
                                          ? Text(
                                        formatCurrency(
                                          _cartController.getPrice(
                                              product.id) /
                                              Preferences
                                                  .getExchangeRateResult(),
                                          _businessController.business[
                                          'secondaryCurrency'],
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF999999),
                                          fontSize: 14,
                                        ),
                                      )
                                          : Container(),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
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
                                                product.id),
                                          ),
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 6, horizontal: 8),
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddSaleScreen(
                                    userData:
                                    UserData('editscreen')), // Use named argument
                              ),
                            );
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
                                    .color),
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
                                    .color),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const DashedSeperator(width: 2),
                      _cartController.discount.value.abs() > 0.01
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
                                '${_cartController.netSaleSummaryLabelKey.tr}:',
                                style: bodyText(
                                    Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color),
                              ),
                              Text(
                                chosenCurrency ==
                                    _businessController.business[
                                    'mainCurrency']
                                    ? formatCurrency(
                                    _cartController
                                        .productsPrice -
                                        _cartController
                                            .discount.value,
                                    chosenCurrency)
                                    : formatCurrency(
                                    (_cartController.productsPrice -
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
                                        .color),
                              ),
                            ],
                          ),
                        ],
                      )
                          : Container(),
                      const SizedBox(height: 12),
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
                _cartController.payment > 0
                    ? GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      isScrollControlled: true,
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                      builder: (BuildContext context) {
                        return PaymentBottomSheet(
                          chosenCurrency: chosenCurrency,
                        );
                      },
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Preferences.getTheme()
                          ? mediumGrayColor
                          : primaryUltraLightColor,
                      border: Border.all(
                        color: Preferences.getTheme()
                            ? mediumGrayColor
                            : primaryColor,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 20),
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${'paid'.tr}: ${chosenCurrency == _businessController.business['mainCurrency'] ? formatCurrency(_cartController.payment, chosenCurrency) : formatCurrency(_cartController.payment / Preferences.getExchangeRateResult(), chosenCurrency)}',
                          style: bodyText(
                            Preferences.getTheme()
                                ? primaryLightColor
                                : primaryColor,
                          ),
                        ),
                        Text(
                          "${'remaining'.tr}: ${chosenCurrency == _businessController.business['mainCurrency'] ? formatCurrency(_cartController.remaining, chosenCurrency) : formatCurrency(_cartController.remaining / Preferences.getExchangeRateResult(), chosenCurrency)}",
                          style: bodyText(
                            _cartController.remaining > 0
                                ? warningColor
                                : textPlaceholderColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    : Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 44,
                    child: TextField(
                      onTap: () {
                        showModalBottomSheet(
                          isScrollControlled: true,
                          context: context,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                          builder: (BuildContext context) {
                            return PaymentBottomSheet(
                              chosenCurrency: chosenCurrency,
                            );
                          },
                        );
                      },
                      readOnly: true,
                      decoration: InputDecoration(
                        contentPadding: inputPadding,
                        hintText: _cartController.payment > 0
                            ? "${formatCurrency(_cartController.payment, chosenCurrency)} paid"
                            : 'add_payment'.tr,
                        hintStyle: TextStyle(
                          color: Preferences.getTheme()
                              ? primaryLightColor
                              : primaryColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Preferences.getTheme()
                                ? mediumGrayColor
                                : primaryColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
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
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: PrimaryButton(
                          color: greenColor,
                          onPressed: () async {
                            Navigator.pushNamed(context, '/cart');
                          },
                          text: 'confirm_received_payment'.tr,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> addSale(List<dynamic> products) async {
    final String? ownerId = _businessController.business['id'];

    if (ownerId == null) {
      print('Owner ID is null, cannot add sale.');
      return;
    }

    await firestore
        .collection('sales')
        .doc(ownerId)
        .collection('businessSales')
        .add({
      'client': _cartController.client == null ? "" : _cartController.client!.id,
      'products': products,
      'owner': ownerId,
      'price': _cartController.productsPrice,
      'payment': _cartController.payment,
      'debt': _cartController.remaining,
      'discount': _cartController.discount.value,
      'comment': _cartController.comment,
      'date': DateTime.now(),
    }).then((_) {
      // Call updateSoldQuantity after adding the sale
      updateSoldQuantity();
    });
  }

  Future<void> updateInvoice(List<dynamic> products) async {
    final String? ownerId = _businessController.business['id'];

    if (ownerId == null) {
      print('Owner ID is null, cannot update invoice.');
      return;
    }

    await firestore
        .collection('invoices')
        .doc(ownerId)
        .collection('businessInvoices')
        .doc(widget.sale.id)
        .update({
      'client': _cartController.client == null ? '' : _cartController.client!.id,
      'products': products,
      'owner': ownerId,
      'price': _cartController.productsPrice,
      'payment': _cartController.payment,
      'debt': _cartController.remaining,
      'discount': _cartController.discount.value,
      'comment': _cartController.comment,
      'date': widget.sale.date,
    });
  }

  Future<void> updateInvoiceStatus() async {
    final String? ownerId = _businessController.business['id'];

    if (ownerId == null) {
      print('Owner ID is null, cannot update invoice status.');
      return;
    }

    await firestore
        .collection('invoices')
        .doc(ownerId)
        .collection('businessInvoices')
        .doc(widget.sale.id)
        .update({
      'frominvoice': true,
    });
  }

  Future<void> updateSoldQuantity() async {
    // Batch all updates for better offline support
    final updates = <Future>[];
    
    for (var product in widget.sale.products) {
      final m = Map<String, dynamic>.from(product as Map);
      final pid = m['id']?.toString() ?? '';
      final origBase = saleLineBaseQuantity(m);
      final cartBase = _cartController.singleProductBaseQuantity(pid);
      updates.add(_productController.updateProductCount(
          _productController.getProduct(pid),
          _productController.getProduct(pid).quantity! -
              cartBase +
              origBase,
          'Edit'));
    }
    
    // Wait for all updates together
    await Future.wait(updates);
  }
}
