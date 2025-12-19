import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/client_controller.dart';

import '../../../utils/constants.dart';
import '../../../utils/preferences.dart';

class FilterClientDialog extends StatefulWidget {
  const FilterClientDialog({Key? key}) : super(key: key);

  @override
  State<FilterClientDialog> createState() => _FilterClientDialogState();
}

class _FilterClientDialogState extends State<FilterClientDialog> {
  final ClientController _clientController = Get.find();
  String selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    selectedFilter = _clientController.filterType.value;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'filter'.tr,
        style: h5(
          Theme.of(context).textTheme.bodyLarge!.color,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile(
            activeColor:
                Preferences.getTheme() ? primaryLightColor : primaryColor,
            contentPadding: const EdgeInsets.all(0),
            title: Text('all_clients'.tr),
            value: 'all',
            groupValue: selectedFilter,
            onChanged: (value) {
              setState(() {
                selectedFilter = value.toString();
              });
            },
          ),
          RadioListTile(
            activeColor:
                Preferences.getTheme() ? primaryLightColor : primaryColor,
            contentPadding: const EdgeInsets.all(0),
            title: Text('with_debt'.tr),
            value: 'with_debt',
            groupValue: selectedFilter,
            onChanged: (value) {
              setState(() {
                selectedFilter = value.toString();
              });
            },
          ),
          RadioListTile(
            activeColor:
                Preferences.getTheme() ? primaryLightColor : primaryColor,
            contentPadding: const EdgeInsets.all(0),
            title: Text('with_advance'.tr),
            value: 'with_advance',
            groupValue: selectedFilter,
            onChanged: (value) {
              setState(() {
                selectedFilter = value.toString();
              });
            },
          ),
          RadioListTile(
            activeColor:
                Preferences.getTheme() ? primaryLightColor : primaryColor,
            contentPadding: const EdgeInsets.all(0),
            title: Text('no_debt_no_advance'.tr),
            value: 'no_balance',
            groupValue: selectedFilter,
            onChanged: (value) {
              setState(() {
                selectedFilter = value.toString();
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text('cancel'.tr),
        ),
        ElevatedButton(
          onPressed: () {
            _clientController.applyFilter(selectedFilter);
            Navigator.pop(context);
          },
          child: Text('apply'.tr),
        ),
      ],
    );
  }
}
