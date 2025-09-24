import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/supplier_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/models/supplier_model.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';

import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';
import '../buttons/secondary_button.dart';

class SupplierInfoBottomSheet extends StatelessWidget {
  final Supplier supplier;
  const SupplierInfoBottomSheet({Key? key, required this.supplier})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final SupplierController supplierController = Get.find();
    final BusinessController businessController = Get.find();
    final ProfileController profileController = Get.find();
    final bool canManageSuppliers = profileController.hasPermission('manage_suppliers');
    
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: 25.0,
            horizontal: 20,
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: supplier.image != null && supplier.image != ''
                    ? Container(
                  decoration: const BoxDecoration(
                    color: gray200Color,
                  ),
                  width: 72,
                  height: 72,
                  child: CachedNetworkImage(
                    placeholder: (context, url) =>
                    const CircularProgressIndicator(),
                    imageUrl: supplier.image!,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) =>
                    const CircleAvatar(
                      radius: 31,
                      backgroundColor: gray200Color,
                      child: Icon(
                        Icons.business,
                        size: 40,
                        color: primaryColor,
                      ),
                    ),
                  ),
                )
                    : const CircleAvatar(
                  radius: 31,
                  backgroundColor: gray200Color,
                  child: Icon(
                    Icons.business,
                    size: 40,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                supplier.name,
                style: h5(Theme.of(context).textTheme.bodyLarge!.color),
              ),
              const SizedBox(height: 4),
              if (supplier.company != null && supplier.company!.isNotEmpty)
                Text(
                  supplier.company!,
                  style: bodyText(Theme.of(context).textTheme.bodyMedium!.color),
                ),
              const SizedBox(height: 12),
              if (supplier.phone.isNotEmpty)
                Text(
                  supplier.phone,
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
              const SizedBox(height: 8),
              if (supplier.email != null && supplier.email!.isNotEmpty)
                Text(
                  supplier.email!,
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
              const SizedBox(height: 8),
              if (supplier.address != null && supplier.address!.isNotEmpty)
                Text(
                  supplier.address!,
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
              const SizedBox(height: 8),
              if (supplier.taxNumber != null && supplier.taxNumber!.isNotEmpty)
                Text(
                  '${'tax_number'.tr}: ${supplier.taxNumber!}',
                  style: bodyText(
                    Theme.of(context).textTheme.bodyMedium!.color,
                  ),
                ),
              const SizedBox(height: 12),
              
              // Financial information
              if (supplier.debt > 0)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: redColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning, color: redColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${'debt'.tr}: ${formatCurrency(supplier.debt, businessController.business['mainCurrency'])}',
                        style: const TextStyle(
                          color: redColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              
              if (supplier.advance > 0)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.account_balance_wallet, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${'advance'.tr}: ${formatCurrency(supplier.advance, businessController.business['mainCurrency'])}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 44),
              SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canManageSuppliers)
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: borderColor,
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) {
                              return DoubleActionDialog(
                                title: 'delete_supplier'.tr,
                                content: 'delete_supplier_confirmation'.tr,
                                confirm: 'delete'.tr,
                                cancel: 'cancel'.tr,
                                onConfirm: () {
                                  supplierController.deleteSupplier(supplier.id);
                                  Navigator.pop(context);
                                },
                                onCancel: () {
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                        icon: const Icon(
                          Icons.delete,
                          color: redColor,
                        ),
                      ),
                    ),
                    if (canManageSuppliers) ...[
                      const SizedBox(width: 8),
                      SecondaryButton(
                        text: 'edit'.tr,
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/supplier/edit',
                            arguments: supplier,
                          );
                        },
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: PrimaryButton(
                        text: 'view_purchases'.tr,
                        onPressed: () {
                          // Navigate to BoughtScreen with supplier filter
                          Navigator.pushNamed(
                            context, 
                            '/bought',
                            arguments: {'supplierId': supplier.id, 'supplierName': supplier.name}
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
}
