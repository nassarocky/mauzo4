import 'package:flutter/material.dart';

List<DropdownMenuItem<String>> getUnitDropdownItems() {
  return [
    DropdownMenuItem(
      value: 'Units',
      child: Text('units'.tr),
    ),
    DropdownMenuItem(
      value: 'Dozen',
      child: Text('dozen'.tr),
    ),
    DropdownMenuItem(
      value: 'Pair',
      child: Text('pair'.tr),
    ),
    DropdownMenuItem(
      value: 'Meter',
      child: Text('meter'.tr),
    ),
    DropdownMenuItem(
      value: 'Kilogram',
      child: Text('kilogram'.tr),
    ),
    DropdownMenuItem(
      value: 'Gram',
      child: Text('gram'.tr),
    ),
    DropdownMenuItem(
      value: 'Liter',
      child: Text('liter'.tr),
    ),
    DropdownMenuItem(
      value: 'Centimeter',
      child: Text('centimeter'.tr),
    ),
    DropdownMenuItem(
      value: 'Other',
      child: Text('other'.tr),
    ),
  ];
}

int getUnitGroupValue(String unit) {
  switch (unit) {
    case 'Dozen':
      return 12;
    case 'Pair':
      return 2;
    default:
      return 1;
  }
}
