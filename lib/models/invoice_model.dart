import 'package:cloud_firestore/cloud_firestore.dart';

class InvoiceItem {
  final String productId;
  final String name;
  final int quantity;
  final double price;

  InvoiceItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'quantity': quantity,
      'price': price,
    };
  }

  static InvoiceItem fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      productId: map['productId'],
      name: map['name'],
      quantity: map['quantity'],
      price: map['price'],
    );
  }
}

class Invoice {
  final String id;
  final String owner;
  final List<InvoiceItem> items;
  final DateTime date;
  final double total;

  Invoice({
    required this.id,
    required this.owner,
    required this.items,
    required this.date,
    required this.total,
  });

  // Method to create Invoice instance from Firestore snapshot
  static Invoice fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?; // Safely get the document data

    if (data == null) {
      throw Exception("Document data is null for snapshot with ID: ${snapshot.id}");
    }

    return Invoice(
      id: snapshot.id,
      owner: data['owner'] ?? '',
      items: (data['items'] as List).map((item) => InvoiceItem.fromMap(item)).toList(),
      date: (data['date'] as Timestamp).toDate(),
      total: data['total'] is int ? (data['total'] as int).toDouble() : (data['total'] ?? 0.0) as double,
    );
  }

  // Method to convert Invoice instance to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'owner': owner,
      'items': items.map((item) => item.toMap()).toList(),
      'date': date,
      'total': total,
    };
  }
}
