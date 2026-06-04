import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:badges/badges.dart' as badge;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/widgets/bottomsheets/product_info_bottom_sheet.dart';
import 'package:http/http.dart' as http;
import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../../widgets/bottomsheets/sort_products_bottom_sheet.dart';
import '../../widgets/search_filter_icon.dart';
import '../../widgets/tiles/product_tile.dart';
import '../mobile_code.dart';
import 'package:file_picker/file_picker.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();
  final ProductController _productController = Get.find();
  final ScrollController _scrollController = ScrollController();
  bool showSearchBar = true;
  bool transferMode = false;
  final Set<String> selectedProductIds = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['transferMode'] == true) {
      transferMode = true;
    }
  }

  @override
  void dispose() {
    Timer.run(() {

      _productController.filterCategories.value = [];
      _productController.searchProducts.value = _productController.products;
      _productController.searchText.value = '';
      _productController.filteredProducts.value = _productController.products;
      _productController.clearSelectedDateRange();
    });
    super.dispose();
  }

  // * SCAN - Live camera barcode scanner
  Future<void> scanner(BuildContext context) async {
    try {
      // Navigate to live camera scanner screen
      final scannedCode = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeScannerScreen(),
        ),
      );
      
      // If a code was scanned, search for the product
      if (scannedCode != null && scannedCode is String) {
        var product = _productController.getProductByCode(scannedCode);
        
        if (product.id != '') {
          // Product found - show product info
          showModalBottomSheet(
            isScrollControlled: true,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            context: context,
            builder: (context) => DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SafeArea(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: ProductInfoBottomSheet(product: product),
                  ),
                );
              },
            ),
          );
        } else {
          // Product not found
          errorSnackbar(
            "${'not_found'.tr}. ${'code'.tr}: $scannedCode",
          );
        }
      }
    } catch (e) {
      errorSnackbar('something_went_wrong'.tr);
    }
  }
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

  @override
  Widget build(BuildContext context) {
    final bool canEditProduct = _profileController.hasPermission('edit_products');

    AppBar buildAppBar(BuildContext context, ProductController productController) {
      return AppBar(
        elevation: 0,  // Remove elevation for a flat look
        backgroundColor: Colors.white,  // Set background to white
        title: Obx(() => Text(
          'products'.tr + ' (${productController.productCount.value})',
          style: TextStyle(color: Colors.black),  // Set the title text color to black
        )),
        iconTheme: IconThemeData(color: Colors.black),  // Set the back icon color to black
        actions: [
          if (canEditProduct)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                Navigator.pushNamed(context, '/product/add');
              },
            ),
          Obx(() => IconButton(
            icon: Image.asset(
              productController.isUnderstockFilterActive.value
                  ? 'assets/images/understockUp.png'
                  : 'assets/images/understock.png',
              width: 24,  // Set the desired width for the icon
              height: 24,  // Set the desired height for the icon
            ),
            onPressed: () {
              productController.toggleUnderstockFilter();  // Toggle the understock filter
            },
          )),
          if (canEditProduct)
            IconButton(
              icon: Image.asset(
                'assets/images/excel.png',  // Path to your custom Excel icon
                width: 24,  // Set the desired width for the icon
                height: 24,  // Set the desired height for the icon
              ),
              onPressed: () {
                productController.generateExcelFromProducts();  // Call the generateExcel method
              },
            ),
          if (canEditProduct)
            IconButton(
              tooltip: 'Download Import Template',
              icon: const Icon(Icons.file_download),
              onPressed: () {
                _productController.generateProductTemplate();
              },
            ),
          if (canEditProduct)
            IconButton(
              tooltip: 'Import from Excel',
              icon: const Icon(Icons.file_upload),
              onPressed: () async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['xlsx', 'xls'],
                  withData: true,
                );
                if (result == null) return;
                final file = result.files.single;
                final bytes = file.bytes;
                if (bytes == null) {
                  errorSnackbar('Failed to read file bytes');
                  return;
                }
                final summary = await _productController.importProductsFromExcelBytes(bytes);
                successSnackbar('Imported ${summary['imported']} products. Skipped ${summary['skipped']} rows.');
              },
            ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.white,  // Set status bar color to white
          statusBarIconBrightness: Brightness.dark,  // Set status bar icons to dark
        ),
      );
    }



    return Scaffold(
      appBar: buildAppBar(context, _productController),
      body: Obx(
            () {
          // Sort products: services first
          final sortedProducts =
              _productController.sortProductsForDisplay(_productController.filteredProducts);
          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: showSearchBar ? null : 0,
                child: SearchWidget(scanner: scanner),
              ),
              Expanded(
                child: sortedProducts.isEmpty
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
                    itemCount: sortedProducts.length +
                        (_productController.filterCategories.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index < sortedProducts.length) {
                        final product = sortedProducts[index];
                        if (transferMode) {
                          return ListTile(
                            leading: Checkbox(
                              value: selectedProductIds.contains(product.id),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selectedProductIds.add(product.id);
                                  } else {
                                    selectedProductIds.remove(product.id);
                                  }
                                });
                              },
                            ),
                            title: Text(product.name),
                            subtitle: Text('Qty: ${product.quantity}'),
                            trailing: Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              setState(() {
                                if (selectedProductIds.contains(product.id)) {
                                  selectedProductIds.remove(product.id);
                                } else {
                                  selectedProductIds.add(product.id);
                                }
                              });
                            },
                          );
                        } else {
                          return ProductTile(product: product);
                        }
                      } else if (_productController.filterCategories.isNotEmpty) {
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
                                _productController.filterCategories.value = [];
                                _productController.searchProducts.value = _productController.products;
                                _productController.searchText.value = '';
                                _productController.filteredProducts.value = _productController.products;
                                _productController.clearSelectedDateRange();
                              },
                            ),
                          ],
                        );
                      }
                      return null;
                    },
                  ),
                ),
              ),
              if (transferMode)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.shopping_cart),
                    label: Text('proceed_to_transfer'.tr),
                    onPressed: selectedProductIds.isEmpty
                        ? null
                        : () {
                            // Pass selected products to CartScreen in transfer mode
                            final selectedProducts = sortedProducts.where((p) => selectedProductIds.contains(p.id)).toList();
                            Navigator.pushNamed(
                              context,
                              '/cart',
                              arguments: {
                                'transferMode': true,
                                'selectedProducts': selectedProducts,
                              },
                            );
                          },
                  ),
                ),
            ],
          );
        },
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
  final ProductController _productController = Get.find();

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
                        _productController.search(value);
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
                  showBadge: _productController.filterCategories.isNotEmpty,
                  badgeStyle: const badge.BadgeStyle(
                    badgeColor: Color(0xFFFBBC05),
                  ),
                  badgeContent: Text(
                    _productController.filterCategories.length.toString(),
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