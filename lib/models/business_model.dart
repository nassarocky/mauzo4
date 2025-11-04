import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessModel {
  final String id;
  final String ownerId;
  final List<String> categories;
  final List<String> expenseCategories;
  final List<String> manufacturer;
  final List<String> location;
  final String phone;
  final String tin;
  final String email;
  final String name;
  final String logo;
  final Timestamp reset_time;
  final String subscriptionStatus;
  final String mainCurrency;
  final String secondaryCurrency;
  final dynamic date;
  final bool debtEnabled;
  final bool multiFundEnabled; // allow multiple fund sources
  final double reserve;
  final int expireWarning; // in month
  final bool allowSalesView; // New field
  final int discountPercent; // New field with default value

  // Additional fields
  final double additionalDouble1;
  final double additionalDouble2;
  final String additionalString1;
  final String additionalString2;
  final List<String> additionalList1;
  final List<String> additionalList2;

  BusinessModel({
    required this.id,
    this.ownerId = '',
    this.categories = const [],
    this.expenseCategories = const [],
    this.manufacturer = const [],
    this.location = const [],
    required this.phone,
    required this.tin,
    required this.email,
    required this.name,
    required this.reset_time,
    required this.subscriptionStatus,
    required this.mainCurrency,
    required this.secondaryCurrency,
    required this.date,
    this.debtEnabled = true,
    this.multiFundEnabled = false,
    this.expireWarning = 30,
    this.logo = '',
    this.reserve = 0.0,
    this.allowSalesView = true, // Default value
    this.discountPercent = 10, // Default value
    this.additionalDouble1 = 0.0,
    this.additionalDouble2 = 0.0,
    this.additionalString1 = '',
    this.additionalString2 = '',
    this.additionalList1 = const [],
    this.additionalList2 = const [],
  });

  // Factory method to create a BusinessModel from Firestore snapshot
  static BusinessModel fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;

    if (data == null) {
      throw Exception("Document data is null for snapshot with ID: ${snapshot.id}");
    }

    return BusinessModel(
      id: snapshot.id,
      phone: data['phone'] ?? '',
      tin: data['tin'] ?? '',
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      logo: data['logo'] ?? '',
      reset_time: data['reset_time'] ?? Timestamp.now(),
      subscriptionStatus: data['subscriptionStatus'] ?? '',
      mainCurrency: data['mainCurrency'] ?? '',
      secondaryCurrency: data['secondaryCurrency'] ?? '',
      date: data['date'],
      categories: List<String>.from(data['categories'] ?? const []),
      expenseCategories: List<String>.from(data['expenseCategories'] ?? const []),
      manufacturer: List<String>.from(data['manufacturer'] ?? const []),
      location: List<String>.from(data['location'] ?? const []),
      debtEnabled: data['debtEnabled'] ?? true,
      multiFundEnabled: data['multiFundEnabled'] ?? false,
      reserve: data['reserve'] != null ? data['reserve'].toDouble() : 0.0,
      expireWarning: data['expireWarning'] != null ? data['expireWarning'].toInt() : 30,
      allowSalesView: data['allowSalesView'] ?? true,
      discountPercent: data['discountPercent'] != null ? data['discountPercent'].toInt() : 10,
      additionalDouble1: data['additionalDouble1'] != null ? data['additionalDouble1'].toDouble() : 0.0,
      additionalString1: data['additionalString1'] ?? '',
      additionalString2: data['additionalString2'] ?? '',
      additionalList1: List<String>.from(data['additionalList1'] ?? const []),
      additionalList2: List<String>.from(data['additionalList2'] ?? const []),
      ownerId: data['ownerId'] ?? '',
    );
  }

  // Method to convert BusinessModel instance to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'ownerId': ownerId,
      'categories': categories,
      'expenseCategories': expenseCategories,
      'manufacturer': manufacturer,
      'location': location,
      'phone': phone,
      'tin': tin,
      'email': email,
      'name': name,
      'reset_time': reset_time,
      'subscriptionStatus': subscriptionStatus,
      'mainCurrency': mainCurrency,
      'secondaryCurrency': secondaryCurrency,
      'date': date,
      'debtEnabled': debtEnabled,
      'multiFundEnabled': multiFundEnabled,
      'reserve': reserve,
      'expireWarning': expireWarning,
      'allowSalesView': allowSalesView,
      'discountPercent': discountPercent,
      'additionalDouble1': additionalDouble1,
      'additionalDouble2': additionalDouble2,
      'additionalString1': additionalString1,
      'additionalString2': additionalString2,
      'additionalList1': additionalList1,
      'additionalList2': additionalList2,
    };
  }
}

