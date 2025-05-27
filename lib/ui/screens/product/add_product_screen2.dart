import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pattern_formatter/numeric_formatter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../../widgets/bottomsheets/product_category_bottom_sheet.dart';
import '../../widgets/bottomsheets/product_location_bottom_sheet.dart';
import '../../widgets/bottomsheets/product_manufacturer_bottom_sheet.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({Key? key}) : super(key: key);

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final ProductController _productController = Get.find();
  static final BusinessController _businessController = Get.find();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  final TextEditingController _buyingPriceController = TextEditingController();
  final TextEditingController _underStockController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  bool _isNameEmpty = false;
  bool _isQuantityEmpty = false;
  bool _isPriceEmpty = false;
  bool _isBuyingPriceEmpty = false;
  bool _isCategoryEmpty = false;
  bool _isManufacturerEmpty = false;
  bool _isLocationEmpty = false;
  bool showAdditionalFields = false; // State to track visibility of additional fields
  File? imageFile;
  UploadTask? uploadTask;
  bool isUploading = false;

  @override
  void initState() {
    super.initState();
    requestPermissions();
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
    setState(() {
      imageFile = null;
    });
    _productController.setCategory('No category'.tr);
    _productController.setManufacturer('No manufacturer'.tr);
    _productController.setLocation('No location'.tr);

  }

  @override
  Widget build(BuildContext context) {
    _categoryController.text = _productController.selectedCategory.value;
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
            SingleChildScrollView(
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
                    SizedBox(
                      height: 44,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                labelText: 'code'.tr,
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
                        ],
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
                              inputFormatters: [
                                ThousandsFormatter(allowFraction: true)
                              ],
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
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Text(
                          '${'buyingPrice'.tr}: *',
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

                    const SizedBox(height: 24),
                    SizedBox(
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
                            _isQuantityEmpty = _quantityController.text.isEmpty;
                            _isPriceEmpty = _priceController.text.isEmpty;
                            _isBuyingPriceEmpty = _buyingPriceController.text.isEmpty;
                          });

                          if (!_isNameEmpty && !_isQuantityEmpty && !_isPriceEmpty && !_isBuyingPriceEmpty) {
                            double buyingPrice = double.parse(_buyingPriceController.text.replaceAll(',', ''));
                            double sellingPrice = double.parse(_priceController.text.replaceAll(',', ''));

                            // Check if buying price is less than the selling price
                            if (buyingPrice >= sellingPrice) {
                              _showSnackbar('Buying price must be less than selling price.'.tr);
                              return;
                            }

                            isUploading = true;

                            String? imageUrl;
                            if (imageFile != null) {
                              imageUrl = await uploadFile('products', imageFile!).catchError((error) {
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
                              // Check if category exists, and add it if it doesn't
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

                              // Check if manufacturer exists, and add it if it doesn't
                              bool existsManufacturer = _businessController.business['manufacturer']
                                  .contains(_manufacturerController.text.trim());
                              if (!existsManufacturer) {
                                String trimmedManufacturer = _manufacturerController.text.trim();
                                if (trimmedManufacturer.isNotEmpty) {
                                  firestore.collection('businesses').doc(businessId).update({
                                    'manufacturer': FieldValue.arrayUnion([trimmedManufacturer]),
                                  });
                                }
                              }

                              // Check if location exists, and add it if it doesn't
                              bool existsLocation = _businessController.business['location']
                                  .contains(_locationController.text.trim());
                              if (!existsLocation) {
                                String trimmedLocation = _locationController.text.trim();
                                if (trimmedLocation.isNotEmpty) {
                                  firestore.collection('businesses').doc(businessId).update({
                                    'location': FieldValue.arrayUnion([trimmedLocation]),
                                  });
                                }
                              }

                              // Create a document reference for the new product
                              final productRef = firestore
                                  .collection('products')
                                  .doc(businessId)
                                  .collection('userProducts')
                                  .doc(); // Generate a new document ID

                              // Set the new product data in Firestore
                              productRef.set({
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
                                'code': _codeController.text.trim(),
                                'price': sellingPrice,
                                'quantity': int.parse(_quantityController.text.trim().replaceAll(',', '')),
                                'total': int.parse(_quantityController.text.trim().replaceAll(',', '')),
                                'category': _categoryController.text.trim(),
                                'image': imageUrl ?? '',

                                // New fields with default values
                                'storeQuantity': 0, // Default store quantity set to 0
                                'reserveString1': '', // Default empty string for reserveString1
                                'reserveString2': '', // Default empty string for reserveString2
                                'reserveDouble1': 0.0, // Default value for reserveDouble1
                                'reserveDouble2': 0.0, // Default value for reserveDouble2
                                'reserveList1': [], // Default empty list for reserveList1
                                'reserveList2': [], // Default empty list for reserveList2
                              });

                              // Update the initial transaction after the product is added
                              _productController.updateInitialTransaction(
                                  int.parse(_quantityController.text.trim().replaceAll(',', '')) as double, productRef.id,6);

                              _showSnackbar('Product added successfully!');
                              _clearFields();
                            } catch (error) {
                              Get.snackbar(
                                'Error',
                                '$error',
                                snackPosition: SnackPosition.BOTTOM,
                                duration: Duration(seconds: 15),
                                backgroundColor: Colors.red,
                                colorText: Colors.white,
                                margin: EdgeInsets.all(10),
                                borderRadius: 8,
                              );
                              print('Failed to add product or update initial transaction: $error');
                            } finally {
                              setState(() {
                                isUploading = false;
                              });
                            }

                            // Update business data after everything is done
                            _businessController.updateBusinessData();
                          } else {
                            _showSnackbar('Please fill all required fields');
                          }
                        }

                        ,
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                              const Color(0xFF80B2FF)),
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
            if (isUploading)
              Container(
                color: Colors.white.withOpacity(0.7),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}