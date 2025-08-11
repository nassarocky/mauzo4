import 'package:cloud_firestore/cloud_firestore.dart';

class Supplier {
  final String id;
  final String owner;
  late final String name;
  final String phone;
  final Timestamp date;
  final double debt; // Amount we owe to supplier
  final double advance; // Amount we paid in advance to supplier
  final List<dynamic> advanceTransactions; // Track advance transactions
  String? note;
  String? image;
  String? email; // Supplier-specific field
  String? address; // Supplier-specific field
  String? company; // Supplier company name
  String? taxNumber; // Supplier tax/VAT number
  List<String>? categories; // Categories of products they supply

  Supplier({
    required this.id,
    required this.owner,
    required this.name,
    required this.phone,
    required this.date,
    this.debt = 0.0,
    this.advance = 0.0,
    this.advanceTransactions = const [],
    this.note,
    this.image,
    this.email,
    this.address,
    this.company,
    this.taxNumber,
    this.categories,
  });

  // Factory method to create a Supplier from Firestore snapshot
  static Supplier fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception("Document data is null for snapshot with ID: ${snapshot.id}");
    }
    
    // Handle date field with proper type checking and conversion
    Timestamp date;
    if (data['date'] == null) {
      date = Timestamp.now();
    } else if (data['date'] is Timestamp) {
      date = data['date'] as Timestamp;
    } else if (data['date'] is DateTime) {
      date = Timestamp.fromDate(data['date'] as DateTime);
    } else if (data['date'] is Map) {
      // Handle Firestore Timestamp format from web
      try {
        final seconds = data['date']['seconds'] as int;
        final nanoseconds = data['date']['nanoseconds'] as int;
        date = Timestamp(seconds, nanoseconds);
      } catch (e) {
        print('Error converting date: $e');
        date = Timestamp.now();
      }
    } else {
      print('Unexpected date format: ${data['date']}');
      date = Timestamp.now();
    }

    // Handle debt and advance with proper type conversion
    double debt = 0.0;
    if (data['debt'] != null) {
      if (data['debt'] is int) {
        debt = (data['debt'] as int).toDouble();
      } else if (data['debt'] is double) {
        debt = data['debt'] as double;
      } else if (data['debt'] is String) {
        debt = double.tryParse(data['debt'] as String) ?? 0.0;
      }
    }

    double advance = 0.0;
    if (data['advance'] != null) {
      if (data['advance'] is int) {
        advance = (data['advance'] as int).toDouble();
      } else if (data['advance'] is double) {
        advance = data['advance'] as double;
      } else if (data['advance'] is String) {
        advance = double.tryParse(data['advance'] as String) ?? 0.0;
      }
    }

    // Handle categories list
    List<String>? categories;
    if (data['categories'] != null) {
      categories = List<String>.from(data['categories'] as List);
    }

    return Supplier(
      id: snapshot.id,
      owner: data['owner'] ?? '',
      name: data['name'] ?? 'Unnamed Supplier',
      phone: data['phone'] ?? '',
      date: date,
      debt: debt,
      advance: advance,
      advanceTransactions: data['advanceTransactions'] ?? [],
      note: data['note'],
      image: data['image'],
      email: data['email'],
      address: data['address'],
      company: data['company'],
      taxNumber: data['taxNumber'],
      categories: categories,
    );
  }

  // Convert Supplier instance to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'owner': owner,
      'name': name,
      'phone': phone,
      'date': date,
      'debt': debt,
      'advance': advance,
      'advanceTransactions': advanceTransactions,
      'note': note,
      'image': image,
      'email': email,
      'address': address,
      'company': company,
      'taxNumber': taxNumber,
      'categories': categories,
    };
  }
}
