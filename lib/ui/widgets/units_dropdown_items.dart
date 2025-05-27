import 'package:flutter/material.dart';

List<DropdownMenuItem<String>> getUnitDropdownItems() {
  return [
    DropdownMenuItem(
      value: 'Units',
      child: Text('Units'),
    ),
    DropdownMenuItem(
      value: 'Dozen',
      child: Text('Dozen'),
    ),
    DropdownMenuItem(
      value: 'Pair',
      child: Text('Pair'),
    ),
    DropdownMenuItem(
      value: 'Meter',
      child: Text('Meter'),
    ),
    DropdownMenuItem(
      value: 'Kilogram',
      child: Text('Kilogram'),
    ),
    DropdownMenuItem(
      value: 'Gram',
      child: Text('Gram'),
    ),
    DropdownMenuItem(
      value: 'Liter',
      child: Text('Liter'),
    ),
    DropdownMenuItem(
      value: 'Centimeter',
      child: Text('Centimeter'),
    ),
    DropdownMenuItem(
      value: 'Other',
      child: Text('Other'),
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
