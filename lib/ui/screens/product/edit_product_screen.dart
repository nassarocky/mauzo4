import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:pattern_formatter/numeric_formatter.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/utils/constants.dart';
import 'package:mauzo/utils/preferences.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../widgets/bottomsheets/product_location_bottom_sheet.dart';
import '../../widgets/bottomsheets/product_manufacturer_bottom_sheet.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../../models/product_model.dart';
import '../../../utils/image.dart';
import '../../widgets/bottomsheets/product_category_bottom_sheet.dart';

class EditProductScreen extends StatefulWidget {
  final Product product;
  const EditProductScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late final TextEditingController _nameController =
  TextEditingController(text: widget.product.name);
  late final TextEditingController _codeController =
  TextEditingController(text: widget.product.code);
  late final TextEditingController _categoryController =
  TextEditingController(text: widget.product.category);
  late final TextEditingController _priceController = TextEditingController();
  late final TextEditingController _expireDateController = TextEditingController(
    text: widget.product.expireDate != null
        ? DateFormat('yyyy-MM-dd').format(widget.product.expireDate!)
        : '', // Provide an empty string if expireDate is null
  );
  //late final TextEditingController _quantityController = TextEditingController(text: widget.product.name);
  late  final TextEditingController _detailsController = TextEditingController(text: widget.product.details);
  late final TextEditingController _buyingPriceController = TextEditingController(text: widget.product.buyingPrice.toString());
  late final TextEditingController _underStockController = TextEditingController(text: widget.product.understock.toString());
  late  final TextEditingController _locationController = TextEditingController(text: widget.product.location);
  late  final TextEditingController _manufacturerController = TextEditingController(text: widget.product.manufacturer);
  late final TextEditingController _discountController = TextEditingController(text: widget.product.discount.toString());
  late final TextEditingController newUnitController = TextEditingController(text: widget.product.reserveString1.toString());
  bool _isBuyingPriceEmpty = false;
  bool showAdditionalFields = false; // State to track visibility of additional fields
  final ProductController _productController = Get.find();
  static final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();
  String _payment = _businessController.business['mainCurrency'];

  List<String> _units = ['piece','meter','cm','unit', 'kg', 'g']; // Example units

  bool _isUpdating = false;
  List<String> allUnits = [];
  List<String> uniqueUnits = [];
  File? imageFile;
  bool isUploading = false;
  String _selectedUnit = 'unit'; // Default selected unit
  late UploadTask uploadTask;

  @override
  void initState() {
    super.initState();
    
    // CRITICAL SECURITY CHECK: Verify user has permission to edit products
    if (!_profileController.hasPermission('edit_products')) {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: User tried to access EditProductScreen without edit_products permission');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to edit products',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }
    
    // Load custom units from business data
    _loadCustomUnits();
    
    if (_payment == 'UZS') {
      _priceController.text = widget.product.price.toString();
    } else {
      _priceController.text = widget.product.price.toString();
    }
  }

  void _loadCustomUnits() {
    // Load custom units from business 'units' field
    print('=== LOADING CUSTOM UNITS IN EDIT SCREEN ===');
    print('Business units field: ${_businessController.business['units']}');
    
    // Try 'units' field first (mapped from additionalList1)
    if (_businessController.business['units'] != null) {
      List<String> customUnits = List<String>.from(_businessController.business['units']);
      print('Custom units found: $customUnits');
      setState(() {
        // Add custom units to the _units list if not already present
        for (String unit in customUnits) {
          if (!_units.contains(unit)) {
            _units.add(unit);
            print('Added custom unit: $unit');
          }
        }
        print('Final _units list: $_units');
      });
    } else {
      print('No custom units found in business data');
    }
  }

  // SCAN
  /*
  Future<void> scanner() async {
    String barcodeScanRes;
    try {
      barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
          '#ff6666', 'cancel'.tr, true, ScanMode.BARCODE);
      _codeController.text = barcodeScanRes;
    } on PlatformException {
      barcodeScanRes = 'something_went_wrong'.tr;
    }
    if (!mounted) return;
  }*/

  Future<String> uploadFile(String folder, File file) async {
    final path = '$folder/${widget.product.id}.png';
    final ref = FirebaseStorage.instance.ref().child(path);
    uploadTask = ref.putFile(file);
    TaskSnapshot snapshot = await uploadTask;
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }
  List<String> removeDuplicateUnits(List<String> allUnits) {
    final seen = <String>{}; // Use a Set for efficient duplicate checking
    final uniqueUnits = <String>[];

    for (final unit in allUnits) {
      final lowerUnit = unit.toLowerCase();
      if (!seen.contains(lowerUnit)) {
        uniqueUnits.add(lowerUnit); // Keep the original casing
        seen.add(lowerUnit);
      }
    }
    return uniqueUnits;
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController quantityController = TextEditingController(
      text: widget.product.quantity.toString(),
    );
    allUnits = [..._units, ];
uniqueUnits=removeDuplicateUnits(allUnits);
    return WillPopScope(
      onWillPop: () async => isUploading ? false : true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Preferences.getTheme()
              ? darkGrayColor
              : primaryUltraLightColor,
          elevation: 0,
          leading: isUploading
              ? Container()
              : IconButton(
            icon: Icon(Icons.close,
                color: Theme.of(context).textTheme.bodyLarge!.color),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Text(
            'edit_product'.tr,
            style: TextStyle(
              color: Preferences.getTheme()
                  ? primaryUltraLightColor
                  : textDarkColor,
            ),
          ),
        ),
        body: isUploading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text('select_image_source'.tr),
                          content: SizedBox(
                            height: 180,
                            child: Column(
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.collections),
                                  title: Text('gallery'.tr),
                                  onTap: () async {
                                    File? selectedImage =
                                    await pickImageFromGallery();
                                    if (selectedImage != null) {
                                      setState(() {
                                        imageFile = selectedImage;
                                        Navigator.pop(context);
                                      });
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera),
                                  title: Text('camera'.tr),
                                  onTap: () async {
                                    File? capturedImage =
                                    await pickImageFromCamera();
                                    if (capturedImage != null) {
                                      setState(() {
                                        imageFile = capturedImage;
                                        Navigator.pop(context);
                                      });
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.close),
                                  title: Text('delete'.tr),
                                  onTap: () {
                                    setState(() {
                                      imageFile = null;
                                      widget.product.image = '';
                                      // You may want to update Firestore here to remove the image URL
                                      Navigator.pop(context);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        4,
                      ),
                      child: imageFile != null
                          ? Image.file(
                        imageFile!,
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                      )
                          : widget.product.image != ''
                          ? CachedNetworkImage(
                        imageUrl: widget.product.image!,
                        placeholder: (context, url) =>
                            Container(
                              padding: const EdgeInsets.all(10),
                              child:
                              const CircularProgressIndicator(),
                            ),
                        errorWidget: (context, url, error) =>
                            Container(
                              width: 86,
                              height: 86,
                              decoration: const BoxDecoration(
                                color: Color(0xFF80B2FF),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                        width: 86,
                        height: 86,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: const Color(0xFF80B2FF),
                          borderRadius:
                          BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                      ),
                      labelText: '${'name'.tr}*',
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Quantity TextField
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            labelText: '${'quantity'.tr}*',
                            labelStyle: bodyText(textPlaceholderColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8), // Space between TextField and Dropdown
                    // Unit Dropdown
                    Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Preferences.getTheme() ? mediumGrayColor : borderColor,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedUnit,
                        onChanged: (String? newValue) async {
                          if (newValue == 'add_new_unit') {
                            // Show dialog to add new unit
                            await _showAddUnitDialog(context);
                          } else {
                            setState(() {
                              _selectedUnit = newValue!;
                            });
                          }
                        },
                        items: [
                          // Existing units
                          ...uniqueUnits.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          // Add "Add New Unit" option
                          DropdownMenuItem<String>(
                            value: 'add_new_unit',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Add New Unit'.tr, style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                        underline: Container(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      '${'sellingPrice'.tr}: *',
                      style: bodyText(textPlaceholderColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            labelText: _payment,
                            labelStyle: bodyText(textPlaceholderColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),    const SizedBox(height: 24),
                Row(
                  children: [
                    Text(
                      '${'Buying Price Per Item:'.tr}: *',
                      style: bodyText(textPlaceholderColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _buyingPriceController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            ThousandsFormatter(allowFraction: true)
                          ],
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            labelText: _payment, // You can change _payment to a more suitable label if needed
                            labelStyle: bodyText(textPlaceholderColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(
                                color: _isBuyingPriceEmpty ? Colors.red : Preferences.getTheme() ? mediumGrayColor : borderColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
             SizedBox(
                  height: 44,
                  width: double.infinity,
                  child:Container(
                      padding: const EdgeInsets.only(top: 20),
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            showAdditionalFields = !showAdditionalFields;
                          });
                        },
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                              const Color(0xFF808080)),
                        ),
                        child: Text(
                          showAdditionalFields
                              ? 'Hide Additional Details'.tr
                              : 'Add Additional Details'.tr,
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                  ),
                ),
                const SizedBox(height: 24),

                // Additional fields that are shown/hidden
                if (showAdditionalFields) ...[
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _underStockController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        labelText: 'Under stock Value'.tr,
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
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        labelText: 'discount'.tr,
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
                  const SizedBox(height: 24),
// Expire Date Input Field
                  SizedBox(
                    height: 44,
                    child: TextField(
                      controller: _expireDateController, // Create a TextEditingController for this field
                      readOnly: true, // Make the field read-only to use a date picker
                      onTap: () async {
                        // Show DatePicker when the field is tapped
                        DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2000), // Start date
                          lastDate: DateTime(2100), // End date
                        );
                        if (pickedDate != null) {
                          _expireDateController.text =
                          "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}"; // Format the date
                        }
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        labelText: 'Expire Date'.tr,
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
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      onTap: () {
                        showModalBottomSheet(
                          isScrollControlled: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          context: context,
                          builder: (context) => ProductCategoryBottomSheet(
                            refresh: () {
                              _categoryController.text =
                                  _productController.selectedCategory.value;
                            },
                          ),
                        );
                      },
                      controller: _categoryController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        labelText: 'category'.tr,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
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
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      onTap: () {
                        showModalBottomSheet(
                          isScrollControlled: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          context: context,
                          builder: (context) => ProductManufacturerBottomSheet(
                            // Assuming the bottom sheet for Manufacturer operates similarly
                            refresh: () {
                              _manufacturerController.text = _productController.selectedManufacturer.value;
                            },
                          ),
                        );
                      },
                      controller: _manufacturerController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        labelText: 'manufacturer'.tr, // Label for the manufacturer field
                        labelStyle: bodyText(textPlaceholderColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Preferences.getTheme() ? mediumGrayColor : borderColor,
                          ),
                        ),
                      ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 44,
                    child: TextField(
                      onTap: () {
                        showModalBottomSheet(
                          isScrollControlled: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          context: context,
                          builder: (context) => ProductLocationBottomSheet(
                            // Assuming the bottom sheet for Manufacturer operates similarly
                            refresh: () {
                              _locationController.text = _productController.selectedLocation.value;
                            },
                          ),
                        );
                      },
                      controller: _locationController,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        labelText: 'location'.tr, // Label for the manufacturer field
                        labelStyle: bodyText(textPlaceholderColor),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                            color: Preferences.getTheme() ? mediumGrayColor : borderColor,
                          ),
                        ),
                      ),
                      readOnly: true,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 44,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeController,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              labelText: 'code'.tr,
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
                        IconButton(
                          onPressed: () {
                            //scanner();
                          },
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 24,
                            color: iconGrayColor,
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 100,
                    child: TextField(
                      controller: _detailsController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                        labelText: 'Enter details'.tr,
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
                ],
                const SizedBox(height: 34),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: PrimaryButton(
                          text: 'save'.tr,
                          onPressed: () async {
                         double  sellip= double.parse(_priceController.text.trim().replaceAll(',', ''));
                         double  buyingp= double.parse(_buyingPriceController.text.trim().replaceAll(',', ''));
                            try {
                              if (_nameController.text.isEmpty) {
                                errorSnackbar('product_name_required'.tr);
                              } else if (_priceController.text.isEmpty) {
                                errorSnackbar(
                                    'product_price_required'.tr);
                              }else if(_buyingPriceController.text.isEmpty) {
                                errorSnackbar(
                                    'product_buyingprice_required'.tr);
                              }else if (quantityController
                                  .text.isEmpty) {
                                errorSnackbar(
                                    'product_quantity_required'.tr);
                              } else if (double.parse(_priceController
                                  .text
                                  .replaceAll(',', '')) <
                                  0) {
                                errorSnackbar('price_negative'.tr);
                              } else if (double.parse(quantityController.text
                                  .replaceAll(',', '')) <
                                  0) {
                                errorSnackbar('quantity_negative'.tr);
                              } else if(buyingp>=sellip){
                                errorSnackbar(
                                    'Buying price must be less than selling price.'.tr);

                              } else {
                                setState(() {
                                  isUploading = true;
                                });

                                double priceMain = double.parse(
                                    _priceController.text
                                        .replaceAll(',', ''));
                                double priceSecondary;
                                if (_payment ==
                                    _businessController
                                        .business['secondaryCurrency']) {
                                  priceSecondary = double.parse(
                                      _priceController.text
                                          .replaceAll(',', ''));
                                  priceMain = double.parse(
                                      (priceSecondary *
                                          Preferences
                                              .getExchangeRate())
                                          .toStringAsFixed(0));
                                }

                                String url = widget.product.image!;
                                if (imageFile != null) {
                                  url = await uploadFile(
                                    'products',
                                    imageFile!,
                                  );
                                }
                                await updateProduct(
                                  _businessController,
                                  _nameController,
                                  _codeController,
                                  priceMain,
                                  quantityController,
                                  _categoryController,
                                  url,
                                  _buyingPriceController,
                                    _underStockController,
                                    _discountController,
                                    _locationController,
                                    _manufacturerController,
                                    _detailsController,
                                  _expireDateController
                                );
                                setState(() {
                                  isUploading = false;
                                });
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                                successSnackbar('product_updated'.tr);
                              }
                            } catch (e) {
                              errorSnackbar('An error occurred: $e');
                              print('$e');
                            }

                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> updateProduct(
      BusinessController businessController,
      TextEditingController nameController,
      TextEditingController codeController,
      double price,
      TextEditingController quantityController,
      TextEditingController categoryController,
      String url,
      TextEditingController buyingPriceController,
      TextEditingController underStockController,
      TextEditingController discountController,
      TextEditingController  locationController,
      TextEditingController manufacturerController,
      TextEditingController detailsController,
      TextEditingController expireDateController,

      ) async {
    final String? businessId = _businessController.business['id'];

    if (businessId == null) {
      print('Owner ID is null, cannot update product.');
      return;
    }

    DateTime? expireDate = expireDateController.text.trim().isNotEmpty
        ? DateTime.tryParse(expireDateController.text.trim())  // Try to parse the string into a DateTime
        : null;

    // Check if unit needs to be added to business units
    bool existsUnit = allUnits.contains(_selectedUnit);
    if (!existsUnit) {
      try {
        await firestore.collection('businesses').doc(businessId).update({
          'additionalList1': FieldValue.arrayUnion([_selectedUnit]),
        });
      } catch (e) {
        print('Error adding unit to business: $e');
      }
    }

    await firestore
        .collection('products')
        .doc(businessId)
        .collection('userProducts')
        .doc(widget.product.id)
        .update({
      'owner': businessController.business['id'],
      'name': nameController.text.trim(),
      'code': codeController.text.trim(),
      'price': price,
      'quantity': double.parse(quantityController.text.trim().replaceAll(',', '')),
      'category': categoryController.text.trim(),
      'image': url,
      'buyingPrice':double.parse(
    buyingPriceController.text
        .replaceAll(',', '')),
      'understock': underStockController.text.isEmpty
          ? 10.0
          : double.parse(underStockController.text.replaceAll(',', '')),
      'discount': discountController.text.isEmpty
          ? 0.00
          : double.parse(discountController.text.replaceAll(',', '')),
      'details': detailsController.text.trim(),
      'location': locationController.text.trim(),
      'reserveString1': _selectedUnit,
      'manufacturer': manufacturerController.text.trim(),
      'expireDate':expireDate

    });
  }
  Future<void> _showAddUnitDialog(BuildContext context) async {
    // Create a new controller for this dialog to avoid conflicts
    final TextEditingController dialogUnitController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          contentPadding: const EdgeInsets.all(20),
          title: Text(
            "new_unit".tr, // Translate this as needed
            style: h5(Theme.of(context).textTheme.bodyLarge!.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: dialogUnitController,
                autofocus: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  labelText: 'unit_name'.tr, // Translate this as needed
                  labelStyle: bodyText(textPlaceholderColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: PrimaryButton(
                        text: 'save'.tr,
                        onPressed: () async {
                          if (dialogUnitController.text.isNotEmpty) {
                            final String newUnit = dialogUnitController.text.trim();
                            final String? businessId = _businessController.business['id'];
                            
                            // Save to Firestore
                            if (businessId != null) {
                              try {
                                await firestore.collection('businesses').doc(businessId).update({
                                  'additionalList1': FieldValue.arrayUnion([newUnit]),
                                });
                                // Refresh business data to get updated units
                                await _businessController.updateBusinessData();
                              } catch (e) {
                                print('Error saving custom unit: $e');
                              }
                            }
                            
                            setState(() {
                              // Add the new unit to the list and select it
                              _units.add(newUnit);
                              _selectedUnit = newUnit;
                              dialogUnitController.clear();
                            });
                            Navigator.of(context).pop(true); // Close the dialog and return true
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      // Handle the case when the unit is added
    }
  }

}
