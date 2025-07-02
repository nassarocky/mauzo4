import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:badges/badges.dart' as badge;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:http/http.dart' as http;
import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../controllers/store_controller.dart';
import '../../../utils/constants.dart';
import '../../widgets/bottomsheets/sort_products_bottom_sheet.dart';
import '../../widgets/search_filter_icon.dart';
import '../../widgets/tiles/product_tile.dart';
import '../../widgets/tiles/store_tile.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({Key? key}) : super(key: key);

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();
  final StoreController _storeController = Get.find();
  final ScrollController _scrollController = ScrollController();
  bool showSearchBar = true;
  bool isBuyingStock = Preferences.getStockDisplayPreference();
  @override
  void dispose() {
    Timer.run(() {

      _storeController.filterCategories.value = [];
      _storeController.searchProducts.value = _storeController.products;
      _storeController.searchText.value = '';
      _storeController.filteredProducts.value = _storeController.products;
    });
    super.dispose();
  }
  @override
  void initState() {
    super.initState();
    //_onPageOpen(); // Call the function here
  }

  void _onPageOpen() {
    // Your function logic here
    // For example, you could refresh data or perform any setup needed when this page is accessed
  }
  // * SCAN
  /*
  Future<void> scanner(BuildContext context) async {
    String barcodeScanRes;
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'cancel'.tr, true, ScanMode.BARCODE);
      if (barcodeScanRes != "-1") {
        var product = _storeController.getProductByCode(barcodeScanRes);
        if (product.id != '') {
          showModalBottomSheet(
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            context: context,
            builder: (_) => StoreInfoBottomSheet(product: product),
          );
        } else {
          errorSnackbar(
            "${'not_found'.tr}. ${'code'.tr}: $barcodeScanRes",
          );
        }
      }
    } on PlatformException {
      barcodeScanRes = 'something_went_wrong'.tr;
    }
    if (!mounted) return;
  }*/
  void _showSnackbar(String message) {
    final snackBar = SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 10),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  Future<void> _showConfirmationDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Are you sure?'.tr),
          content: Text('Do you really want to refresh the product quantities?'.tr),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: Text('No'.tr),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: Text('Yes'.tr),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _resetProductQuantities();
    }
  }

  Future<void> _resetProductQuantities() async {
    final String businessId = _businessController.business['id'];
    final Uri url = Uri.parse(
        'https://us-central1-hesabumauzo.cloudfunctions.net/resetProductQuantities?business=$businessId'
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        successSnackbar('Product quantities successfully updated.'.tr);
      } else {
        errorSnackbar('Failed to update product quantities.'.tr);
      }
    } catch (e) {
      errorSnackbar('Error: ${e.toString()}'.tr);
    }
  }

  void _showBulkMovementOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bulk Stock Movement'.tr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmBulkMove('toStore');
                    },
                    icon: Icon(Icons.move_to_inbox),
                    label: Text('Move All to Store'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmBulkMove('toShop');
                    },
                    icon: Icon(Icons.store),
                    label: Text('Move All to Shop'.tr),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _confirmBulkMove(String direction) {
    String title = direction == 'toStore' ? 'Move All to Store'.tr : 'Move All to Shop'.tr;
    String message = direction == 'toStore' 
        ? 'This will move all shop products with stock to the store. Continue?'.tr
        : 'This will move all store products with stock to the shop. Continue?'.tr;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (direction == 'toStore') {
                _storeController.moveAllStockToStore();
              } else {
                _storeController.moveAllStockToShop();
              }
            },
            child: Text('Confirm'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool passwordMatches = _profileController.user['role'] == 'owner';

    AppBar buildAppBar(BuildContext context, StoreController storeController, bool passwordMatches) {
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Store'.tr,
              style: const TextStyle(color: Colors.black),
            ),
            const SizedBox(width: 8),
            // Using Obx to update the value reactively if it's an observable value
            Obx(() {
              final totalStock = isBuyingStock
                  ? storeController.calculateTotalStockBuying()
                  : storeController.calculateTotalStock();
              return Text(
                "(${formatCurrency(totalStock, _businessController.business['mainCurrency'])})",
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              );
            }),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          if (passwordMatches)
            IconButton(
              icon: Image.asset(
                'assets/images/excel.png',
                width: 24,
                height: 24,
              ),
              onPressed: () {
                storeController.generateExcelFromProductsInstore();
              },
            ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
        ),
      );
    }



    return Scaffold(
      appBar: buildAppBar(context, _storeController, passwordMatches),
      floatingActionButton: passwordMatches ? FloatingActionButton.extended(
        onPressed: () {
          _showBulkMovementOptions(context);
        },
        label: Text('Bulk Actions'.tr),
        icon: Icon(Icons.move_to_inbox),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ) : null,
      body: Obx(
            () => Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: showSearchBar ? null : 0,
             // child: SearchWidget(scanner: scanner),
            ),
            Expanded(
              child: _storeController.filteredProducts.isEmpty
                  ? Center(
                child: Text(
                  'not_found'.tr,
                  style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                ),
              )
                  : NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (_scrollController.position.userScrollDirection ==
                      ScrollDirection.reverse) {
                    if (showSearchBar) {
                      setState(() {
                        showSearchBar = false;
                      });
                    }
                  } else if (_scrollController.position.userScrollDirection ==
                      ScrollDirection.forward) {
                    if (!showSearchBar) {
                      setState(() {
                        showSearchBar = true;
                      });
                    }
                  }
                  return true;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 20),
                  itemCount: _storeController.filteredProducts.length +
                      (_storeController.filterCategories.isNotEmpty ? 1 : 0),
                  itemBuilder: (context, index) {

                    if (index < _storeController.filteredProducts.length) {

                      final product = _storeController.filteredProducts[index];
                      return StoreTile(product: product);
                    } else if (_storeController.filterCategories.isNotEmpty) {
                      return Column(
                        children: [
                          const Divider(height: 0),
                          const SizedBox(height: 20),
                          Text(
                            'you_applied_filter'.tr,
                            style: bodyText(textMutedColor),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            child: Text(
                              'show_all'.tr,
                              style: bodyText(
                                Preferences.getTheme()
                                    ? primaryLightColor
                                    : primaryColor,
                              ),
                            ),
                            onPressed: () {
                              _storeController.filterCategories.value = [];
                              _storeController.filterProducts();
                            },
                          ),
                          const SizedBox(height: 40),
                        ],
                      );
                    }
                    return null;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchWidget extends StatefulWidget {
  final Function scanner;
  const SearchWidget({Key? key, required this.scanner}) : super(key: key);

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final StoreController _storeController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Preferences.getTheme()
                            ? mediumGrayColor
                            : const Color(0xFFE0E0E0),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        _storeController.search(value);
                      },
                      decoration: InputDecoration(
                        hintText: 'search'.tr,
                        contentPadding: const EdgeInsets.all(0),
                        hintStyle: bodyText(iconGrayColor),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: iconGrayColor,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SearchFilterIcon(
                  icon: Icons.qr_code_scanner,
                  onPressed: () {
                    widget.scanner(context);
                  },
                ),
                const SizedBox(width: 8),
                badge.Badge(
                  showBadge: _storeController.filterCategories.isNotEmpty,
                  badgeStyle: const badge.BadgeStyle(
                    badgeColor: Color(0xFFFBBC05),
                  ),
                  badgeContent: Text(
                    _storeController.filterCategories.length.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  child: SearchFilterIcon(
                    icon: Icons.sort,
                    onPressed: () {
                      showModalBottomSheet(
                        isScrollControlled: true,
                        context: context,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        builder: (_) {
                          return const SortProductsBottomSheet();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.only(left: 16.0, right: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'product_name'.tr,
                style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
              ),
              Text(
                'in_stock'.tr,
                style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
