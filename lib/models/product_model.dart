import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Product {
  final String owner, id, name, code, storeId;
  final String? category;
  String? image;

  // Converted all int variables to double
  double quantity;      // Shop stock quantity
  double total;         // Converted from int
  double price;
  double count;
  double buyingPrice;
  double discount;
  String manufacturer;
  String location;
  String details;
  double understock;    // Converted from int

  // New fields for store stock and reserve data
  double storeQuantity; // Converted from int
  String reserveString1;
  String reserveString2;
  double reserveDouble1;
  double reserveDouble2;
  List<String> reserveList1;
  List<String> reserveList2;

  // New field for expire date
  DateTime? expireDate;

  Product({
    required this.owner,
    required this.id,
    required this.name,
    this.storeId = '',
    required this.code,
    this.category,
    this.image,
    this.quantity = 0.0,
    this.count = 0.0,
    this.total = 0.0,
    required this.price,
    this.buyingPrice = 0.0,
    this.discount = 0.0,
    this.manufacturer = '',
    this.location = '',
    this.details = '',
    this.understock = 0.0,
    this.storeQuantity = 0.0,
    this.reserveString1 = '',
    this.reserveString2 = '',
    this.reserveDouble1 = 0.0,
    this.reserveDouble2 = 0.0,
    this.reserveList1 = const [],
    this.reserveList2 = const [],
    this.expireDate,
  });

  static Product fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception("Document data is null for snapshot with ID: ${snapshot.id}");
    }

    double convertToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      return double.tryParse(value.toString()) ?? 0.0;
    }

    return Product(
      owner: data['owner'] as String? ?? '',
      id: data['id'] as String? ?? snapshot.id,
      name: data['name'] as String? ?? 'Unnamed Product',
      storeId: data['storeId'] as String? ?? '',
      code: data['code'] as String? ?? '',
      category: data['category'] as String?,
      image: data['image'] as String?,
      quantity: convertToDouble(data['quantity']),
      count: convertToDouble(data['count']),
      total: convertToDouble(data['total']),
      manufacturer: data['manufacturer'] as String? ?? '',
      location: data['location'] as String? ?? '',
      details: data['details'] as String? ?? '',
      understock: convertToDouble(data['understock']),
      storeQuantity: convertToDouble(data['storeQuantity']),
      reserveString1: data['reserveString1'] as String? ?? '',
      reserveString2: data['reserveString2'] as String? ?? '',
      price: convertToDouble(data['price']),
      buyingPrice: convertToDouble(data['buyingPrice']),
      discount: convertToDouble(data['discount']),
      reserveDouble1: convertToDouble(data['reserveDouble1']),
      reserveDouble2: convertToDouble(data['reserveDouble2']),
      reserveList1: List<String>.from(data['reserveList1'] ?? []),
      reserveList2: List<String>.from(data['reserveList2'] ?? []),
      expireDate: data['expireDate'] != null
          ? (data['expireDate'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'owner': owner,
      'name': name,
      'code': code,
      'category': category,
      'image': image,
      'quantity': quantity,
      'count': count,
      'total': total,
      'price': price,
      'buyingPrice': buyingPrice,
      'discount': discount,
      'manufacturer': manufacturer,
      'location': location,
      'details': details,
      'understock': understock,
      'storeQuantity': storeQuantity,
      'reserveString1': reserveString1,
      'reserveString2': reserveString2,
      'reserveDouble1': reserveDouble1,
      'reserveDouble2': reserveDouble2,
      'reserveList1': reserveList1,
      'reserveList2': reserveList2,
      'expireDate': expireDate != null ? Timestamp.fromDate(expireDate!) : null,
    };
  }

  InlineSpan getQuantityWithUnitSpan({
    Color quantityColor = Colors.black,
    Color unitColor = Colors.grey,
    double fontSize = 16.0,
  }) {
    String unit = reserveString1.isNotEmpty ? reserveString1 : 'unit';
    String formattedQuantity = quantity % 1 == 0
        ? quantity.toStringAsFixed(0)
        : quantity.toStringAsFixed(2);

    return TextSpan(
      children: [
        TextSpan(
          text: '$formattedQuantity ',
          style: TextStyle(color: quantityColor, fontSize: fontSize),
        ),
        TextSpan(
          text: unit,
          style: TextStyle(color: unitColor, fontSize: fontSize),
        ),
      ],
    );
  }

  Map<String, dynamic> toMap() => toFirestore();
}
