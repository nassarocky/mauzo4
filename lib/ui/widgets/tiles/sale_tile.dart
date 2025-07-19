import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/preferences.dart';
import '../dialogs/add_to_cart_dialog.dart';
import '../bottomsheets/actions_bottom_sheet.dart';
import '../../../controllers/cart_controller.dart';
import '../../../models/product_model.dart';
import '../../../utils/constants.dart';

class SaleTile extends StatelessWidget {
  SaleTile({Key? key, required this.product}) : super(key: key);

  final CartController _cartController = Get.find();
  final BusinessController _businessController = Get.find();

  final Product product;

  @override
  Widget build(BuildContext context) {
    // Determine if this is a service
    bool isService = product.itemType == 'service';
    
    // Determine how soon the product expires (only for non-services)
    int expireWarning = _businessController.business['expireWarning'] ?? 30; // Default to 30 days
    Color nameColor = !isService && product.expireDate != null && product.expireDate!.isBefore(DateTime.now().add(Duration(days: expireWarning)))
        ? Colors.orange // Warning color for products nearing expiry
        : Theme.of(context).textTheme.bodyLarge!.color!; // Default color

    return Obx(
          () => Container(
        margin: const EdgeInsets.only(bottom: 16.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: isService ? Colors.purple : const Color(0xFF80B2FF),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.all(10),
              child: isService 
                  ? Icon(Icons.miscellaneous_services, color: Colors.white, size: 28)
                  : Image.asset('assets/images/box.png'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.start,
                    spacing: 8.0, // Space between elements
                    children: [
                      Text(
                        product.name,
                        style: h6(nameColor), // Apply the color based on expiry warning
                      ),
                      if (product.expireDate != null &&
                          product.expireDate!.isBefore(DateTime.now())) // Check expiration
                        Text(
                          'Expired',
                          style: h6(Colors.red).copyWith(fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatCurrency(
                      product.price,
                      _businessController.business['mainCurrency'],
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            IntrinsicHeight(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isService 
                            ? 'N/A' // Show N/A for services
                            : (product.quantity % 1 == 0
                                ? product.quantity.toStringAsFixed(0) // Display as whole number
                                : product.quantity.toStringAsFixed(2)), // Display with two decimal places
                        style: bodyText(isService ? Colors.grey : warningColor),
                      ),
                      Text(
                        isService 
                            ? 'Service' // Show "Service" for services
                            : ((product.reserveString1?.isEmpty ?? true) ? 'unit' : product.reserveString1!),
                        style: TextStyle(
                          fontSize: 14,
                          color: isService ? Colors.grey : warningColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  const VerticalDivider(
                    color: borderColor,
                    width: 1,
                  ),
                  _cartController.singleProductQuantity(product.id) > 0
                      ? TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.all(0),
                      minimumSize: const Size(0, 0),
                    ),
                    onPressed: () {
                      showModalBottomSheet(
                        backgroundColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                        ),
                        context: context,
                        builder: (context) {
                          return ActionsBottomSheet(
                            product: product,
                          );
                        },
                      );
                    },
                    child: Text(
                      _cartController.singleProductQuantity(product.id).toString(),
                      style: TextStyle(
                        fontSize: 24,
                        color: Preferences.getTheme() ? primaryLightColor : primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                      : IconButton(
                    padding: const EdgeInsets.all(0),
                    onPressed: () {
                      if (isService || product.quantity! > 0) {
                        showDialog(
                          barrierDismissible: false,
                          context: context,
                          builder: (context) => AddToCartDialog(
                            product: product,
                            itemCounter: _cartController.singleProductQuantity(product.id),
                          ),
                        );
                      } else {
                        return;
                      }
                    },
                    icon: Icon(
                      Icons.add_circle,
                      color: (isService || product.quantity! > 0)
                          ? Preferences.getTheme()
                          ? primaryLightColor
                          : primaryColor
                          : iconGrayColor,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
