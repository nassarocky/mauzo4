import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/supplier_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/supplier_debt_controller.dart';
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
    final SupplierDebtController supplierDebtController = Get.find();
    final bool canManageSuppliers = profileController.hasPermission('manage_suppliers');
    
    // Calculate total debt owed to this supplier
    final supplierDebts = supplierDebtController.supplierDebts
        .where((debt) => debt.supplier == supplier.id && debt.status != 'paid')
        .toList();
    final totalDebt = supplierDebts.fold<double>(
      0, (sum, debt) => sum + debt.remainingDebtAmount
    );
    
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
              
              // Financial information - Show debt we owe to supplier
              if (totalDebt > 0)
                GestureDetector(
                  onTap: () {
                    // Show debt purchases dialog
                    showDialog(
                      context: context,
                      builder: (context) => _buildDebtPurchasesDialog(
                        context, supplierDebts, businessController.business['mainCurrency']
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: warningColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.account_balance_wallet, color: warningColor, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'amount_owed'.tr,
                              style: bodyText(textMutedColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency(totalDebt, businessController.business['mainCurrency']),
                          style: const TextStyle(
                            color: warningColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${supplierDebts.length} ${'unpaid_purchases'.tr}',
                          style: TextStyle(
                            color: textMutedColor,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'tap_to_view_details'.tr,
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
                    if (totalDebt > 0) ...[  
                      const SizedBox(width: 8),
                      Expanded(
                        child: PrimaryButton(
                          color: warningColor,
                          text: 'record_payment'.tr,
                          onPressed: () {
                            // Navigate to supplier debt screen to record payment
                            Navigator.pop(context);
                            Navigator.pushNamed(context, '/supplier-debt');
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              )
            ],
          ),
        ),
      ],
    );
  }
  
  // Helper method to build the debt purchases dialog
  Widget _buildDebtPurchasesDialog(BuildContext context, List<dynamic> supplierDebts, String currency) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
          maxWidth: 400,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'debt_purchases'.tr,
                  style: h5(Theme.of(context).textTheme.bodyLarge!.color),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: supplierDebts.length,
                itemBuilder: (context, index) {
                  final debt = supplierDebts[index];
                  final dateIncurred = (debt.dateIncurred as Timestamp).toDate();
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: warningColor,
                          size: 24,
                        ),
                      ),
                      title: Text(
                        formatCurrency(debt.remainingDebtAmount, currency),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: warningColor,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${'date'.tr}: ${DateFormat('dd/MM/yyyy').format(dateIncurred)}',
                            style: TextStyle(fontSize: 12),
                          ),
                          if (debt.comment != null && debt.comment.isNotEmpty)
                            Text(
                              debt.comment,
                              style: TextStyle(fontSize: 12, color: textMutedColor),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (debt.products != null && debt.products!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${'products'.tr}: ${debt.products!.length} ${'items'.tr}',
                              style: TextStyle(
                                fontSize: 11,
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            ...debt.products!.take(2).map((product) =>
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: Text(
                                  '• ${product['name']} (${product['quantity']}x)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textMutedColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ).toList(),
                            if (debt.products!.length > 2)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: Text(
                                  '  ${'and'.tr} ${debt.products!.length - 2} ${'more'.tr}...',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textMutedColor,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                          Text(
                            '${'initial_amount'.tr}: ${formatCurrency(debt.initialDebtAmount, currency)}',
                            style: TextStyle(fontSize: 11, color: textMutedColor),
                          ),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: debt.status == 'pending' 
                            ? redColor.withOpacity(0.1)
                            : debt.status == 'partially_paid'
                              ? warningColor.withOpacity(0.1) 
                              : greenColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          debt.status.tr,
                          style: TextStyle(
                            fontSize: 10,
                            color: debt.status == 'pending'
                              ? redColor
                              : debt.status == 'partially_paid' 
                                ? warningColor
                                : greenColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      onTap: () {
                        // Navigate to purchase details if needed
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/bought',
                          arguments: {'purchaseId': debt.id}
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'total_debt'.tr,
                  style: h6(textDarkColor),
                ),
                Text(
                  formatCurrency(
                    supplierDebts.fold<double>(0, (sum, debt) => sum + debt.remainingDebtAmount),
                    currency
                  ),
                  style: h5(warningColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
