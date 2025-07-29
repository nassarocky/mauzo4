import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../utils/preferences.dart';
import '../../widgets/bottomsheets/product_info_bottom_sheet.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';
import '../bottomsheets/store_info_buttomsheet.dart';
import '../dialogs/product_quantity_dialog.dart';
import '../dialogs/store_quantity_dialog.dart';

class StoreTile extends StatelessWidget {
  const StoreTile({Key? key, required this.product}) : super(key: key);

  final Product product;

  @override
  Widget build(BuildContext context) {
    final ProfileController profileController = Get.find();
    final BusinessController businessController = Get.find();
    final bool canEditStore = profileController.hasPermission('edit_products');
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
          builder: (_) => StoreInfoBottomSheet(
            product: product,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Preferences.getTheme() ? mediumGrayColor : borderColor,
              width: 1,
            ),
          ),
        ),
        margin: const EdgeInsets.only(left: 16, right: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: product.image != ''
                    ? Container(
                  margin: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: CachedNetworkImage(
                      imageUrl: product.image!,
                      placeholder: (context, url) => Container(
                        padding: const EdgeInsets.all(10),
                        child: const CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 48,
                        width: 48,
                        decoration: const BoxDecoration(
                          color: Color(0xFF80B2FF),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset('assets/images/box.png'),
                      ),
                      height: 48,
                      width: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                )
                    : ClipRRect(
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
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: bodyText(
                          Preferences.getTheme()
                              ? primaryLightColor
                              : primaryColor,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatCurrency(product.price,
                            businessController.business['mainCurrency']),
                        style: bodyText(
                          Theme.of(context).textTheme.bodyMedium!.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                width: 4,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (canEditStore) {
                          showDialog(
                            barrierDismissible: false,
                            context: context,
                            builder: (context) => StoreQuantityDialog(product: product),
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
                            builder: (_) => StoreInfoBottomSheet(
                              product: product,
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
                            Text(
                              product.quantity.toString(),
                              style: h5(
                                (product.quantity ?? 0) < (product.understock ?? 0) ? Colors.red : Colors.green,
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
