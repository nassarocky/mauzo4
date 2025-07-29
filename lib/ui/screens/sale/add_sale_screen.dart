import 'dart:async';
import 'package:badges/badges.dart' as badge;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mauzo/controllers/cart_controller.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/ui/screens/cart_screen.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../../widgets/bottomsheets/sort_products_bottom_sheet.dart';
import '../../widgets/search_filter_icon.dart';
import '../../widgets/tiles/sale_tile.dart';
import 'edit_sale.screen.dart';

class AddSaleScreen extends StatefulWidget {
  final UserData? userData; // Optional user data for flexibility

  const AddSaleScreen({Key? key, this.userData}) : super(key: key);

  static AddSaleScreen fromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    print('[DEBUG] AddSaleScreen.fromArgs called with args: ' + args.toString());
    if (args is Map && args['userData'] is UserData) {
      print('[DEBUG] AddSaleScreen.fromArgs setting userData to: ' + (args['userData'] as UserData).name);
      return AddSaleScreen(userData: args['userData']);
    }
    return AddSaleScreen();
  }

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen>
    with TickerProviderStateMixin {
  // Animation
  late final AnimationController _animationController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  late final Animation<double> _animation = CurvedAnimation(
    parent: _animationController,
    curve: Curves.fastOutSlowIn,
  );
  String name = '';

  @override
  void dispose() {
    Timer.run(() {
      _productController.filterCategories.value = [];
      _productController.searchProducts.value = _productController.products;
      _productController.searchText.value = '';
      _productController.filteredProducts.value = _productController.products;
      _animationController.dispose();
    });
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['transferMode'] == true) {
      transferMode = true;
      print('[DEBUG] AddSaleScreen transferMode set to TRUE');
    }
  }

  final ProductController _productController = Get.find();
  final CartController _cartController = Get.find();
  final ProfileController _profileController = Get.find();
  final ScrollController _scrollController = ScrollController();
  bool showSearchBar = true;
  bool transferMode = false;

  // Scanner
  Future<void> scanner() async {
    try {
      final inputImage = await ImagePicker().pickImage(source: ImageSource.camera);
      if (inputImage == null) return;

      final input = InputImage.fromFilePath(inputImage.path);
      final barcodeScanner = BarcodeScanner();
      final List<Barcode> barcodes = await barcodeScanner.processImage(input);
      
      if (barcodes.isNotEmpty) {
        final barcode = barcodes.first;
        if (barcode.rawValue != null) {
          Product product = _productController.getProductByCode(barcode.rawValue!);
          if (product.id != "") {
            if (product.quantity! > _cartController.singleProductQuantity(product.id)) {
              _cartController.updateCart(
                product,
                _cartController.singleProductQuantity(product.id) + 1,
                _cartController.getPrice(product.id) == 0
                    ? product.price
                    : _cartController.getPrice(product.id),
              );
            } else {
              errorSnackbar('not_enough'.tr);
            }
          } else {
            errorSnackbar(
              "${'not_found'.tr}. ${'code'.tr}: ${barcode.rawValue}",
            );
          }
        }
      }
    } catch (e) {
      errorSnackbar('something_went_wrong'.tr);
    }
    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    String from = widget.userData?.name ?? '';
    final bool transferMode = from == 'transfer';
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600;

    final TextEditingController searchController = TextEditingController(
      text: '',
    );
    return Obx(
          () => Scaffold(
        appBar: AppBar(
          backgroundColor:
          Preferences.getTheme() ? darkGrayColor : primaryUltraLightColor,
          foregroundColor:
          Preferences.getTheme() ? primaryUltraLightColor : textDarkColor,
          elevation: 0,
          title: Text('select_items'.tr),
        ),
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: [
                    Text(
                      _cartController.products.length.toString(),
                      style: TextStyle(
                        fontSize: 28,
                        color: Preferences.getTheme()
                            ? primaryLightColor
                            : primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      ' ${'selected'.tr}',
                      style: bodyText(const Color(0xFFA9A9A9)),
                    ),
                  ],
                ),
                if (!isTablet)
                  SizedBox(
                    height: 44,
                    width: 124,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                      ),
                      onPressed: _cartController.products.isEmpty
                          ? null
                          : () {
                        if (from == 'invoice') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CartScreen(
                                  userData: UserData('invoice')),
                            ),
                          );
                        } else if(from=='transfer') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CartScreen(
                                  userData: UserData('transfer')),
                            ),
                          );
                        } else if(from=='hariri'){
                          Navigator.pop(context);
                        } else {
                          print('[DEBUG] Navigating to CartScreen with transferMode=$transferMode');
                          Navigator.pushNamed(context, '/cart');
                        }
                      },
                      child: Text(
                        'done'.tr,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            showSearchBar
                ? SizeTransition(
              sizeFactor: _animation,
              child: Padding(
                padding: const EdgeInsets.all(16),
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
                            controller: searchController,
                            onChanged: (value) {
                              _productController.search(value);
                            },
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(0),
                              hintText: 'search'.tr,
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
                          scanner();
                        },
                      ),
                      const SizedBox(width: 8),
                      badge.Badge(
                        showBadge: _productController
                            .filterCategories.isNotEmpty,
                        badgeStyle: const badge.BadgeStyle(
                          badgeColor: Color(0xFFFBBC05),
                        ),
                        badgeContent: Text(
                          _productController.filterCategories.length
                              .toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        child: SearchFilterIcon(
                          icon: Icons.sort,
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
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
            )
                : const SizedBox(),
            Expanded(
              child: _productController.filteredProducts.isEmpty
                  ? Center(
                child: Text(
                  'not_found'.tr,
                  style: bodyText(
                      Theme.of(context).textTheme.bodyMedium!.color),
                ),
              )
                  : NotificationListener(
                onNotification: (scrollNotification) {
                  if (_scrollController.position.userScrollDirection ==
                      ScrollDirection.reverse) {
                    if (showSearchBar) {
                      _animationController.reverse();
                      showSearchBar = false;
                    }
                  } else if (_scrollController
                      .position.userScrollDirection ==
                      ScrollDirection.forward) {
                    if (!showSearchBar) {
                      _animationController.forward();
                      setState(() {
                        showSearchBar = true;
                      });
                    }
                  }
                  return true;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: _productController.filteredProducts.length,
                  itemBuilder: (context, index) {
                    // Sort products: services first
                    final sortedProducts = List.of(_productController.filteredProducts);
                    sortedProducts.sort((a, b) {
                      if (a.itemType == 'service' && b.itemType != 'service') return -1;
                      if (a.itemType != 'service' && b.itemType == 'service') return 1;
                      return 0;
                    });
                    
                    return SaleTile(
                      product: sortedProducts[index],
                    );
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
