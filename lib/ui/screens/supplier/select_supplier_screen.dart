import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/utils/preferences.dart';
import '../../../controllers/supplier_controller.dart';
import '../../../utils/constants.dart';

class SelectSupplierScreen extends StatefulWidget {
  const SelectSupplierScreen({Key? key}) : super(key: key);

  @override
  State<SelectSupplierScreen> createState() => _SelectSupplierScreenState();
}

class _SelectSupplierScreenState extends State<SelectSupplierScreen> {
  final SupplierController _supplierController = Get.find();
  final BusinessController _businessController = Get.find();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text('select_supplier'.tr),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, null); // Return null for no supplier selected
            },
            child: Text(
              'skip'.tr,
              style: const TextStyle(color: primaryColor),
            ),
          ),
        ],
      ),
      body: Obx(
        () => Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: TextField(
                  onChanged: (value) {
                    _supplierController.search(value);
                  },
                  decoration: InputDecoration(
                    contentPadding: inputPadding,
                    prefixIcon: const Icon(Icons.search),
                    prefixIconColor: iconGrayColor,
                    filled: true,
                    fillColor: Preferences.getTheme()
                        ? darkGrayColor
                        : gray100Color,
                    hintText: 'search_suppliers'.tr,
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
              Expanded(
                child: _supplierController.suppliers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.business,
                              size: 64,
                              color: textPlaceholderColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'no_suppliers_found'.tr,
                              style: bodyText(
                                Theme.of(context).textTheme.bodyMedium!.color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/supplier/add');
                              },
                              child: Text('add_supplier'.tr),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _supplierController.searchSuppliers.length,
                        itemBuilder: (context, index) {
                          final supplier = _supplierController.searchSuppliers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              onTap: () {
                                Navigator.pop(context, supplier); // Return selected supplier
                              },
                              contentPadding: const EdgeInsets.all(12),
                              leading: SizedBox(
                                height: 50,
                                width: 50,
                                child: (supplier.image != null && supplier.image != '')
                                    ? ClipRRect(
                                  borderRadius: BorderRadius.circular(25),
                                  child: CachedNetworkImage(
                                    imageUrl: supplier.image!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                    errorWidget: (context, url, error) => Container(
                                      decoration: BoxDecoration(
                                        color: gray200Color,
                                        borderRadius: BorderRadius.circular(25),
                                      ),
                                      child: const Icon(
                                        Icons.business,
                                        color: iconGrayColor,
                                      ),
                                    ),
                                  ),
                                )
                                    : Container(
                                  decoration: BoxDecoration(
                                    color: gray200Color,
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: const Icon(
                                    Icons.business,
                                    color: iconGrayColor,
                                  ),
                                ),
                              ),
                              title: Text(
                                supplier.name,
                                style: bodyText(
                                    Theme.of(context).textTheme.bodyLarge!.color),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (supplier.company != null && supplier.company!.isNotEmpty)
                                    Text(
                                      supplier.company!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: textPlaceholderColor,
                                      ),
                                    ),
                                  if (supplier.phone.isNotEmpty)
                                    Text(
                                      supplier.phone,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: textPlaceholderColor,
                                      ),
                                    ),
                                  if (supplier.debt > 0)
                                    Text(
                                      '${'debt'.tr}: ${formatCurrency(supplier.debt, _businessController.business['mainCurrency'])}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: redColor,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: textPlaceholderColor,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/supplier/add');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
