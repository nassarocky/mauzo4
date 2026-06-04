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
import '../../../constants/transaction_constants.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../widgets/bottomsheets/product_location_bottom_sheet.dart';
import '../../widgets/bottomsheets/product_manufacturer_bottom_sheet.dart';
import '../../widgets/buttons/primary_button.dart';
import '../../../models/product_model.dart';
import '../../../services/paired_product_service.dart';
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
  late final TextEditingController _wholesalePriceController;
  late final TextEditingController _wholesaleMinQtyController;
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
  String _selectedProductType = 'normal';
  final TextEditingController _twinNameController = TextEditingController();
  final TextEditingController _twinBuyingPriceController = TextEditingController();
  final TextEditingController _twinSellingPriceController = TextEditingController();
  final TextEditingController _twinQuantityController = TextEditingController();
  late UploadTask uploadTask;

  @override
  void initState() {
    super.initState();
    _wholesalePriceController = TextEditingController(
      text: widget.product.wholesalePrice > 0
          ? widget.product.wholesalePrice.toString()
          : '',
    );
    _wholesaleMinQtyController = TextEditingController(
      text: widget.product.effectiveWholesaleMinQuantity.toString(),
    );
    if (widget.product.wholesalePrice > 0) {
      showAdditionalFields = true;
    }

    _selectedUnit = widget.product.reserveString1.isNotEmpty
        ? widget.product.reserveString1
        : 'unit';
    _selectedProductType = widget.product.isTwinProduct
        ? PairedProductService.typeNormal
        : widget.product.productType;
    if (widget.product.isPairedMain &&
        widget.product.twinProductId != null &&
        widget.product.twinProductId!.isNotEmpty) {
      showAdditionalFields = true;
      final twin = _productController.getProduct(widget.product.twinProductId!);
      if (twin.id.isNotEmpty) {
        _twinNameController.text = twin.name;
        _twinBuyingPriceController.text = twin.buyingPrice.toString();
        _twinSellingPriceController.text = twin.price.toString();
        final tq = twin.quantity;
        _twinQuantityController.text =
            tq % 1 == 0 ? tq.toStringAsFixed(0) : tq.toString();
      }
    }

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

    final rs = widget.product.reserveString1.trim();
    if (rs.isNotEmpty) {
      _selectedUnit = rs;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _businessController.updateBusinessData();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _twinNameController.dispose();
    _twinBuyingPriceController.dispose();
    _twinSellingPriceController.dispose();
    _twinQuantityController.dispose();
    super.dispose();
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
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _wholesalePriceController,
                  builder: (context, value, _) {
                    final w = double.tryParse(
                      value.text.trim().replaceAll(',', ''),
                    );
                    if (w == null || w <= 0 || showAdditionalFields) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'wholesale_selling_price'.tr,
                              style: bodyText(textPlaceholderColor),
                            ),
                          ),
                          Text(
                            formatCurrency(
                              w,
                              _businessController.business['mainCurrency'] ?? 'TZS',
                            ),
                            style: h6(
                              Theme.of(context).textTheme.bodyLarge?.color ??
                                  textDarkColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
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
                if (widget.product.itemType == 'product' &&
                    !widget.product.isTwinProduct) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('product_type'.tr),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _selectedProductType,
                        items: [
                          DropdownMenuItem(
                            value: PairedProductService.typeNormal,
                            child: Text('product_type_normal'.tr),
                          ),
                          DropdownMenuItem(
                            value: PairedProductService.typePaired,
                            child: Text('product_type_paired'.tr),
                          ),
                        ],
                        onChanged: widget.product.isPairedMain
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedProductType = value!;
                                });
                              },
                      ),
                    ],
                  ),
                  if (widget.product.isPairedMain)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'paired_edit_cannot_remove_link'.tr,
                        style: bodyText(textMutedColor),
                      ),
                    ),
                  if (_selectedProductType == PairedProductService.typePaired) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.product.isPairedMain
                          ? 'edit_twin_section_existing'.tr
                          : 'edit_convert_to_paired_hint'.tr,
                      style: bodyText(textMutedColor),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _twinNameController,
                        decoration: InputDecoration(
                          labelText: 'twin_product_name'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _twinBuyingPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'twin_product_buying_price'.tr,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _twinSellingPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'twin_product_selling_price'.tr,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: TextField(
                        controller: _twinQuantityController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'twin_product_quantity'.tr,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
                if (widget.product.isTwinProduct &&
                    widget.product.parentProductId != null &&
                    widget.product.parentProductId!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Text(
                      '${'paired_parent_product_label'.tr}: ${_productController.getProduct(widget.product.parentProductId!).name}',
                      style: TextStyle(color: Colors.teal.shade900),
                    ),
                  ),
                ],
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
                  Row(
                    children: [
                      Text(
                        'wholesale_selling_price'.tr,
                        style: bodyText(textPlaceholderColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _wholesalePriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              labelText: _payment,
                              hintText: 'wholesale_price_leave_empty'.tr,
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
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          'wholesale_min_quantity_label'.tr,
                          style: bodyText(textPlaceholderColor),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _wholesaleMinQtyController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              hintText: 'wholesale_min_quantity_hint'.tr,
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
                    ],
                  ),
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
                              } else if(_buyingPriceController.text.isEmpty) {
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
                              } else {
                                final wMinRaw = _wholesaleMinQtyController.text
                                    .trim()
                                    .replaceAll(',', '');
                                final wholesaleMinQty = int.tryParse(wMinRaw);
                                if (wholesaleMinQty == null ||
                                    wholesaleMinQty < 1) {
                                  errorSnackbar('wholesale_min_invalid'.tr);
                                } else {
                                final wholesaleRaw =
                                    _wholesalePriceController.text
                                        .trim()
                                        .replaceAll(',', '');
                                double wholesaleDisplay = 0.0;
                                if (wholesaleRaw.isNotEmpty) {
                                  wholesaleDisplay =
                                      double.parse(wholesaleRaw);
                                }
                                if (wholesaleDisplay > sellip + 1e-9) {
                                  errorSnackbar('wholesale_above_retail'.tr);
                                } else if (buyingp >= sellip) {
                                  errorSnackbar(
                                      'Buying price must be less than selling price.'
                                          .tr);
                                } else if (wholesaleDisplay > 0 &&
                                    buyingp >= wholesaleDisplay - 1e-9) {
                                  errorSnackbar('buying_must_be_below_wholesale'.tr);
                                } else if (!widget.product.isTwinProduct &&
                                    widget.product.itemType == 'product' &&
                                    _selectedProductType ==
                                        PairedProductService.typePaired) {
                                  if (_twinNameController.text.trim().isEmpty) {
                                    errorSnackbar('twin_product_name_required'.tr);
                                  } else {
                                    final twinBuy = double.tryParse(
                                        _twinBuyingPriceController.text.replaceAll(',', ''));
                                    final twinSell = double.tryParse(
                                        _twinSellingPriceController.text.replaceAll(',', ''));
                                    if (twinBuy == null || twinSell == null) {
                                      errorSnackbar('twin_product_prices_required'.tr);
                                    } else if (twinBuy >= twinSell) {
                                      errorSnackbar('twin_buy_below_sell'.tr);
                                    } else {
                                      final twinQtyRaw = _twinQuantityController.text
                                          .trim()
                                          .replaceAll(',', '');
                                      if (twinQtyRaw.isNotEmpty &&
                                          (double.tryParse(twinQtyRaw) == null ||
                                              double.parse(twinQtyRaw) < 0)) {
                                        errorSnackbar('twin_product_quantity_invalid'.tr);
                                      } else {
                                        setState(() => isUploading = true);
                                        await _saveProductFromForm(
                                          quantityController,
                                          sellip,
                                          wholesaleDisplay,
                                          wholesaleMinQty,
                                          imageFile,
                                        );
                                      }
                                    }
                                  }
                                } else {
                                  setState(() {
                                    isUploading = true;
                                  });

                                  double priceMain = double.parse(
                                      _priceController.text
                                          .replaceAll(',', ''));
                                  if (_payment ==
                                      _businessController
                                          .business['secondaryCurrency']) {
                                    final priceSecondary = double.parse(
                                        _priceController.text
                                            .replaceAll(',', ''));
                                    priceMain = double.parse(
                                        (priceSecondary *
                                                Preferences.getExchangeRate())
                                            .toStringAsFixed(0));
                                  }

                                  double wholesaleMain = 0.0;
                                  if (wholesaleDisplay > 0) {
                                    wholesaleMain = wholesaleDisplay;
                                    if (_payment ==
                                        _businessController
                                            .business['secondaryCurrency']) {
                                      wholesaleMain = double.parse(
                                          (wholesaleDisplay *
                                                  Preferences.getExchangeRate())
                                              .toStringAsFixed(0));
                                    }
                                  }

                                  await _saveProductFromForm(
                                    quantityController,
                                    sellip,
                                    wholesaleDisplay,
                                    wholesaleMinQty,
                                    imageFile,
                                    priceMainOverride: priceMain,
                                    wholesaleMainOverride: wholesaleMain,
                                  );
                                }
                                }
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

  Future<void> _saveProductFromForm(
    TextEditingController quantityController,
    double sellipDisplay,
    double wholesaleDisplay,
    int wholesaleMinQty,
    File? imageFile, {
    double? priceMainOverride,
    double? wholesaleMainOverride,
  }) async {
    double priceMain = priceMainOverride ??
        double.parse(_priceController.text.replaceAll(',', ''));
    if (priceMainOverride == null &&
        _payment == _businessController.business['secondaryCurrency']) {
      priceMain = double.parse(
        (sellipDisplay * Preferences.getExchangeRate()).toStringAsFixed(0),
      );
    }

    double wholesaleMain = wholesaleMainOverride ?? 0.0;
    if (wholesaleMainOverride == null && wholesaleDisplay > 0) {
      wholesaleMain = wholesaleDisplay;
      if (_payment == _businessController.business['secondaryCurrency']) {
        wholesaleMain = double.parse(
          (wholesaleDisplay * Preferences.getExchangeRate()).toStringAsFixed(0),
        );
      }
    }

    String url = widget.product.image ?? '';
    if (imageFile != null) {
      url = await uploadFile('products', imageFile) ?? url;
    }

    final ok = await updateProduct(
      _businessController,
      _nameController,
      _codeController,
      priceMain,
      wholesaleMain,
      wholesaleMinQty,
      quantityController,
      _categoryController,
      url,
      _buyingPriceController,
      _underStockController,
      _discountController,
      _locationController,
      _manufacturerController,
      _detailsController,
      _expireDateController,
    );

    if (!mounted) return;
    setState(() => isUploading = false);
    if (ok) {
      Navigator.pop(context);
      successSnackbar('product_updated'.tr);
    }
  }

  Future<bool> updateProduct(
      BusinessController businessController,
      TextEditingController nameController,
      TextEditingController codeController,
      double price,
      double wholesalePrice,
      int wholesaleMinQuantity,
      TextEditingController quantityController,
      TextEditingController categoryController,
      String url,
      TextEditingController buyingPriceController,
      TextEditingController underStockController,
      TextEditingController discountController,
      TextEditingController locationController,
      TextEditingController manufacturerController,
      TextEditingController detailsController,
      TextEditingController expireDateController,
      ) async {
    final String? businessId = _businessController.business['id'];

    if (businessId == null) {
      print('Owner ID is null, cannot update product.');
      return false;
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

    final double oldQuantity = widget.product.quantity;
    final double newQuantity = double.parse(quantityController.text.trim().replaceAll(',', ''));

    String? twinId = widget.product.twinProductId;

    if (!widget.product.isTwinProduct &&
        widget.product.itemType == 'product' &&
        _selectedProductType == PairedProductService.typePaired) {
      final twinBuy =
          double.parse(_twinBuyingPriceController.text.replaceAll(',', ''));
      final twinSell =
          double.parse(_twinSellingPriceController.text.replaceAll(',', ''));
      final twinQtyRaw =
          _twinQuantityController.text.trim().replaceAll(',', '');
      final twinQty = twinQtyRaw.isEmpty ? 0.0 : double.parse(twinQtyRaw);

      if (widget.product.productType != PairedProductService.typePaired) {
        twinId = await _productController.attachTwinToExistingMain(
          main: widget.product,
          twinName: _twinNameController.text.trim(),
          twinBuyingPrice: twinBuy,
          twinSellingPrice: twinSell,
          twinQuantity: twinQty,
        );
        if (twinId == null) return false;
      } else if (twinId != null && twinId.isNotEmpty) {
        await _productController.updateLinkedTwinProduct(
          twinId: twinId,
          name: _twinNameController.text.trim(),
          buyingPrice: twinBuy,
          sellingPrice: twinSell,
          newQuantity: twinQty,
        );
      }
    }

    final productType =
        widget.product.isTwinProduct ? 'normal' : _selectedProductType;

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
      'wholesalePrice': wholesalePrice,
      'wholesaleMinQuantity': wholesaleMinQuantity,
      'uomConversions': <Map<String, dynamic>>[],
      'quantity': newQuantity,
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
      'expireDate': expireDate,
      'productType': productType,
      if (twinId != null && twinId.isNotEmpty) 'twinProductId': twinId,
      'isTwinProduct': widget.product.isTwinProduct,
      if (widget.product.parentProductId != null &&
          widget.product.parentProductId!.isNotEmpty)
        'parentProductId': widget.product.parentProductId,
    });

    await _productController.syncProductMetadataToStore(
      productId: widget.product.id,
      metadata: {
        'name': nameController.text.trim(),
        'code': codeController.text.trim(),
        'price': price,
        'wholesalePrice': wholesalePrice,
        'wholesaleMinQuantity': wholesaleMinQuantity,
        'uomConversions': <Map<String, dynamic>>[],
        'category': categoryController.text.trim(),
        'image': url,
        'buyingPrice': double.parse(
            buyingPriceController.text.replaceAll(',', '')),
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
        'expireDate': expireDate != null ? Timestamp.fromDate(expireDate) : null,
        'itemType': widget.product.itemType,
        'productType': productType,
        'twinProductId': twinId,
        'isTwinProduct': widget.product.isTwinProduct,
        'parentProductId': widget.product.parentProductId,
      },
    );

    if (newQuantity != oldQuantity) {
      final double change = (newQuantity - oldQuantity).abs();
      await _productController.createStockTransaction(
        productId: widget.product.id,
        quantityChange: change,
        previousQuantity: oldQuantity,
        newQuantity: newQuantity,
        transactionType: newQuantity > oldQuantity
            ? TransactionTypes.addition
            : TransactionTypes.removal,
        transactionOrigin: TransactionOrigins.manualAdjustment,
        price: price,
        referenceType: TransactionReferenceTypes.manual,
        notes: 'Manual quantity edit',
      );
    }
    return true;
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
