import 'package:cloud_firestore/cloud_firestore.dart';

class StockTransaction {
  final String transactionId;
  final String productId;
  final double quantity;
  final double previousQuantity;
  final String transactionType; // e.g., "addition" or "removal"
  final String transactionOrigin;
  final Timestamp timestamp;
  final String userId;
  final double price; // Added field

  StockTransaction({
    required this.transactionId,
    required this.productId,
    required this.quantity,
    required this.previousQuantity,
    required this.transactionType,
    required this.transactionOrigin,
    required this.timestamp,
    required this.userId,
    required this.price, // Add required price in constructor
  });

  // Factory method to create a StockTransaction from Firestore snapshot
  static StockTransaction fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?; // Ensure safe access to data

    if (data == null) {
      throw Exception("Document data is null for snapshot with ID: ${snapshot.id}");
    }

    return StockTransaction(
      transactionId: snapshot.id,
      productId: data['productId'] ?? '',
      quantity: (data['quantity'] ?? 0.0) is int ? (data['quantity'] as int).toDouble() : (data['quantity'] ?? 0.0) as double,
      previousQuantity: (data['previousQuantity'] ?? 0.0) is int ? (data['previousQuantity'] as int).toDouble() : (data['previousQuantity'] ?? 0.0) as double,
      transactionType: data['transactionType'] ?? '',
      transactionOrigin: data['transactionOrigin'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      userId: data['userId'] ?? '',
      price: (data['price'] ?? 0.0) is int ? (data['price'] as int).toDouble() : (data['price'] ?? 0.0) as double,
    );
  }

  // Method to convert StockTransaction instance to Firestore format
  Map<String, dynamic> toFirestore() {
    return {
      'transactionId': transactionId,
      'productId': productId,
      'quantity': quantity,
      'previousQuantity': previousQuantity,
      'transactionType': transactionType,
      'transactionOrigin': transactionOrigin,
      'timestamp': timestamp,
      'userId': userId,
      'price': price, // Include price in the map
    };
  }

  // Add the missing toMap method
  Map<String, dynamic> toMap() {
    return toFirestore(); // Reuse the toFirestore method for the toMap method
  }
}
