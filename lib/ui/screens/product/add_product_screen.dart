import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../../widgets/bottomsheets/product_category_bottom_sheet.dart';
import '../../widgets/bottomsheets/product_location_bottom_sheet.dart';
import '../../widgets/bottomsheets/product_manufacturer_bottom_sheet.dart';
import '../../widgets/buttons/primary_button.dart';
import 'package:http/http.dart' as http;

import '../mobile_code.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final ProductController _productController = Get.find();
  static final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _buyingPriceController = TextEditingController();
  final TextEditingController _underStockController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _expireDateController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController newUnitController = TextEditingController();

  bool _isNameEmpty = false;
  bool _isQuantityEmpty = false;
  bool _isPriceEmpty = false;
  //final Connectivity _connectivity = Connectivity();
  bool _isBuyingPriceEmpty = false;
  bool showAdditionalFields = false; // State to track visibility of additional fields
  File? imageFile;
  UploadTask? uploadTask;
  bool isUploading = false;
  String _selectedUnit = 'unit'; // Default selected unit
  List<String> _units = ['piece','meter','cm','unit', 'kg', 'g','pair','set']; // Example units
  bool _isUpdating = false;
  List<String> allUnits = [];
  List<String> uniqueUnits = [];
  final TextEditingController _totalBuyingPriceController = TextEditingController();

  bool _isTypingPerItem = false;
  bool _isTypingTotal = false;
  bool _isQuantityEntered = false;
  // Add state for item type
  String _selectedItemType = 'product'; // Default to 'product'
  @override
  void initState() {
    super.initState();
    
    // CRITICAL SECURITY CHECK: Verify user has permission to edit products
    if (!_profileController.hasPermission('edit_products')) {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: User tried to access AddProductScreen without edit_products permission');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to add/edit products',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }
    
    requestPermissions();
    
    // Load custom units from business data
    _loadCustomUnits();

    _quantityController.addListener(() {
      setState(() {
        _isQuantityEntered = _quantityController.text.isNotEmpty;
      });

      if (!_isTypingPerItem && !_isTypingTotal) {
        _updateBothPrices();
      }
    });

    // Listeners for focus changes
    _buyingPriceController.addListener(() {
      if (_isTypingPerItem) {
        _updateTotalBuyingPrice();
      }
    });

    _totalBuyingPriceController.addListener(() {
      if (_isTypingTotal) {
        _updateBuyingPricePerItem();
      }
    });
  }

  void _updateTotalBuyingPrice() {
    final perItemText = _buyingPriceController.text;
    final quantityText = _quantityController.text;

    if (perItemText.isNotEmpty && quantityText.isNotEmpty) {
      final perItem = double.tryParse(perItemText.replaceAll(',', '')) ?? 0.0;
      final quantity = double.tryParse(quantityText) ?? 0.0;

      final total = perItem * quantity;

      setState(() {
        _totalBuyingPriceController.text = _formatNumber(total);
      });
    }
  }

  void _updateBuyingPricePerItem() {
    final totalText = _totalBuyingPriceController.text;
    final quantityText = _quantityController.text;

    if (totalText.isNotEmpty && quantityText.isNotEmpty) {
      final total = double.tryParse(totalText.replaceAll(',', '')) ?? 0.0;
      final quantity = double.tryParse(quantityText) ?? 0.0;

      if (quantity > 0) {
        final perItem = total / quantity;

        setState(() {
          _buyingPriceController.text = _formatNumber(perItem);
        });
      }
    }
  }

  String _formatNumber(double value) {
    // Check if the number is an integer
    if (value == value.toInt()) {
      return value.toInt().toString(); // Remove decimals for integers
    }
    return value.toStringAsFixed(2); // Keep two decimals for non-integers
  }


  void _updateBothPrices() {
    _updateTotalBuyingPrice();
    _updateBuyingPricePerItem();
  }


  void _loadCustomUnits() {
    // Load custom units from business 'units' field
    print('=== LOADING CUSTOM UNITS ===');
    print('Business units field: ${_businessController.business['units']}');
    
    // Try 'units' field first (seems to be the actual field name)
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
    } 
    // Fallback to additionalList1 if units field doesn't exist
    else if (_businessController.business['additionalList1'] != null) {
      List<String> customUnits = List<String>.from(_businessController.business['additionalList1']);
      print('Custom units found in additionalList1: $customUnits');
      setState(() {
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

  Future<void> requestPermissions() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    var cameraStatus = await Permission.camera.status;
    if (!cameraStatus.isGranted) {
      await Permission.camera.request();
    }
  }

  @override
  void dispose() {
    _productController.setCategory('No category'.tr);
    _productController.setManufacturer('No manufacturer'.tr);
    _productController.setLocation('No location'.tr);
    super.dispose();
  }




  Future<String?> uploadFile(String folder, File file) async {
    try {
      final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance.ref().child(path);
      uploadTask = ref.putFile(file);
      final snapshot = await uploadTask!.whenComplete(() => {});
      final url = await snapshot.ref.getDownloadURL();
      return url;
    } catch (e) {
      _showSnackbar('Upload failed: $e');
      throw Exception('File upload failed: $e');
    }
  }

  Future<void> pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {

        imageFile = File(pickedFile.path);
        // _showSnackbar('Image picked from gallery: ${pickedFile.path}');
      });
    }
  }
  /*
  Future<bool> checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result == ConnectivityResult.mobile || result == ConnectivityResult.wifi;
  }*/

  Future<void> pickImageFromCamera() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
        //  _showSnackbar('Image picked from camera: ${pickedFile.path}');
      });
    }
  }

  String _payment = _businessController.business['mainCurrency'];

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void _clearFields() {
    _nameController.clear();
    _codeController.clear();
    _priceController.clear();
    _categoryController.clear();
    _quantityController.clear();
    _detailsController.clear();
    _buyingPriceController.clear();
    _locationController.clear();
    _manufacturerController.clear();
    _underStockController.clear();
    _totalBuyingPriceController.clear();
    _discountController.clear();
    setState(() {
      imageFile = null;
    });
    _productController.setCategory('No category'.tr);
    _productController.setManufacturer('No manufacturer'.tr);
    _productController.setLocation('No location'.tr);

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
    _categoryController.text = _productController.selectedCategory.value;
    allUnits = [..._units];
    uniqueUnits=removeDuplicateUnits(allUnits);
    return WillPopScope(
      onWillPop: () async => isUploading ? false : true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
          Preferences.getTheme() ? darkGrayColor : primaryUltraLightColor,
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
            'new_product'.tr,
            style: TextStyle(
              color: Preferences.getTheme() ? primaryUltraLightColor : textDarkColor,
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
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
                                              await pickImageFromGallery();
                                              Navigator.pop(context);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.camera),
                                            title: Text('camera'.tr),
                                            onTap: () async {
                                              await pickImageFromCamera();
                                              Navigator.pop(context);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.close),
                                            title: Text('delete'.tr),
                                            onTap: () {
                                              setState(() {
                                                imageFile = null;
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
                                borderRadius: BorderRadius.circular(4),
                                child: imageFile != null
                                    ? Image.file(
                                  imageFile!,
                                  width: 86,
                                  height: 86,
                                  fit: BoxFit.cover,
                                )
                                    : Container(
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
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 44,
                            child: TextField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                labelText: '${'name'.tr}*',
                                labelStyle: bodyText(textPlaceholderColor),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(4),
                                  borderSide: BorderSide(
                                    color: _isNameEmpty ? Colors.red : Preferences.getTheme() ? mediumGrayColor : borderColor,
                                  ),
                                ),
                              ),
                            ),
                          ),


                          const SizedBox(height: 24),
                          Row(
                            children: [
                              // Quantity and unit fields (only for products)
                              if (_selectedItemType == 'product') ...[
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: TextField(
                                      controller: _quantityController,
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
                                          borderSide: BorderSide(
                                            color: _isQuantityEmpty ? Colors.red : Preferences.getTheme() ? mediumGrayColor : borderColor,
                                          ),
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
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Text('Buying Price Per Item:'.tr),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: Focus(
                                    onFocusChange: (hasFocus) {
                                      setState(() {
                                        _isTypingPerItem = hasFocus;
                                        _isTypingTotal = !hasFocus;
                                      });
                                    },
                                    child: TextField(
                                      controller: _buyingPriceController,
                                      enabled: _isQuantityEntered, // Disable if Quantity is empty
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(4),
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
                            children: [
                              Text('Buying Price Total:'.tr),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SizedBox(
                                  height: 44,
                                  child: Focus(
                                    onFocusChange: (hasFocus) {
                                      setState(() {
                                        _isTypingTotal = hasFocus;
                                        _isTypingPerItem = !hasFocus;
                                      });
                                    },
                                    child: TextField(
                                      controller: _totalBuyingPriceController,
                                      enabled: _isQuantityEntered, // Disable if Quantity is empty
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(4),
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
                                        borderSide: BorderSide(
                                          color: _isPriceEmpty ? Colors.red : Preferences.getTheme() ? mediumGrayColor : borderColor,
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
                            // Item type selection in additional details
                            Row(
                              children: [
                                Text('Item Type:'.tr),
                                const SizedBox(width: 16),
                                DropdownButton<String>(
                                  value: _selectedItemType,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'product',
                                      child: Text('Product'.tr),
                                    ),
                                    DropdownMenuItem(
                                      value: 'service',
                                      child: Text('Service'.tr),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedItemType = value!;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Understock, manufacturer, location fields (only for products)
                            if (_selectedItemType == 'product') ...[
                              SizedBox(
                                height: 44,
                                child: TextField(
                                  controller: _underStockController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
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
                                  onTap: () {
                                    showModalBottomSheet(
                                      isScrollControlled: true,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      context: context,
                                      builder: (context) => ProductManufacturerBottomSheet(
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
                            ],
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
                                        _categoryController.text = _productController.selectedCategory.value;
                                      },
                                    ),
                                  );
                                },
                                controller: _categoryController,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                  labelText: 'category'.tr,
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
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                        labelText: 'Qr/Bar code'.tr,
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
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 44,
                                    width: 44,
                                    child: IconButton(
                                      icon: const Icon(Icons.qr_code_scanner),
                                      tooltip: 'Scan QR/Barcode',
                                      onPressed: () async {
                                        final scannedCode = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => BarcodeScannerScreen(),
                                          ),
                                        );
                                        if (scannedCode != null && scannedCode is String) {
                                          setState(() {
                                            _codeController.text = scannedCode;
                                          });
                                        }
                                      },
                                    ),
                                  ),
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
                          const SizedBox(height: 44),
                          SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  _isNameEmpty = _nameController.text.isEmpty;
                                  _isPriceEmpty = _priceController.text.isEmpty;
                                  _isBuyingPriceEmpty = _buyingPriceController.text.isEmpty;
                                  if (_selectedItemType == 'product') {
                                    _isQuantityEmpty = _quantityController.text.isEmpty;
                                  } else {
                                    _isQuantityEmpty = false;
                                  }
                                });

                                // Validation: for service, only name, price, and buying price are required
                                if (!_isNameEmpty && !_isPriceEmpty && !_isBuyingPriceEmpty && (_selectedItemType == 'service' || !_isQuantityEmpty)) {
                                  double buyingPrice = double.parse(_buyingPriceController.text.replaceAll(',', ''));
                                  double sellingPrice = double.parse(_priceController.text.replaceAll(',', ''));

                                  if (buyingPrice >= sellingPrice) {
                                    _showSnackbar('Buying price must be less than selling price.'.tr);
                                    return;
                                  }

                                  isUploading = true;

                                  String? imageUrl;
                                  if (imageFile != null) {
                                    imageUrl = await uploadFile('gmanproducts', imageFile!).catchError((error) {
                                      _showSnackbar('Upload failed: $error');
                                    });
                                  }

                                  final String? businessId = _businessController.business['id'];

                                  if (businessId == null) {
                                    print('Owner ID is null, cannot add product.');
                                    setState(() {
                                      isUploading = false;
                                    });
                                    return;
                                  }

                                  try {
                                    bool existsCategory = _businessController.business['categories']
                                        .contains(_categoryController.text.trim());
                                    if (!existsCategory) {
                                      String trimmedCategory = _categoryController.text.trim();
                                      if (trimmedCategory.isNotEmpty) {
                                        firestore.collection('businesses').doc(businessId).update({
                                          'categories': FieldValue.arrayUnion([trimmedCategory]),
                                        });
                                      }
                                    }

                                    bool existsUnit = allUnits.contains(_selectedUnit);
                                    if (!existsUnit) {
                                      firestore.collection('businesses').doc(businessId).update({
                                        'additionalList1': FieldValue.arrayUnion([_selectedUnit]),
                                      });
                                    }

                                    final productRef = firestore
                                        .collection('products')
                                        .doc(businessId)
                                        .collection('userProducts')
                                        .doc();

                                    DateTime? expireDate = _expireDateController.text.trim().isNotEmpty
                                        ? DateTime.tryParse(_expireDateController.text.trim())
                                        : null;

                                    await saveProductToUserStore(
                                      understock: int.parse(
                                          _underStockController.text.trim().replaceAll(',', '').isEmpty
                                              ? '10'
                                              : _underStockController.text.trim().replaceAll(',', '')),
                                      owner: businessId,
                                      id: productRef.id,
                                      storeId: _businessController.business['owner'],
                                      code: _codeController.text.trim(),
                                      businessId: businessId,
                                      name: _nameController.text.trim(),
                                      buyingPrice: buyingPrice,
                                      details: _detailsController.text.trim(),
                                      imageUrl: imageUrl ?? '',
                                      price: sellingPrice,
                                      quantity: _selectedItemType == 'service' ? 1.0 : double.tryParse(_quantityController.text.trim().replaceAll(',', '')) ?? 0.0,
                                      manufacturer: _manufacturerController.text.trim(),
                                      location: _locationController.text.trim(),
                                      category: _categoryController.text.trim(),
                                      expireDate: expireDate,
                                    );

                                    await productRef.set({
                                      'id': productRef.id,
                                      'owner': businessId,
                                      'businessId': businessId,
                                      'manufacturer': _manufacturerController.text.trim(),
                                      'name': _nameController.text.trim(),
                                      'details': _detailsController.text.trim(),
                                      'location': _locationController.text.trim(),
                                      'buyingPrice': buyingPrice,
                                      'understock': int.parse(
                                          _underStockController.text.trim().replaceAll(',', '').isEmpty
                                              ? '10'
                                              : _underStockController.text.trim().replaceAll(',', '')),
                                      'discount': double.parse(
                                          _discountController.text.trim().replaceAll(',', '').isEmpty
                                              ? '0'
                                              : _discountController.text.trim().replaceAll(',', '')),
                                      'code': _codeController.text.trim(),
                                      'price': sellingPrice,
                                      'quantity': _selectedItemType == 'service' ? 1.0 : double.tryParse(_quantityController.text.trim().replaceAll(',', '')) ?? 0.0,
                                      'category': _categoryController.text.trim(),
                                      'image': imageUrl ?? '',
                                      'storeQuantity': 0,
                                      'reserveString1': _selectedUnit,
                                      'reserveString2': '',
                                      'reserveDouble1': 0.0,
                                      'reserveDouble2': 0.0,
                                      'reserveList1': [],
                                      'reserveList2': [],
                                      'expireDate': expireDate,
                                      'itemType': _selectedItemType, // Add itemType
                                    });

                                    await _productController.updateInitialTransaction(
                                      _selectedItemType == 'service' ? 1.0 : double.parse(_quantityController.text.trim().replaceAll(',', '')),
                                      productRef.id,
                                      sellingPrice,
                                    );

                                    _showSnackbar('Product added successfully!');
                                    _clearFields();
                                    _businessController.updateBusinessData();
                                  } catch (error) {
                                    Get.snackbar(
                                      'Error',
                                      '$error',
                                      snackPosition: SnackPosition.BOTTOM,
                                      duration: const Duration(seconds: 15),
                                      backgroundColor: Colors.red,
                                      colorText: Colors.white,
                                      margin: const EdgeInsets.all(10),
                                      borderRadius: 8,
                                    );
                                    print('Failed to add product or update initial transaction: $error');
                                  } finally {
                                    setState(() {
                                      isUploading = false;
                                    });
                                  }
                                } else {
                                  _showSnackbar('Please fill all required fields');
                                }
                              },
                              style: ButtonStyle(
                                backgroundColor: MaterialStateProperty.all<Color>(
                                  const Color(0xFF80B2FF),
                                ),
                              ),
                              child: Text(
                                'add_product'.tr,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isUploading)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> saveProductToUserStore({
    String? owner,
    String? id,
    required String storeId,
    required String businessId,
    required String name,
    required double buyingPrice,
    required double price,
    required double quantity,
    String? manufacturer,
    String? details,
    String? location,
    int? understock,
    String? code,
    String? category,
    String? imageUrl,
    String? reserveString1,
    String? reserveString2,
    double? reserveDouble1,
    double? reserveDouble2,
    List<dynamic>? reserveList1,
    List<dynamic>? reserveList2,
    DateTime? expireDate,
    double? discount,
  }) async {
    const String functionUrl = 'https://us-central1-hesabumauzo.cloudfunctions.net/saveProductToUserStore'; // Replace with the function's actual URL

    // Create the request payload
    final Map<String, dynamic> data = {
      'id':id,
      'storeId': storeId,
      'businessId': businessId,
      'manufacturer': manufacturer,
      'name': name,
      'details': details,
      'location': location,
      'buyingPrice': buyingPrice,
      'understock': understock,
      'code': code,
      'price': price,
      'quantity': quantity,
      'category': category,
      'imageUrl': imageUrl,
      'reserveString1': reserveString1,
      'reserveString2': reserveString2,
      'reserveDouble1': reserveDouble1,
      'reserveDouble2': reserveDouble2,
      'reserveList1': reserveList1,
      'reserveList2': reserveList2,
      'discount':discount,
    };

    try {
      // Make the POST request to the Cloud Function
      final response = await http.post(
        Uri.parse(functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      // Check if the request was successful
      if (response.statusCode == 200) {
        print("Product saved successfully: ${response.body}");
      } else {
        print("Failed to save product: ${response.body}");
      }
    } catch (e) {
      print("Error calling Cloud Function: $e");
    }
  }

  Future<void> _showAddUnitDialog(BuildContext context) async {


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
                controller: newUnitController,
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
                          if (newUnitController.text.isNotEmpty) {
                            final String newUnit = newUnitController.text.trim();
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
                              newUnitController.clear();
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