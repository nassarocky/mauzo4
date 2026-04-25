import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/product_transfer_controller.dart';
import 'package:mauzo/controllers/inventory_loss_controller.dart';
import 'package:mauzo/ui/screens/product/edit_product_screen.dart';
import 'package:mauzo/ui/widgets/buttons/secondary_button.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';
import 'package:mauzo/ui/widgets/dialogs/record_loss_dialog.dart';
import '../../../controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../../../controllers/cart_controller.dart';
import '../../../models/product_model.dart';
import '../../screens/transactions/transactions_screen.dart';
import '../dialogs/product_quantity_dialog.dart';
import '../buttons/delete_save_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../dialogs/transfer_quantity_dialog.dart';
import '../dialogs/store_quantity_dialog.dart';


class ProductInfoBottomSheet extends StatelessWidget {
  ProductInfoBottomSheet({Key? key, required this.product}) : super(key: key);

  final Product product;
  final ProductController _productController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();
  final CartController _cartController = Get.put(CartController());

  void _showFullScreenImage(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: product.image != null && product.image != ''
                  ? CachedNetworkImage(
                      imageUrl: product.image!,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFF80B2FF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Image.asset(
                          'assets/images/box.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      fit: BoxFit.contain,
                    )
                  : Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF80B2FF),
                      ),
                      child: Image.asset(
                        'assets/images/box.png',
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  String formatDate(DateTime date) {
    // Format the date as 'dd MMM yyyy'
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final bool canEditProduct = _profileController.hasPermission('edit_products');
    final bool canMakeSales = _profileController.hasPermission('make_sales');
    return Wrap(
      children: [
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _showFullScreenImage(context),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: product.image != null && product.image != ''
                          ? CachedNetworkImage(
                              placeholder: (context, url) => Container(
                                padding: const EdgeInsets.all(10),
                                child: const CircularProgressIndicator(),
                              ),
                              imageUrl: product.image!,
                              errorWidget: (context, url, error) => Container(
                                width: 100,
                                height: 100,
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF80B2FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Image.asset(
                                  'assets/images/box.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: 100,
                              height: 100,
                              padding: const EdgeInsets.all(24),
                              decoration: const BoxDecoration(
                                color: Color(0xFF80B2FF),
                              ),
                              child: Image.asset(
                                'assets/images/box.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: h5(
                            Theme.of(context).textTheme.bodyLarge!.color,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${'category'.tr}: ${product.category!}',
                          style: bodyText(
                              Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${'code'.tr}:',
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  product.code != '' ? product.code : 'N/A',
                                  style: h6(
                                    Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${'in_stock'.tr}:',
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  product.quantity.toString(),
                                  style: h6(
                                    warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${'sellingPrice'.tr}:',
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  formatCurrency(
                                    product.price,
                                    _businessController.business['mainCurrency'],
                                  ),
                                  style: h6(
                                    Theme.of(context).textTheme.bodyLarge!.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (product.wholesalePrice > 0) ...[
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${'wholesale_selling_price'.tr}:',
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formatCurrency(
                                      product.wholesalePrice,
                                      _businessController.business['mainCurrency'] ?? 'TZS',
                                    ),
                                    style: h6(
                                      Theme.of(context).textTheme.bodyLarge!.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (product.buyingPrice != null && product.buyingPrice != 0) ...[
                          const Divider(),
                          if(canEditProduct)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${'Buying Price'.tr}:',
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    formatCurrency(product.buyingPrice,
                                        _businessController.business['mainCurrency']),
                                    style: h6(
                                      Theme.of(context).textTheme.bodyLarge!.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Conditionally display expireDate

                          if (product.expireDate != null) ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${'expireDate'.tr}:',
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      formatDate(product.expireDate!),
                                      style: h6(
                                        Theme.of(context).textTheme.bodyLarge!.color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (product.location != null && product.location !='') ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${'location'.tr}:',
                                  ),
                                  const SizedBox(width: 4),
    Flexible(
    child: Text(
     product.location.toString(),
    style: h6(
    Theme.of(context)
        .textTheme
        .bodyLarge!
        .color,
    ),
    ),
    ),
                                ],
                              ),
                            ),
                          ],
                          if (product.manufacturer != null && product.manufacturer !='') ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${'manufacturer'.tr}:',
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      product.manufacturer.toString(),
                                      style: h6(
                                        Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],  if (product.details != null && product.details !='') ...[
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${'details'.tr}:',
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      product.details.toString(),
                                      style: h6(
                                        Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        ]
                        ,
                      ],
                    ),
                  )
                ],
              ),

              // Action buttons (hide for services)
              if (product.itemType != 'service') ...[
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'stock_in_out'.tr,
                        onPressed: () {
                          if(canEditProduct){
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) =>
                                  ProductQuantityDialog(product: product),
                            );}
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'Stock Transactions'.tr,
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => TransactionsScreen(product: product),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Record Loss Button (Manager/Owner only)
                if (_profileController.isManagerOrOwner())
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          text: 'Record Loss'.tr,
                          onPressed: () async {
                            Get.lazyPut(() => InventoryLossController());
                            final result = await showDialog(
                              context: context,
                              builder: (context) => RecordLossDialog(product: product),
                            );
                            if (result == true) {
                              Navigator.pop(context); // Close bottom sheet after recording loss
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'Move to Store'.tr,
                        onPressed: () {
                          if(canEditProduct){
                            Navigator.pop(context);
                            showDialog(
                              context: context,
                              builder: (context) => StoreQuantityDialog(
                                product: product,
                                isMoveToStore: true,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: 'Transfer Product',
                        onPressed: () async {
                          // Check if user has permission to transfer products (block agents)
                          if (!_profileController.hasPermission('transfer_products')) {
                            Get.snackbar(
                              'Access Denied'.tr,
                              'You do not have permission to transfer products'.tr,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                              duration: Duration(seconds: 3),
                            );
                            return;
                          }
                          // Get all businesses associated with the user except the current one
                          final businesses = _profileController.user['business'] as List<dynamic>? ?? [];
                          final currentBusinessId = _businessController.businessId.value;
                          final otherBusinessIds = businesses.where((id) => id != currentBusinessId).toList();
                          if (otherBusinessIds.isEmpty) {
                            Get.snackbar('No Businesses', 'No other businesses available for transfer.');
                            return;
                          }
                          // Fetch business names for dropdown
                          List<Map<String, String>> businessOptions = [];
                          for (var id in otherBusinessIds) {
                            var doc = await FirebaseFirestore.instance.collection('businesses').doc(id).get();
                            if (doc.exists) {
                              final data = doc.data() as Map<String, dynamic>;
                              businessOptions.add({'id': id, 'name': data['name'] ?? id});
                            }
                          }
                          String? selectedBusinessId = await showDialog<String>(
                            context: context,
                            builder: (context) {
                              String? dropdownValue = businessOptions.first['id'];
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return AlertDialog(
                                    title: Text('select_target_business'.tr),
                                    content: DropdownButton<String>(
                                      value: dropdownValue,
                                      isExpanded: true,
                                      items: businessOptions.map((option) {
                                        return DropdownMenuItem<String>(
                                          value: option['id'],
                                          child: Text(option['name'] ?? option['id']!),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          dropdownValue = value;
                                        });
                                      },
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, null),
                                        child: Text('cancel'.tr),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, dropdownValue),
                                        child: Text('next'.tr),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          );
                          if (selectedBusinessId != null && selectedBusinessId.isNotEmpty) {
                            // Show transfer quantity dialog
                            showDialog(
                              context: context,
                              builder: (context) => TransferQuantityDialog(
                                product: product,
                                fromBusinessId: _businessController.businessId.value!,
                                toBusinessId: selectedBusinessId,
                                onConfirm: (fromBusinessId, toBusinessId, quantity) async {
                                  final productTransferController = Get.find<ProductTransferController>();
                                  await productTransferController.createTransferRequest(
                                    productId: product.id,
                                    fromBusinessId: fromBusinessId,
                                    toBusinessId: toBusinessId,
                                    requestedByUserId: _profileController.user['id'],
                                    transferQuantity: quantity,
                                  );
                                  Get.snackbar('Transfer Requested', 'Product transfer request sent.');
                                },
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: 'edit_product'.tr,
                      onPressed: () {
                        if(canEditProduct){
                          Navigator.pushReplacement(
                            context,
                            CupertinoPageRoute(
                              builder: (context) =>
                                  EditProductScreen(product: product),
                            ),
                          );}
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: DeleteSaveButton(
                  onDelete: () {
                    if(canEditProduct){
                      showDialog(
                        context: context,
                        builder: (context) => DoubleActionDialog(
                          title: 'delete_product'.tr,
                          content: 'delete_product_confirmation'.tr,
                          confirm: 'delete'.tr,
                          cancel: 'cancel'.tr,
                          onConfirm: () {
                            _productController.deleteProduct(product);
                            Navigator.pop(context);
                            Navigator.pop(context);
                          },
                          onCancel: () {
                            Navigator.pop(context);
                          },
                        ),
                      );}
                  },
                  onSave: canMakeSales ? () {
                    if (product.quantity! > 0) {

                      Navigator.pushNamed(context, '/sale/add');
                      _cartController.updateCart(
                        product,
                        1,
                        _cartController.defaultUnitSellingPrice(product),
                      );
                      Navigator.pushNamed(context, '/cart');
                    } else {
                      errorSnackbar('not_enough'.tr);
                    }
                  } : () {
                    // Show permission denied message
                    errorSnackbar('Permission denied: Cannot make sales'.tr);
                  },
                  text: 'make_sale'.tr,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
