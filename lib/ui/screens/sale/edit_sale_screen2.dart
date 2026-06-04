import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/client_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/ui/widgets/dashed_seperator.dart';
import 'package:mauzo/ui/widgets/dialogs/add_to_cart_edit_dialog.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../models/client_model.dart';
import '../../../models/sale_model.dart';
import '../../../utils/constants.dart';
import '../../../utils/sale_line_quantity.dart';
import '../../../utils/preferences.dart';
import '../../widgets/bottomsheets/comment_bottom_sheet.dart';
import '../../widgets/bottomsheets/discount_bottom_sheet.dart';
import '../../widgets/bottomsheets/payment_bottom_sheet.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../widgets/dialogs/add_to_cart_dialog.dart';
import '../../widgets/dialogs/double_action_dialog.dart';
import '../../widgets/dialogs/triple_action_button.dart';
import '../../../services/ledger_service.dart';
import 'add_sale_screen.dart';
import 'edit_sale.screen.dart';

class EditSaleScreen2 extends StatefulWidget {
  final String title;
  final Sale sale;
  const EditSaleScreen2({Key? key, required this.title, required this.sale})
      : super(key: key);

  @override
  State<EditSaleScreen2> createState() => _EditSaleScreenState();
}

class _EditSaleScreenState extends State<EditSaleScreen2> {
  final CartController _cartController = Get.find();
  final ProductController _productController = Get.find();
  final ClientController _clientController = Get.put(ClientController());
  static final ProfileController _profileController = Get.find();
  static final BusinessController _businessController = Get.find();
  String chosenCurrency = _businessController.business['mainCurrency'];
  final TextEditingController _detailsController = TextEditingController();
  DateTime? selectedDate;

  bool _isLoading = false;

  bool get _isDebtAllowed => _businessController.isDebtEnabled;

  @override
  void dispose() {
    Timer.run(() {
      _cartController.clearClient();
      _cartController.clearPayments();
      _cartController.clearComment();
      _cartController.clearCart();
      _cartController.clearDiscount();
    });
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    selectedDate = widget.sale.date.toDate();
  }
  Future<void> _selectSaleDate(BuildContext context) async {
    final DateTime now = DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      setState(() {
        // Preserve the original time component (hours, minutes, seconds, microseconds)
        // Only update the date part (year, month, day)
        final DateTime originalTime = selectedDate ?? now;
        selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          originalTime.hour,
          originalTime.minute,
          originalTime.second,
          originalTime.millisecond,
          originalTime.microsecond,
        );
      });

      print('📅 New selected date with preserved time: $selectedDate');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => _isLoading ? false : true,
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
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client name row (copied from CartScreen)
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
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
                                      date: _cartController.client?.date ?? Timestamp.now(),
                                      debt: _cartController.client?.debt ?? 0.0,
                                      note: _cartController.client?.note,
                                      image: _cartController.client?.image,
                                    );

                                    _cartController.setClient(updatedClient);
                                  },
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                    hintText: 'Enter client name'.tr,
                                    hintStyle: bodyText(
                                      Theme.of(context).textTheme.bodyLarge!.color,
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
                                  Navigator.pushNamed(context, '/client/select').then((value) {
                                    setState(() {});
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                ),
                                child: const Icon(Icons.keyboard_arrow_right),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Date Picker Below
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GestureDetector(
                          onTap: () => _selectSaleDate(context),
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
                        itemCount: _cartController.getUniqueProducts().length,
                        itemBuilder: (context, index) {
                          final product = _cartController.getUniqueProducts()[index];


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
                                        _productController
                                            .getProduct(
                                            product.id)
                                            .name ==
                                            ''
                                            ? formatCurrency(
                                          product.price,
                                          _businessController
                                              .business['mainCurrency'],
                                        )
                                            : formatCurrency(
                                          _cartController.getPrice(
                                            product.id,
                                          ),
                                          _businessController
                                              .business['mainCurrency'],
                                        ),
                                        style: const TextStyle(
                                          color: Color(0xFF999999),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                  ),
                                ),
                                const SizedBox(
                                  width: 4,
                                ),
                                GestureDetector(
                                  onTap: () {
                                    _productController
                                        .getProduct(product.id)
                                        .id ==
                                        ''
                                        ? errorSnackbar('not_found'.tr)
                                        : showDialog(
                                      barrierDismissible: false,
                                      context: context,
                                      builder: (context) =>
                                          AddToCartDialogEdit(
                                            product: _productController
                                                .getProduct(
                                                product.id),
                                            itemCounter: _cartController
                                                .singleProductQuantity(
                                                product.id),
                                            addition:
                                            product.quantity,
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
                                      _productController
                                          .getProduct(
                                          product.id)
                                          .name ==
                                          ''
                                          ? '${product.quantity}x'
                                          : '${_cartController.singleProductQuantity(
                                        product.id,
                                      )}x',
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
                      ),   /*  Container(
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
                                  userData: UserData('hariri'),
                                ),
                              ),
                            );
                          }

                          ,
                          child: Text(
                            "add_product".tr,
                            style: bodyText(textMutedColor),
                          ),
                        ),
                      ),*/
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
                    margin:
                    const EdgeInsets.symmetric(horizontal: 20),
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
                              if (_cartController.remaining > 0) {
                                if (!_isDebtAllowed) {
                                  errorSnackbar('debt_not_allowed'.tr);
                                  return;
                                }
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

                              for (var item in _cartController.getUniqueProducts()) {
                                final quantity = _cartController.singleProductQuantity(item.id);

                                // Skip products with zero quantity if needed
                                if (quantity == 0) continue;

                                products.add({
                                  'id': item.id,
                                  'quantity': quantity,
                                  'price': _cartController.getPrice(item.id),
                                  'buyingPrice': _cartController.getBuyingPrice(item.id),
                                  'name': item.name,
                                });
                              }


                              if (_cartController.remaining > 0) {
                                if (!_isDebtAllowed) {
                                  errorSnackbar('debt_not_allowed'.tr);
                                  return;
                                }
                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    return DoubleActionDialog(
                                      title: 'unpaid_amount'.tr,
                                      content: 'unpaid_amount_description'.tr,
                                      confirm: 'debt'.tr,
                                      cancel: 'cancel'.tr,
                                      onConfirm: () {

                                        // ✅ CHECK IF PRODUCTS LIST IS EMPTY
                                        if (products.isEmpty) {
                                          Get.snackbar(
                                            'Error',
                                            'No products found. Please add products before updating the sale.',
                                            duration: const Duration(seconds: 5), // 5 seconds duration
                                            snackPosition: SnackPosition.TOP,
                                            backgroundColor: Colors.red,
                                            colorText: Colors.white,
                                          );
                                          return; // Stop execution
                                        }

                                        setState(() {
                                          _isLoading = true;
                                        });
                                        try {

                                          if (_cartController
                                              .client!.id !=
                                              '') {
                                            _clientController.updateDebt(
                                              _cartController.client!,
                                              _cartController.client!.debt - widget.sale.debt + _cartController.remaining,
                                            );

                                          }

                                          // update order
                                          updateSale(products);
                                          // update sold quantity
                                          updateSoldQuantity();
                                          // clear cart
                                          _cartController.clearCart();
                                          // navigate to home
                                          Navigator
                                              .pushNamedAndRemoveUntil(
                                              context,
                                              '/home',
                                                  (route) => false);
                                          // show success snackbar
                                          successSnackbar(
                                            'order_updated'.tr,
                                          );
                                        } catch (e) {
                                          errorSnackbar(e.toString());
                                        }
                                        setState(() {
                                          _isLoading = false;
                                        });
                                      },
                                      onCancel: () {
                                        Navigator.pop(context);
                                      },

                                    );
                                  },
                                );
                              } else if (_cartController.remaining < 0) {
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

                                // ✅ CHECK IF PRODUCTS LIST IS EMPTY
                                if (products.isEmpty) {
                                  Get.snackbar(
                                    'Error',
                                    'No products found. Please add products before updating the sale.',
                                    duration: const Duration(seconds: 5), // 5 seconds duration
                                    snackPosition: SnackPosition.TOP,
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                  );
                                  return; // Stop execution
                                }


                                setState(() {
                                  _isLoading = true;
                                });
                                try {

                                  // update order
                                  updateSale(products);
                                  // update sold quantity
                                  updateSoldQuantity();
                                  // update debt
                                  if (_cartController.client!.id != '') {
                                    _clientController.updateDebt(
                                      _cartController.client!,
                                      _cartController.client!.debt - widget.sale.debt + _cartController.remaining,
                                    );

                                  }
                                  // clear cart
                                  _cartController.clearCart();
                                  // navigate to home
                                  Navigator.pushNamedAndRemoveUntil(
                                      context, '/home', (route) => false);
                                  // show success snackbar
                                  successSnackbar(
                                    'order_updated'.tr,
                                  );
                                } catch (e) {
                                  errorSnackbar(e.toString());
                                }
                                setState(() {
                                  _isLoading = false;
                                });
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
              ],
            ),
          ),
        ),
      ),
    );
  }



  void updateSale(List<dynamic> products) {
    final String? businessId = _businessController.business['id'];
    if (businessId == null) {
      errorSnackbar('Business ID is null');
      return;
    }

    final newSaleRef = firestore
        .collection('sales')
        .doc(businessId)
        .collection('userSales')
        .doc(widget.sale.id);

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
      'debt': _isDebtAllowed ? _cartController.remaining : 0,
      'discount': _cartController.discount.value,
      'comment': _detailsController.text.trim(),
      'date': Timestamp.fromDate(selectedDate!),
      'wholesalePricingAudit':
          _cartController.buildWholesalePricingAuditMap(),
    };

    // Call functions separately without `then`
    createSale(newSaleRef, saleData, businessId);
  }

  void createSale(DocumentReference saleRef, Map<String, dynamic> saleData, String businessId) {
    saleRef.update(saleData).then((_) async {
      updateSaleId(saleRef);
      // Ledger update: delete stale entries for old sale data, then post new ones.
      try {
        await LedgerService().deleteSaleLedgerEntries(
          saleId: widget.sale.id,
          payments: widget.sale.payments,
          postedAt: widget.sale.date,
        );
        final List<dynamic> newPayments = List<dynamic>.from(saleData['payments'] ?? []);
        final dynamic d = saleData['date'];
        final Timestamp newPostedAt = d is Timestamp ? d : Timestamp.fromDate(d as DateTime);
        await LedgerService().postSaleIn(
          saleId: saleRef.id,
          payments: newPayments,
          postedAt: newPostedAt,
          clientId: _cartController.client?.id,
          clientName: _cartController.client?.name,
        );
      } catch (e) {
        print('⚠️ Ledger update failed for edited sale ${saleRef.id}: $e');
      }
    }).catchError((error) {
      errorSnackbar('Failed to create sale: $error');
    });

    if (_isDebtAllowed && _cartController.remaining > 0) {
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
    _cartController.clearDiscount();
    _cartController.clearPayments();
    _cartController.passedArgument='NOT';
    _cartController.editInvoice='NOT';
  }

  Future<void> updateSoldQuantity() async {
    // ✅ Batch all updates for better offline support
    final updates = <Future>[];
    
    for (var product in widget.sale.products) {
      final m = Map<String, dynamic>.from(product as Map);
      final pid = m['id']?.toString() ?? '';
      final origBase = saleLineBaseQuantity(m);
      final cartBase = _cartController.singleProductBaseQuantity(pid);
      final inv = _productController.getProduct(pid);
      if (inv.id.isEmpty) continue;
      updates.add(_productController.updateProductCount(
        inv,
        inv.quantity - cartBase + origBase,
        'Edit',
        pairedTwinQuantityDelta: inv.isPairedMain ? (origBase - cartBase) : null,
      ));
    }
    
    // ✅ Wait for all updates together
    await Future.wait(updates);
  }

}
