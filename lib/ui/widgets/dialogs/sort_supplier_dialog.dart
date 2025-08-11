import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../controllers/supplier_controller.dart';
import '../../../utils/constants.dart';
import '../buttons/primary_button.dart';

class SortSupplierDialog extends StatefulWidget {
  const SortSupplierDialog({Key? key}) : super(key: key);

  @override
  State<SortSupplierDialog> createState() => _SortSupplierDialogState();
}

class _SortSupplierDialogState extends State<SortSupplierDialog> {
  final SupplierController _supplierController = Get.find();
  String _selectedCategory = 'name';

  @override
  void initState() {
    super.initState();
    _selectedCategory = _supplierController.sortCategory.value;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('sort_suppliers'.tr),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            title: Text('name'.tr),
            value: 'name',
            groupValue: _selectedCategory,
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: Text('company'.tr),
            value: 'company',
            groupValue: _selectedCategory,
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: Text('debt'.tr),
            value: 'debt',
            groupValue: _selectedCategory,
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
          RadioListTile<String>(
            title: Text('date'.tr),
            value: 'date',
            groupValue: _selectedCategory,
            onChanged: (value) {
              setState(() {
                _selectedCategory = value!;
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('cancel'.tr),
        ),
        PrimaryButton(
          text: 'sort'.tr,
          onPressed: () {
            _supplierController.sort(_selectedCategory);
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
