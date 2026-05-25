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
import 'package:mauzo/services/referral_attribution_service.dart';
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

import '../widgets/bottomsheets/currency_picker_bottom_sheet.dart';
import 'settings/fund_and_payment_settings.dart';
import '../widgets/dialogs/edit_discount_dialog.dart';
import '../widgets/dialogs/edit_expire_warning_dialog.dart';
import '../widgets/dialogs/edit_receipt_footer_dialog.dart';
import '../../utils/receipt_footer.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _profileController.refreshUserData();
      await _businessController.updateBusinessData();
    });
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  Future<void> _saveManualReferralCode(String raw) async {
    final normalized = ReferralAttributionService.normalizeReferrerCode(raw);
    if (normalized == null) {
      errorSnackbar('referral_code_invalid'.tr);
      return;
    }
    final uid = (_profileController.user['id'] ?? '').toString();
    if (uid.isEmpty) return;
    try {
      await _firestore.collection('gmanusers').doc(uid).set(
        {
          'installReferrerCode': normalized,
          'installReferrerAttributedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      if (_profileController.user['role'] == 'owner') {
        final bid =
            (_businessController.business['id'] ?? '').toString().trim();
        if (bid.isNotEmpty) {
          await _firestore.collection('businesses').doc(bid).set(
            {
              'installReferrerCode': normalized,
              'installReferrerAttributedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      }
      await _profileController.refreshUserData();
      await _businessController.updateBusinessData();
      if (!mounted) return;
      setState(() {});
      successSnackbar('referral_code_saved'.tr);
    } catch (e) {
      errorSnackbar(e.toString());
    }
  }

  void _showAddReferralCodeDialog() {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('referral_code_dialog_title'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'referral_code_dialog_hint'.tr,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(ctx).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'e.g. AGENT01',
              ),
              onSubmitted: (v) {
                Navigator.pop(ctx);
                _saveManualReferralCode(v);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveManualReferralCode(ctrl.text);
            },
            child: Text('referral_code_save'.tr),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
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
                // Business profile (name, TIN, phone, etc.) is under Account Status.
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_profileController.user['role'] == 'owner') {
                        showDialog(
                          context: context,
                          builder: (_) => const EditReceiptFooterDialog(),
                        );
                      }
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'receipt_footer_message'.tr,
                            style: bodyText(
                                Theme.of(context).textTheme.bodyMedium!.color),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  receiptFooterMessage(
                                    Map<String, dynamic>.from(
                                        _businessController.business),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: bodyText(Theme.of(context)
                                      .textTheme
                                      .bodyLarge!
                                      .color),
                                ),
                              ),
                              const SizedBox(width: 18),
                              const Icon(
                                Icons.edit,
                                size: 20,
                                color: gray400Color,
                              ),
                            ],
                          ),
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
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (_profileController.user['role'] != 'owner') return;
                      // Seed the auth controller with the current value so the
                      // picker shows it as selected, then use isAuth:true path.
                      _authController.mainCurrency.value =
                          _businessController.business['mainCurrency'] ?? 'TZS';
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                        builder: (_) =>
                            const CurrencyPickerBottomSheet(isAuth: true),
                      ).then((_) async {
                        final chosen =
                            _authController.mainCurrency.value.trim();
                        if (chosen.isEmpty) return;
                        final businessId =
                            _businessController.business['id'];
                        try {
                          await _firestore
                              .collection('businesses')
                              .doc(businessId)
                              .update({'mainCurrency': chosen});
                          await _businessController.updateBusinessData();
                          successSnackbar('Currency updated successfully'.tr);
                        } catch (e) {
                          errorSnackbar('Failed to update currency');
                        }
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'main_currency'.tr,
                          style: bodyText(
                              Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        Row(
                          children: [
                            Text(
                              _businessController.business['mainCurrency'] ??
                                  'TZS',
                              style: bodyText(Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color),
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
                        'Allow Debt'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      if (_profileController.user['role'] == 'owner')
                        Switch(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          activeColor: primaryLightColor,
                          value: _businessController.isDebtEnabled,
                          onChanged: (value) async {
                            await _businessController.setDebtEnabled(value);
                            final String businessId =
                                _businessController.business['id'];
                            await FirebaseFirestore.instance
                                .collection('businesses')
                                .doc(businessId)
                                .update({'debtEnabled': value})
                                .then((_) {
                              successSnackbar('Changes made Successfully');
                              print("debtEnabled updated successfully");
                            }).catchError((error) {
                              print("Failed to update debtEnabled: $error");
                            });
                            await _businessController.updateBusinessData();
                            if (mounted) setState(() {});
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
                          value: _businessController.isPurchasesEnabled,
                          onChanged: (bool value) async {
                            await _businessController.setPurchasesEnabled(value);
                            final String businessId =
                                _businessController.business['id'];
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
                            await _businessController.updateBusinessData();
                            if (mounted) setState(() {});
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
                        'Allow Multiple Fund Sources'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      if (_profileController.user['role'] == 'owner')
                        Switch(
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          activeColor: primaryLightColor,
                          value: _businessController.isMultiFundEnabled,
                          onChanged: (value) async {
                            await _businessController.setMultiFundEnabled(value);
                            final String businessId =
                                _businessController.business['id'];
                            await FirebaseFirestore.instance
                                .collection('businesses')
                                .doc(businessId)
                                .update({'multiFundEnabled': value}).then((_) {
                              successSnackbar('Changes made Successfully');
                              print("multiFundEnabled updated successfully");
                            }).catchError((error) {
                              print("Failed to update multiFundEnabled: $error");
                            });
                            await _businessController.updateBusinessData();
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ),
                const Divider(height: 0),
                if (_profileController.user['role'] == 'owner') ...
                [
                  _SettingsNavRow(
                    title: 'Fund Sources',
                    subtitle: 'Expenses, checkout, payroll & debt payments',
                    icon: Icons.account_balance_wallet_outlined,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FundSourceSettingsScreen()),
                    ),
                  ),
                  const Divider(height: 0),
                ],
                GetBuilder<ProfileController>(
                  builder: (_) => GetBuilder<BusinessController>(
                    builder: (_) {
                      final fromUser = (_profileController
                                  .user['installReferrerCode'] ??
                              '')
                          .toString()
                          .trim();
                      final fromBiz = (_businessController
                                  .business['installReferrerCode'] ??
                              '')
                          .toString()
                          .trim();
                      final code =
                          fromUser.isNotEmpty ? fromUser : fromBiz;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(Icons.card_giftcard_outlined,
                                        size: 20, color: primaryColor),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'referral_code_title'.tr,
                                        style: bodyText(Theme.of(context)
                                                .textTheme.bodyMedium?.color)
                                            .copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (code.isNotEmpty)
                                      IconButton(
                                        constraints: const BoxConstraints(
                                            minWidth: 40, minHeight: 40),
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(Icons.copy_rounded,
                                            size: 22),
                                        tooltip: 'referral_code_copy'.tr,
                                        onPressed: () {
                                          Clipboard.setData(
                                              ClipboardData(text: code));
                                          successSnackbar(
                                              'referral_code_copied'.tr);
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: SelectableText(
                                        code.isEmpty
                                            ? 'referral_code_none'.tr
                                            : code,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: code.isEmpty
                                              ? FontWeight.normal
                                              : FontWeight.w600,
                                          letterSpacing:
                                              code.isEmpty ? 0 : 0.8,
                                          color: code.isEmpty
                                              ? Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.color
                                              : Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                        ),
                                      ),
                                    ),
                                    if (code.isEmpty)
                                      TextButton(
                                        onPressed: _showAddReferralCodeDialog,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text('referral_code_add'.tr),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 0),
                        ],
                      );
                    },
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
                        'Version'.tr,
                        style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                      ),
                      Text(
                        _packageInfo.version == 'Unknown'
                            ? '…'
                            : 'v${_packageInfo.version}+${_packageInfo.buildNumber}',
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

class _SettingsNavRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsNavRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}