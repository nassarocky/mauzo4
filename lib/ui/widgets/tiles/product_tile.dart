import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../utils/preferences.dart';
import '../../widgets/bottomsheets/product_info_bottom_sheet.dart';
import '../../../models/product_model.dart';
import '../../../services/paired_product_service.dart';
import '../../../utils/constants.dart';
import '../dialogs/product_quantity_dialog.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({Key? key, required this.product}) : super(key: key);

  final Product product;

  @override
  Widget build(BuildContext context) {
    final ProfileController profileController = Get.find();
    final BusinessController businessController = Get.find();
    final bool canEditProduct = profileController.hasPermission('edit_products');
    int expireWarning = businessController.business['expireWarning'] ?? 30;

    bool isExpireWarning = false;
    if (product.expireDate != null) {
      final expireDate = product.expireDate!;
      final currentDate = DateTime.now();
      final daysUntilExpiration = expireDate.difference(currentDate).inDays;

      if (daysUntilExpiration <= expireWarning && daysUntilExpiration >= 0) {
        isExpireWarning = true;
      }
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.7,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return SafeArea(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: ProductInfoBottomSheet(
                    product: product,
                  ),
                ),
              );
            },
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: product.itemType == 'service' ? const Color(0xFFD0F5E8) : null, // Light green for services
          border: Border(
            top: BorderSide(
              color: Preferences.getTheme() ? mediumGrayColor : borderColor,
              width: 1,
            ),
          ),
        ),
        margin: EdgeInsets.only(
          left: PairedProductService.isTwin(product) ? 28 : 16,
          right: 16,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  margin: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF80B2FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Image.asset('assets/images/box.png'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.start,
                        spacing: 8.0,
                        children: [
                          Text(
                            product.name,
                            style: bodyText(
                              isExpireWarning
                                  ? Colors.orange
                                  : Preferences.getTheme()
                                  ? primaryLightColor
                                  : primaryColor,
                            ),
                          ),
                          if (product.isPairedMain)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                'paired_product_badge'.tr,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (product.isTwinProduct)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Text(
                                'twin_product_badge'.tr,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.teal.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (product.expireDate != null &&
                              product.expireDate!.isBefore(DateTime.now()))
                            Text(
                              'Expired',
                              style: bodyText(
                                Colors.red,
                              ).copyWith(fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatCurrency(
                          product.price,
                          businessController.business['mainCurrency'],
                        ),
                        style: bodyText(
                          Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (canEditProduct) {
                          showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (context) => ProductQuantityDialog(product: product),
                          );
                        } else {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(4),
                              ),
                            ),
                            builder: (context) => DraggableScrollableSheet(
                              initialChildSize: 0.7,
                              minChildSize: 0.4,
                              maxChildSize: 0.95,
                              expand: false,
                              builder: (context, scrollController) {
                                return SafeArea(
                                  child: SingleChildScrollView(
                                    controller: scrollController,
                                    child: ProductInfoBottomSheet(
                                      product: product,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width * 0.25,
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Preferences.getTheme()
                                  ? mediumGrayColor
                                  : borderColor,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            product.itemType == 'service'
                                ? Text(
                                    'N/A',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : Text.rich(
                                    product.getQuantityWithUnitSpan(
                                      quantityColor: (product.quantity ?? 0) < (product.understock ?? 0)
                                          ? Colors.red
                                          : Colors.green,
                                      unitColor: Colors.grey,
                                      fontSize: 16.0,
                                    ),
                                  ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.unfold_more,
                              color: iconGrayColor,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
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