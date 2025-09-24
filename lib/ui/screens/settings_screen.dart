import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/auth_controller.dart';
import 'package:mauzo/controllers/theme_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/ui/widgets/bottomsheets/discount_allow_bottom_sheet.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../controllers/transaction_controller.dart';
import '../../controllers/bought_controller.dart';
import '../../controllers/business_controller.dart';
import '../../controllers/business_list_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/client_controller.dart';
import '../../controllers/closed_books_controller.dart';
import '../../controllers/debt_history_controller.dart';
import '../../controllers/employee_controller.dart';
import '../../controllers/expence_controller.dart';
import '../../controllers/invoice_controller.dart';
import '../../controllers/product_controller.dart';
import '../../controllers/sale_controller.dart';
import '../../controllers/store_controller.dart';
import '../../models/themes_model.dart';
import '../../utils/constants.dart';
import '../../utils/image.dart';
import '../widgets/buttons/primary_button.dart';
import 'package:http/http.dart' as http;

import '../widgets/dialogs/edit_business_dialog.dart';
import '../widgets/dialogs/edit_discount_dialog.dart';
import '../widgets/dialogs/edit_expire_warning_dialog.dart';
import '../widgets/dialogs/edit_tin_dialog.dart';
import '../widgets/dialogs/edit_user_dialog.dart';
import '../widgets/dialogs/edit_phone_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  File? logoFile;
  UploadTask? uploadTask;
  bool isUploading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ThemeController _themeController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();
  final AuthController _authController = Get.find();

  final BusinessListController _businessListController = Get.find();
  final StoreController _storeController = Get.find();
  final BoughtController _boughtController = Get.find();
  final DebtHistoryController _debtHistoryController = Get.find();
  final InvoiceController _invoiceController = Get.find();
  final ExpenseController _expenseController = Get.find();
  final ProductController _productController = Get.find();
  final TransactionController _transactionController = Get.find();
  final ClientController _clientController = Get.find();
  final SaleController _saleController = Get.find();
  final CartController _cartController = Get.find();
  final EmployeeController _employeeController = Get.find();
  final ClosedBooksController _closedBooksController = Get.find();

  String formatNumberSync(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) return '';
    
    // Remove any non-digit characters
    String digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Handle different country codes
    if (digits.startsWith('255')) {
      return '+255 ${digits.substring(3, 6)} ${digits.substring(6)}';
    } else if (digits.startsWith('254')) {
      return '+254 ${digits.substring(3, 6)} ${digits.substring(6)}';
    } else if (digits.startsWith('256')) {
      return '+256 ${digits.substring(3, 6)} ${digits.substring(6)}';
    } else if (digits.startsWith('250')) {
      return '+250 ${digits.substring(3, 6)} ${digits.substring(6)}';
    } else if (digits.startsWith('257')) {
      return '+257 ${digits.substring(3, 6)} ${digits.substring(6)}';
    } else if (digits.startsWith('1')) {
      // US format: +1 (XXX) XXX-XXXX
      if (digits.length >= 10) {
        return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7, 11)}';
      }
    }
    
    // If no country code matches, return the original number
    return phoneNumber;
  }

  Future<String> uploadFile(String folder, File file) async {
    try {
      final path = '$folder/${DateTime.now().millisecondsSinceEpoch}.png';
      final ref = FirebaseStorage.instance.ref().child(path);
      uploadTask = ref.putFile(file);
      final snapshot = await uploadTask!.whenComplete(() => {});
      final url = await snapshot.ref.getDownloadURL();
      print('Uploaded logo URL: $url');
      return url;
    } catch (e) {
      print('Error uploading logo to Firebase Storage: $e');
      throw e;
    }
  }

  bool hasMultipleBusinesses() {
    List businesses = _profileController.user['business'] ?? [];
    return businesses.length > 1;
  }

  PackageInfo _packageInfo = PackageInfo(
    appName: 'Unknown',
    packageName: 'Unknown',
    version: 'Unknown',
    buildNumber: 'Unknown',
    buildSignature: 'Unknown',
  );

  @override
  void initState() {
    super.initState();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> syncProductsAcrossAllBusinesses() async {
    const String cloudFunctionUrl = "https://us-central1-hesabumauzo.cloudfunctions.net/syncProductsAcrossAllBusinesses";
    try {
      final headers = {"Content-Type": "application/json"};
      final body = jsonEncode({"userId": _profileController.user['id']});
      final response = await http.post(
        Uri.parse(cloudFunctionUrl),
        headers: headers,
        body: body,
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print("Sync success: ${responseData['message']}");
        successSnackbar('Copy Completed');
      } else {
        final errorData = jsonDecode(response.body);
        print("Error: ${errorData['error']}");
      }
    } catch (e) {
      print("Exception: $e");
    }
  }

  Future<void> deleteAllControllers() async {
    _businessListController.clearBusiness();
    _boughtController.clearBought();
    _debtHistoryController.clearDebt();
    _invoiceController.clearInvoice();
    _storeController.clearStore();
    _expenseController.clearExpense();
    _productController.clearProducts();
    _clientController.clearClients();
    _saleController.clearSales();
    _employeeController.clearEmployee();
    _closedBooksController.clearBooks();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => isUploading ? false : true,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          title: Text('settings'.tr),
          leading: isUploading
              ? Container()
              : IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            isUploading
                ? Container()
                : IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => DoubleActionDialog(
                    title: 'logout'.tr,
                    content: 'logout_confirmation'.tr,
                    confirm: 'logout'.tr,
                    cancel: 'cancel'.tr,
                    onConfirm: () async {
                      await deleteAllControllers();
                      Preferences.setTheme(false);
                      Preferences.setLoggedIn(false);
                      ThemeController().changeTheme(ThemeMode.light, Themes.lightTheme);
                      _authController.logout();
                    },
                    onCancel: () {
                      Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ],
        ),
        body: isUploading
            ? const Center(child: CircularProgressIndicator())
            : Obx(
              () => SingleChildScrollView(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      height: 62,
                      width: double.maxFinite,
                      color: primaryColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 20.0, top: 20),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('select_logo_source'.tr),
                              content: SizedBox(
                                height: 180,
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.collections),
                                      title: Text('gallery'.tr),
                                      onTap: () async {
                                        setState(() {
                                          isUploading = true;
                                        });
                                        try {
                                          logoFile = await pickImageFromGallery();
                                          if (logoFile == null) {
                                            print('No logo selected from gallery');
                                            setState(() {
                                              isUploading = false;
                                            });
                                            return;
                                          }
                                          print('Logo picked from gallery: ${logoFile!.path}');
                                          Navigator.pop(context);

                                          String url = await uploadFile('logos', logoFile!);
                                          await _firestore
                                              .collection('businesses')
                                              .doc(_businessController.business['id'])
                                              .update({'logo': url});
                                          print('Firestore updated with logo URL: $url');
                                          _businessController.updateBusinessData();
                                          successSnackbar('Logo Uploaded Successfully');
                                        } catch (e) {
                                          print('Error uploading logo: $e');
                                          Get.snackbar('Error', 'Failed to upload logo: $e',
                                              backgroundColor: Colors.red, colorText: Colors.white);
                                        } finally {
                                          setState(() {
                                            isUploading = false;
                                          });
                                        }
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.camera),
                                      title: Text('camera'.tr),
                                      onTap: () async {
                                        setState(() {
                                          isUploading = true;
                                        });
                                        try {
                                          logoFile = await pickImageFromCamera();
                                          if (logoFile == null) {
                                            print('No logo captured from camera');
                                            setState(() {
                                              isUploading = false;
                                            });
                                            return;
                                          }
                                          print('Logo captured from camera: ${logoFile!.path}');
                                          Navigator.pop(context);

                                          String url = await uploadFile('logos', logoFile!);
                                          await _firestore
                                              .collection('businesses')
                                              .doc(_businessController.business['id'])
                                              .update({'logo': url});
                                          print('Firestore updated with logo URL: $url');
                                          _businessController.updateBusinessData();
                                          successSnackbar('Logo Uploaded Successfully');
                                        } catch (e) {
                                          print('Error uploading logo: $e');
                                          Get.snackbar('Error', 'Failed to upload logo: $e',
                                              backgroundColor: Colors.red, colorText: Colors.white);
                                        } finally {
                                          setState(() {
                                            isUploading = false;
                                          });
                                        }
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.close),
                                      title: Text('delete'.tr),
                                      onTap: () async {
                                        setState(() {
                                          isUploading = true;
                                        });
                                        try {
                                          logoFile = null;
                                          await _firestore
                                              .collection('businesses')
                                              .doc(_businessController.business['id'])
                                              .update({'logo': ''});
                                          print('Logo removed from Firestore');
                                          _businessController.updateBusinessData();
                                          Navigator.pop(context);
                                          successSnackbar('Logo Removed Successfully');
                                        } catch (e) {
                                          print('Error removing logo: $e');
                                          Get.snackbar('Error', 'Failed to remove logo: $e',
                                              backgroundColor: Colors.red, colorText: Colors.white);
                                        } finally {
                                          setState(() {
                                            isUploading = false;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: whiteColor, width: 1),
                          ),
                          child: logoFile != null
                              ? Container(
                            decoration: BoxDecoration(
                              color: gray200Color,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            width: 80,
                            height: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: Image.file(
                                logoFile!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('Error displaying logo from file: $error');
                                  return const Icon(Icons.error, color: Colors.red);
                                },
                              ),
                            ),
                          )
                              : _businessController.business['logo'] != null &&
                              _businessController.business['logo'] != ''
                              ? Container(
                            decoration: BoxDecoration(
                              color: gray200Color,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            width: 80,
                            height: 80,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(100),
                              child: CachedNetworkImage(
                                imageUrl: _businessController.business['logo'],
                                placeholder: (context, url) =>
                                const CircularProgressIndicator(),
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) {
                                  print('Error loading logo from URL: $error');
                                  return const Icon(Icons.error, color: Colors.red);
                                },
                              ),
                            ),
                          )
                              : const CircleAvatar(
                            radius: 40,
                            backgroundColor: gray100Color,
                            child: Icon(
                              Icons.business,
                              color: iconGrayColor,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Rest of the UI remains unchanged
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_profileController.user['role'] == 'owner') {
                        showDialog(
                          context: context,
                          builder: (_) => EditUserDialog(
                            info: _profileController.user['name'],
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'name'.tr,
                          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        Row(
                          children: [
                            Text(
                              _profileController.user['name'],
                              style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.edit,
                              size: 20,
                              color: gray400Color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    onTap: () {
                      if (_profileController.user['role'] == 'owner') {
                        showDialog(
                          context: context,
                          builder: (_) => EditBusinessDialog(
                            info: 'business_name'.tr,
                          ),
                        );
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'business_name'.tr,
                          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        Row(
                          children: [
                            Text(
                              _businessController.business['name'],
                              style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.edit,
                              size: 20,
                              color: gray400Color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_profileController.user['role'] == 'owner') {
                        showDialog(
                          context: context,
                          builder: (_) => const EditTinDialog(),
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TIN number'.tr,
                          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        Row(
                          children: [
                            Text(
                              _businessController.business['tin'],
                              style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.edit,
                              size: 20,
                              color: gray400Color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_profileController.user['role'] == 'owner') {
                        showDialog(
                          context: context,
                          builder: (_) => const EditExpireDialog(),
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'expireWarning'.tr,
                          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        Row(
                          children: [
                            Text(
                              _businessController.business['expireWarning'].toString(),
                              style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.edit,
                              size: 20,
                              color: gray400Color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_profileController.user['role'] == 'owner') {
                        showDialog(
                          context: context,
                          builder: (_) => const DiscountPercentDialog(),
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'discountPercent'.tr,
                          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        Row(
                          children: [
                            Text(
                              _businessController.business['discountPercent'].toString(),
                              style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.edit,
                              size: 20,
                              color: gray400Color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'email'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      Text(
                        _profileController.user['email'] ?? 'N/A',
                        style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_profileController.user['role'] == 'owner') {
                        final TextEditingController countryCodeController = TextEditingController(
                          text: _businessController.business['phone']!.toString().startsWith('+255') ? '255' :
                                _businessController.business['phone']!.toString().startsWith('+254') ? '254' :
                                _businessController.business['phone']!.toString().startsWith('+256') ? '256' :
                                _businessController.business['phone']!.toString().startsWith('+250') ? '250' :
                                _businessController.business['phone']!.toString().startsWith('+257') ? '257' :
                                _businessController.business['phone']!.toString().startsWith('+1') ? '1' : '255',
                        );
                        final TextEditingController phoneController = TextEditingController(
                          text: _businessController.business['phone']!.toString().replaceAll(RegExp(r'[^0-9]'), '')
                                .replaceFirst(RegExp(r'^(255|254|256|250|257|1)'), ''),
                        );

                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('Edit Phone Number'.tr),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 80,
                                      child: TextField(
                                        controller: countryCodeController,
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                          labelText: 'Country Code',
                                          counterText: '',
                                          prefix: Text(
                                            '+',
                                            style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        maxLength: 3,
                                        keyboardType: TextInputType.phone,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: phoneController,
                                        keyboardType: TextInputType.phone,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          LengthLimitingTextInputFormatter(10),
                                        ],
                                        decoration: InputDecoration(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                          labelText: '${'phone'.tr}*',
                                          counterText: '',
                                          border: const OutlineInputBorder(
                                            borderSide: BorderSide(color: borderColor),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text('Cancel'.tr),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () async {
                                        String newCountryCode = countryCodeController.text;
                                        String newPhoneNumber = phoneController.text;
                                        
                                        if (newPhoneNumber.isEmpty) {
                                          errorSnackbar('Please enter a phone number');
                                          return;
                                        }

                                        String formattedPhone = '+$newCountryCode$newPhoneNumber';
                                        
                                        try {
                                          await _firestore
                                              .collection('businesses')
                                              .doc(_businessController.business['id'])
                                              .update({'phone': formattedPhone});
                                          
                                          _businessController.updateBusinessData();
                                          Navigator.pop(context);
                                          successSnackbar('Phone number updated successfully');
                                        } catch (e) {
                                          errorSnackbar('Failed to update phone number: $e');
                                        }
                                      },
                                      child: Text('Save'.tr),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'phone'.tr,
                          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        Row(
                          children: [
                            Text(
                              formatNumberSync(_businessController.business['phone']),
                              style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.edit,
                              size: 20,
                              color: gray400Color,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: 12,
                  child: Container(
                    color: Preferences.getTheme() == false
                        ? const Color(0xFFF2F2F2)
                        : darkGrayColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'main_currency'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      Row(
                        children: [
                          Text(
                            _businessController.business['mainCurrency'],
                            style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                          ),
                          const SizedBox(width: 18),
                          const Icon(
                            Icons.unfold_more,
                            size: 20,
                            color: gray400Color,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 12,
                  child: Container(
                    color: Preferences.getTheme() == false
                        ? const Color(0xFFF2F2F2)
                        : darkGrayColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Allow Debt'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      if (_profileController.user['role'] == 'owner')
                        Switch(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          activeColor: primaryLightColor,
                          value: Preferences.getEnableDebt(),
                          onChanged: (value) async {
                            setState(() {
                              Preferences.setEnabletDebt(value);
                            });
                            String businessId = _businessController.business['id'];
                            await FirebaseFirestore.instance
                                .collection('businesses')
                                .doc(businessId)
                                .update({'debtEnabled': value}).then((_) {
                              successSnackbar('Changes made Successfully');
                              print("debtEnabled updated successfully");
                            }).catchError((error) {
                              print("Failed to update debtEnabled: $error");
                            });
                            _businessController.updateBusinessData();
                          },
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Allow Purchases'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      if (_profileController.user['role'] == 'owner')
                        Switch(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          activeColor: primaryLightColor,
                          value: Preferences.isPurchasesEnabled(),
                          onChanged: (bool value) async {
                            setState(() {
                              Preferences.setEnablePurchases(value ? 'true' : 'false');
                            });
                            String businessId = _businessController.business['id'];
                            await FirebaseFirestore.instance
                                .collection('businesses')
                                .doc(businessId)
                                .update({'additionalString1': value ? 'true' : 'false'})
                                .then((_) {
                              successSnackbar('Changes made Successfully');
                              print("purchases updated successfully");
                            }).catchError((error) {
                              print("Failed to update additionalString1: $error");
                            });
                            _businessController.updateBusinessData();
                          },
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 12,
                  child: Container(
                    color: Preferences.getTheme() == false
                        ? const Color(0xFFF2F2F2)
                        : darkGrayColor,
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'dark_mode'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      Switch(
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        activeColor: primaryLightColor,
                        value: Preferences.getTheme(),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _themeController.changeTheme(ThemeMode.dark, Themes.darkTheme);
                            } else {
                              _themeController.changeTheme(ThemeMode.light, Themes.lightTheme);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 0),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => SimpleDialog(
                          title: Text(
                            'select_language'.tr,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          children: [
                            SimpleDialogOption(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              onPressed: () {
                                Preferences.setLanguage('kiswahili');
                                Get.updateLocale(const Locale('sw', 'TZ'));
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Kiswahili',
                                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                            ),
                            SimpleDialogOption(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              onPressed: () {
                                Preferences.setLanguage('english');
                                Get.updateLocale(const Locale('en', 'US'));
                                Navigator.pop(context);
                              },
                              child: Text(
                                'English',
                                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                            ),
                            SimpleDialogOption(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              onPressed: () {
                                Preferences.setLanguage('spanish');
                                Get.updateLocale(const Locale('es', 'ES'));
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Español',
                                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                            ),
                            SimpleDialogOption(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              onPressed: () {
                                Preferences.setLanguage('russian');
                                Get.updateLocale(const Locale('ru', 'RU'));
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Русский',
                                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                            ),
                            SimpleDialogOption(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              onPressed: () {
                                Preferences.setLanguage('uzbek');
                                Get.updateLocale(const Locale('uz', 'UZ'));
                                Navigator.pop(context);
                              },
                              child: Text(
                                "O'zbek",
                                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'language'.tr,
                          style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        Row(
                          children: [
                            Text(
                              '${Preferences.getLanguage()}'.tr,
                              style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                            const SizedBox(width: 18),
                            const Icon(
                              Icons.unfold_more,
                              size: 20,
                              color: gray400Color,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Role'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      Text(
                        (_profileController.user['role'] ?? 'employee').toString().capitalizeFirst!,
                        style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Version'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      Text(
                        '1.7',
                        style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),
                if (hasMultipleBusinesses())
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
                                bool? confirmed = await showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: Text('Confirm Copy'.tr),
                                      content: Text('This will make products in all your business equal except for the quantity'.tr),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(false);
                                          },
                                          child: Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(true);
                                          },
                                          child: Text('Confirm'.tr),
                                        ),
                                      ],
                                    );
                                  },
                                );
                                if (confirmed == true) {
                                  syncProductsAcrossAllBusinesses();
                                }
                              },
                              text: 'Copy Products'.tr,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}