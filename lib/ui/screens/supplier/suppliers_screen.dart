import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/utils/preferences.dart';
import 'package:mauzo/ui/widgets/dialogs/sort_supplier_dialog.dart';
import 'package:mauzo/ui/widgets/search_filter_icon.dart';
import '../../widgets/bottomsheets/supplier_info_bottom_sheet.dart';
import '../../../controllers/supplier_controller.dart';
import '../../../utils/constants.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({Key? key}) : super(key: key);

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  final SupplierController _supplierController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  @override
  void initState() {
    super.initState();
    final role = (_profileController.user['role'] ?? '').toString();
    if (!_businessController.isPurchasesAllowedForRole(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
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
    }
  }

  @override
  void dispose() {
    Timer.run(() {
      _supplierController.searchSuppliers.value = _supplierController.suppliers;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canManageSuppliers = _profileController.hasPermission('manage_suppliers');
    
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('suppliers'.tr),
      ),
      floatingActionButton: canManageSuppliers ? FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/supplier/add',
          );
        },
        child: const Icon(Icons.add),
      ) : null,
      body: Obx(
        () => Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() {
                            _supplierController.search(value);
                          });
                        },
                        decoration: InputDecoration(
                          contentPadding: inputPadding,
                          prefixIcon: const Icon(Icons.search),
                          prefixIconColor: iconGrayColor,
                          filled: true,
                          fillColor: Preferences.getTheme()
                              ? darkGrayColor
                              : gray100Color,
                          hintText: 'search'.tr,
                          hintStyle: bodyText(textPlaceholderColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: Preferences.getTheme()
                                  ? mediumGrayColor
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(4),
                            borderSide: BorderSide(
                              color: Preferences.getTheme()
                                  ? mediumGrayColor
                                  : const Color(0xFFE0E0E0),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SearchFilterIcon(
                      icon: Icons.sort,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) {
                            return const SortSupplierDialog();
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: _supplierController.suppliers.isEmpty
                    ? Center(
                        child: Text(
                          'not_found'.tr,
                          style: bodyText(
                            Theme.of(context).textTheme.bodyMedium!.color,
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _supplierController.searchSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = _supplierController.searchSuppliers[index];
                          return ListTile(
                            onTap: () {
                              showModalBottomSheet(
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                                isScrollControlled: true,
                                context: context,
                                builder: (_) {
                                  return SupplierInfoBottomSheet(
                                    supplier: supplier,
                                  );
                                },
                              );
                            },
                            contentPadding: const EdgeInsets.all(0),
                            leading: SizedBox(
                              height: 36,
                              width: 36,
                              child: (supplier.image != null && supplier.image != '')
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: CachedNetworkImage(
                                  imageUrl: supplier.image!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) => Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: gray200Color,
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.business,
                                        color: iconGrayColor,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                                  : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: gray200Color,
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.business,
                                    color: iconGrayColor,
                                  ),
                                ],
                              ),
                            ),
                            title: Text(
                              supplier.name,
                              style: bodyText(
                                  Theme.of(context).textTheme.bodyLarge!.color),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (supplier.company != null && supplier.company!.isNotEmpty)
                                  Text(
                                    supplier.company!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: textPlaceholderColor,
                                    ),
                                  ),
                                if (supplier.debt > 0)
                                  Text(
                                    '${'debt'.tr}: ${formatCurrency(supplier.debt, _businessController.business['mainCurrency'])}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: redColor,
                                    ),
                                  ),
                                if (supplier.advance > 0)
                                  Text(
                                    '${'advance'.tr}: ${formatCurrency(supplier.advance, _businessController.business['mainCurrency'])}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.green, // Use green for advance
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
