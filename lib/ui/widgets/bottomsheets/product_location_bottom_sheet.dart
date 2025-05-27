import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/business_controller.dart';
import '../../../controllers/product_controller.dart';
import '../../../controllers/profile_controller.dart';
import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';
import '../buttons/primary_button.dart';

class ProductLocationBottomSheet extends StatefulWidget {
  const ProductLocationBottomSheet({
    Key? key,
    required this.refresh,
  }) : super(key: key);
  final VoidCallback refresh;
  @override
  State<ProductLocationBottomSheet> createState() =>
      _ProductLocationBottomSheetState();
}

class _ProductLocationBottomSheetState
    extends State<ProductLocationBottomSheet> {
  final ProductController _productController = Get.find();
  final BusinessController _businessController = Get.find();

  @override
  Widget build(BuildContext context) {
    int radioValue = _businessController.business['location']
        .indexOf(_productController.selectedLocation.value);
    final TextEditingController newLocationController = TextEditingController();
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
                      "location".tr,
                      style: h5(
                        Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      children: [
                        ..._businessController.business['location']
                            .map((Location) {
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
                                  Location,
                                  style: bodyText(
                                    Theme.of(context)
                                        .textTheme
                                        .bodyLarge!
                                        .color,
                                  ),
                                ),
                                value: _businessController.business['location']
                                    .indexOf(Location),
                                groupValue: radioValue,
                                onChanged: (dynamic value) {
                                  setState(() {
                                    radioValue = value;
                                    _productController.setLocation(Location);
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
                                addLocation(context, newLocationController);
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
                                addLocation(context, newLocationController);
                              },
                              label: Text('add_new_Location'.tr,
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

  Future<void> addLocation(
      BuildContext context, TextEditingController newLocationController) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          contentPadding: const EdgeInsets.all(20),
          title: Text(
            "new_Location".tr,
            style: h5(Theme.of(context).textTheme.bodyLarge!.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: newLocationController,
                autofocus: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  labelText: 'Location_name'.tr,
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
                              .setLocation(newLocationController.text);
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
      // Handle the case when the Location is added
    }
  }

}
