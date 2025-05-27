import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/business_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../buttons/primary_button.dart';

class ProductManufacturerBottomSheet extends StatefulWidget {
  const ProductManufacturerBottomSheet({
    Key? key,
    required this.refresh,
  }) : super(key: key);
  final VoidCallback refresh;
  @override
  State<ProductManufacturerBottomSheet> createState() =>
      _ProductManufacturerBottomSheetState();
}

class _ProductManufacturerBottomSheetState
    extends State<ProductManufacturerBottomSheet> {
  final ProductController _productController = Get.find();
  final BusinessController _businessController = Get.find();

  @override
  Widget build(BuildContext context) {
    int radioValue = _businessController.business['manufacturer']
        .indexOf(_productController.selectedManufacturer.value);
    final TextEditingController newManufacturerController = TextEditingController();
    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(20.0),
          child: Wrap(
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "manufacturer".tr,
                      style: h5(
                        Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        ..._businessController.business['manufacturer']
                            .map((Manufacturer) {
                          return Container(
                            padding: const EdgeInsets.all(0),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Preferences.getTheme()
                                    ? mediumGrayColor
                                    : borderColor,
                              ),
                            ),
                            child: SizedBox(
                              height: 44,
                              child: RadioListTile(
                                visualDensity: VisualDensity.compact,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 0,
                                ),
                                activeColor: Preferences.getTheme()
                                    ? primaryLightColor
                                    : primaryColor,
                                title: Text(
                                  Manufacturer,
                                  style: bodyText(
                                    Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color,
                                  ),
                                ),
                                value: _businessController.business['manufacturer']
                                    .indexOf(Manufacturer),
                                groupValue: radioValue,
                                onChanged: (dynamic value) {
                                  setState(() {
                                    radioValue = value;
                                    _productController.setManufacturer(Manufacturer);
                                    widget.refresh();
                                    Navigator.pop(context);
                                  });
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 44,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 44,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(0),
                                elevation: 0,
                                backgroundColor: primaryUltraLightColor,
                              ),
                              onPressed: () {
                                addManufacturer(context, newManufacturerController);
                              },
                              child: const Icon(
                                Icons.settings,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.add,
                                color: primaryColor,
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(0),
                                elevation: 0,
                                backgroundColor: primaryUltraLightColor,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                addManufacturer(context, newManufacturerController);
                              },
                              label: Text('add_new_Manufacturer'.tr,
                                  style: h6(primaryColor)),
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> addManufacturer(
      BuildContext context, TextEditingController newManufacturerController) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          contentPadding: const EdgeInsets.all(20),
          title: Text(
            "new_Manufacturer".tr,
            style: h5(Theme.of(context).textTheme.bodyLarge!.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: newManufacturerController,
                autofocus: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  labelText: 'Manufacturer_name'.tr,
                  labelStyle: bodyText(textPlaceholderColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: PrimaryButton(
                        text: 'save'.tr,
                        onPressed: () async {


                          _productController
                              .setManufacturer(newManufacturerController.text);
                          widget.refresh();
                          Navigator.of(context).pop(true); // Close the dialog and return true
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (result == true) {
      // Handle the case when the Manufacturer is added
    }
  }

}
