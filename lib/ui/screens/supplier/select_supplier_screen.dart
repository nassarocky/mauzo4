import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/supplier_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/utils/constants.dart';
import '../../../utils/preferences.dart';

class SelectSupplierScreen extends StatefulWidget {
  const SelectSupplierScreen({Key? key}) : super(key: key);

  @override
  State<SelectSupplierScreen> createState() => _SelectSupplierScreenState();
}

class _SelectSupplierScreenState extends State<SelectSupplierScreen> {
  final SupplierController _supplierController = Get.find();
  final BusinessController _businessController = Get.find();

  @override
  void dispose() {
    _supplierController.searchSuppliers.value = _supplierController.suppliers;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Preferences.getTheme() ? darkGrayColor : gray100Color,
        elevation: 0,
        title: Text(
          'select_supplier'.tr,
          style: TextStyle(
            color: Preferences.getTheme() ? primaryUltraLightColor : textDarkColor,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).textTheme.bodyLarge!.color),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/supplier/add');
        },
        child: const Icon(Icons.add),
      ),
      body: Obx(
        () => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
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
            const SizedBox(height: 14),
            ListTile(
              onTap: () {
                Navigator.pop(context, null);
              },
              contentPadding: const EdgeInsets.all(0),
              leading: SizedBox(
                height: 36,
                width: 36,
                child: Stack(
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
                'no_supplier'.tr,
                style: bodyText(Theme.of(context).textTheme.bodyLarge!.color),
              ),
              trailing: const Icon(Icons.check),
            ),
                ListView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  itemCount: _supplierController.searchSuppliers.length,
                  itemBuilder: (context, index) {
                    final supplier = _supplierController.searchSuppliers[index];
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context, supplier);
                      },
                      contentPadding: const EdgeInsets.all(0),
                      leading: SizedBox(
                        height: 36,
                        width: 36,
                        child: (supplier.image != null && supplier.image != '')
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: Image.network(
                                  supplier.image!,
                                  fit: BoxFit.cover,
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
                      subtitle: supplier.debt > 0
                          ? Text(
                              '${'debt'.tr}: ${formatCurrency(supplier.debt, _businessController.business['mainCurrency'])}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: redColor,
                              ),
                            )
                          : supplier.company?.isNotEmpty == true
                              ? Text(
                                  supplier.company!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: textPlaceholderColor,
                                  ),
                                )
                              : null,
                    );
                  },
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
