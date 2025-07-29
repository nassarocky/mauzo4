import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/product_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/ui/screens/product/edit_product_screen.dart';
import 'package:mauzo/ui/widgets/buttons/secondary_button.dart';
import 'package:mauzo/ui/widgets/dialogs/double_action_dialog.dart';

import '../../../controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../../../controllers/cart_controller.dart';
import '../../../models/product_model.dart';
import '../../screens/transactions/transactions_screen.dart';
import '../dialogs/product_quantity_dialog.dart';
import '../buttons/delete_save_button.dart';
import '../dialogs/store_quantity_dialog.dart';

class StoreInfoBottomSheet extends StatelessWidget {
  StoreInfoBottomSheet({Key? key, required this.product}) : super(key: key);

  final Product product;
  final ProductController _productController = Get.find();
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();
  final CartController _cartController = Get.put(CartController());

  @override
  Widget build(BuildContext context) {
    final bool canEditStore = _profileController.hasPermission('edit_products');
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
                  ClipRRect(
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
                                  formatCurrency(product.price,
                                      _businessController.business['mainCurrency']),
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
                        if (product.buyingPrice != null && product.buyingPrice != 0) ...[
                          const Divider(),
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
                          ],  
                          if (canEditStore && product.details != null && product.details !='') ...[
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

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: 'stock_in_out'.tr,
                      onPressed: () {
                        if(canEditStore){
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (context) =>
                                StoreQuantityDialog(product: product),
                          );}
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
