import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../models/supplier_model.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../../widgets/buttons/primary_button.dart';

class EditSupplierScreen extends StatefulWidget {
  const EditSupplierScreen({Key? key}) : super(key: key);

  @override
  State<EditSupplierScreen> createState() => _EditSupplierScreenState();
}

class _EditSupplierScreenState extends State<EditSupplierScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _taxNumberController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  File? imageFile;
  UploadTask? uploadTask;
  bool isUploading = false;
  Supplier? supplier;

  @override
  void initState() {
    super.initState();
    
    // CRITICAL SECURITY CHECK: Verify user has permission to manage suppliers
    if (!_profileController.hasPermission('manage_suppliers')) {
      print('🚨 UNAUTHORIZED ACCESS BLOCKED: User tried to access EditSupplierScreen without manage_suppliers permission');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'You do not have permission to edit suppliers',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }

    final role = (_profileController.user['role'] ?? '').toString();
    if (!_businessController.isPurchasesAllowedForRole(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pop();
        Get.snackbar(
          'Access Denied',
          'Suppliers are available to the owner, or to staff when Allow Purchases is enabled in settings.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      });
      return;
    }

    // Get supplier from arguments
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      
      print('📥 EditSupplierScreen arguments received: $args');
      print('📥 Arguments type: ${args.runtimeType}');
      
      if (args is Supplier) {
        supplier = args;
        print('✅ Supplier object assigned: ${supplier!.name}');
        _populateFields();
      } else {
        print('❌ Arguments are not a Supplier object');
        errorSnackbar('Supplier data not received. Please try again.');
        Navigator.pop(context);
      }
    });
  }

  void _populateFields() {
    if (supplier != null) {
      setState(() {
        _nameController.text = supplier!.name;
        _phoneController.text = supplier!.phone;
        _emailController.text = supplier!.email ?? '';
        _addressController.text = supplier!.address ?? '';
        _companyController.text = supplier!.company ?? '';
        _taxNumberController.text = supplier!.taxNumber ?? '';
        _noteController.text = supplier!.note ?? '';
      });
      print('✅ Supplier fields populated: ${supplier!.name}');
    } else {
      print('❌ Supplier is null, cannot populate fields');
    }
  }

  Future<String?> uploadFile(String folder, File file) async {
    try {
      final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance.ref().child(path);
      uploadTask = ref.putFile(file);

      final snapshot = await uploadTask!.whenComplete(() {});
      final urlDownload = await snapshot.ref.getDownloadURL();
      return urlDownload;
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<void> pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> pickImageFromCamera() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      setState(() {
        imageFile = File(pickedFile.path);
      });
    }
  }

  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('edit_supplier'.tr),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Image picker section
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    builder: (context) => Container(
                      height: 120,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.photo_library),
                            title: Text('gallery'.tr),
                            onTap: () {
                              Navigator.pop(context);
                              pickImageFromGallery();
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.camera_alt),
                            title: Text('camera'.tr),
                            onTap: () {
                              Navigator.pop(context);
                              pickImageFromCamera();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: gray200Color,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: imageFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(50),
                          child: Image.file(
                            imageFile!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : (supplier?.image != null && supplier!.image!.isNotEmpty)
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(50),
                              child: Image.network(
                                supplier!.image!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.business,
                                  size: 50,
                                  color: iconGrayColor,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.business,
                              size: 50,
                              color: iconGrayColor,
                            ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Name field (required)
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${'name'.tr} *',
                  contentPadding: inputPadding,
                  filled: true,
                  fillColor: Preferences.getTheme() ? darkGrayColor : gray100Color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Company field
              TextField(
                controller: _companyController,
                decoration: InputDecoration(
                  labelText: 'company'.tr,
                  contentPadding: inputPadding,
                  filled: true,
                  fillColor: Preferences.getTheme() ? darkGrayColor : gray100Color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Phone field (required)
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: '${'phone'.tr} *',
                  contentPadding: inputPadding,
                  filled: true,
                  fillColor: Preferences.getTheme() ? darkGrayColor : gray100Color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'email'.tr,
                  contentPadding: inputPadding,
                  filled: true,
                  fillColor: Preferences.getTheme() ? darkGrayColor : gray100Color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Address field
              TextField(
                controller: _addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'address'.tr,
                  contentPadding: inputPadding,
                  filled: true,
                  fillColor: Preferences.getTheme() ? darkGrayColor : gray100Color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Tax Number field
              TextField(
                controller: _taxNumberController,
                decoration: InputDecoration(
                  labelText: 'tax_number'.tr,
                  contentPadding: inputPadding,
                  filled: true,
                  fillColor: Preferences.getTheme() ? darkGrayColor : gray100Color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Note field
              TextField(
                controller: _noteController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'note'.tr,
                  contentPadding: inputPadding,
                  filled: true,
                  fillColor: Preferences.getTheme() ? darkGrayColor : gray100Color,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Save button
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      onPressed: isUploading ? null : () async {
                        try {
                          if (_nameController.text.isEmpty || _phoneController.text.isEmpty) {
                            errorSnackbar('fill_required_fields'.tr);
                            return;
                          }
                          
                          if (_emailController.text.isNotEmpty && !isValidEmail(_emailController.text)) {
                            errorSnackbar('Invalid email format.');
                            return;
                          }

                          if (supplier == null) {
                            print('❌ Supplier is null during save attempt');
                            errorSnackbar('Supplier information not found. Please go back and try again.');
                            return;
                          }
                          
                          print('✅ Saving supplier: ${supplier!.name} (ID: ${supplier!.id})');

                          setState(() {
                            isUploading = true;
                          });

                          String? imageUrl = supplier!.image;
                          if (imageFile != null) {
                            imageUrl = await uploadFile('suppliers', imageFile!);
                          }

                          final String? businessId = _businessController.business['id'];
                          if (businessId == null) {
                            print('Business ID is null, cannot update supplier.');
                            setState(() {
                              isUploading = false;
                            });
                            return;
                          }

                          // Update supplier document
                          await firestore
                              .collection('suppliers')
                              .doc(businessId)
                              .collection('userSuppliers')
                              .doc(supplier!.id)
                              .update({
                            'name': _nameController.text,
                            'company': _companyController.text.isEmpty ? null : _companyController.text,
                            'phone': _phoneController.text,
                            'email': _emailController.text.isEmpty ? null : _emailController.text,
                            'address': _addressController.text.isEmpty ? null : _addressController.text,
                            'taxNumber': _taxNumberController.text.isEmpty ? null : _taxNumberController.text,
                            'note': _noteController.text.isEmpty ? null : _noteController.text,
                            'image': imageUrl,
                          });

                          setState(() {
                            isUploading = false;
                          });

                          if (mounted) {
                            Navigator.pop(context);
                          }
                          successSnackbar('Supplier updated successfully.');
                        } catch (e) {
                          setState(() {
                            isUploading = false;
                          });
                          errorSnackbar('something_went_wrong'.tr);
                          print('Error updating supplier: $e');
                        }
                      },
                      text: isUploading ? 'saving'.tr : 'save'.tr,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
