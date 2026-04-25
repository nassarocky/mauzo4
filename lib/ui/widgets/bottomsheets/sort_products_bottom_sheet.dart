import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/store_controller.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class SortProductsBottomSheet extends StatefulWidget {
  /// When true, filter/sort applies to [StoreController] (store inventory), not shop products.
  final bool forStore;

  const SortProductsBottomSheet({Key? key, this.forStore = false}) : super(key: key);

  @override
  State<SortProductsBottomSheet> createState() =>
      _SortProductsBottomSheetState();
}

class _SortProductsBottomSheetState extends State<SortProductsBottomSheet> {
  List<String> localFilterCategories = [];
  final ProductController _productController = Get.find();
  final StoreController _storeController = Get.find();
  DateTime? selectedExpireDate;

  @override
  void initState() {
    localFilterCategories = widget.forStore
        ? [..._storeController.filterCategories]
        : [..._productController.filterCategories];
    super.initState();
  }

  // Function to show Date Picker
  Future<void> _selectExpireDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedExpireDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null && picked != selectedExpireDate) {
      setState(() {
        selectedExpireDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final BusinessController businessController = Get.find();
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Categories Title
                Text(
                  'categories'.tr,
                  style: h5(Theme.of(context).textTheme.bodyLarge!.color),
                ),
                // Expire Date Filter Button
                GestureDetector(
                  onTap: () {
                    _selectExpireDate(context); // Show date picker
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Preferences.getTheme() ? primaryLightColor : primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      selectedExpireDate == null
                          ? 'Select Expire Date'
                          : '${selectedExpireDate!.toLocal()}'.split(' ')[0], // Format the date
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.purple,
                    Colors.transparent,
                    Colors.transparent,
                    Colors.purple
                  ],
                  stops: [
                    0.0,
                    0.05,
                    0.9,
                    1.0
                  ], // 10% purple, 80% transparent, 10% purple
                ).createShader(rect);
              },
              blendMode: BlendMode.dstOut,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: businessController.business['categories'].length,
                itemBuilder: (_, index) {
                  return CheckboxListTile(
                    visualDensity: VisualDensity.compact,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: Preferences.getTheme()
                        ? primaryLightColor
                        : primaryColor,
                    title: Text(
                      businessController.business['categories'][index],
                    ),
                    value: localFilterCategories.contains(
                      businessController.business['categories'][index],
                    ),
                    onChanged: (value) {
                      setState(() {
                        if (localFilterCategories.contains(
                            businessController.business['categories'][index])) {
                          localFilterCategories.remove(
                            businessController.business['categories'][index],
                          );
                        } else {
                          localFilterCategories.add(
                            businessController.business['categories'][index],
                          );
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Preferences.getTheme() ? lightGrayColor : borderColor,
                ),
              ),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: SecondaryButton(
                    onPressed: () {
                      if (widget.forStore) {
                        _storeController.filterCategories.clear();
                        _storeController.resetProducts();
                        _storeController.clearSelectedDateRange();
                      } else {
                        _productController.filterCategories.clear();
                        _productController.resetProducts();
                        _productController.clearSelectedDateRange();
                      }
                      Navigator.pop(context);
                    },
                    text: 'reset'.tr,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    text: 'apply'.tr,
                      onPressed: () {
                        if (widget.forStore) {
                          if (selectedExpireDate != null) {
                            _storeController.filterProductsByExpireDate(selectedExpireDate!);
                          }
                          _storeController.setFilterCategories(localFilterCategories);
                          _storeController.filterProducts();
                        } else {
                          if (selectedExpireDate != null) {
                            _productController.filterProductsByExpireDate(selectedExpireDate!);
                          }
                          _productController.setFilterCategories(localFilterCategories);
                          _productController.filterProducts();
                        }
                        Navigator.pop(context);
                      },

                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
