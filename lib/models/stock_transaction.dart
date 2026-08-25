import 'package:cloud_firestore/cloud_firestore.dart';

class StockTransaction {
  final String transactionId;
  final String productId;
  final double quantity; // Amount changed (for backward compatibility)
  final double? delta; // Signed movement; authoritative for new rows
  final double previousQuantity; // Quantity before transaction
  final double? newQuantity; // NEW: Quantity after transaction
  final String transactionType; // "addition" or "removal"
  final String transactionOrigin; // "Sale", "Purchase", etc.
  final Timestamp timestamp;
  final String userId;
  final double price;

  // NEW: Enhanced fields for better tracking
  final String? referenceId; // saleId, purchaseId, transferId, etc.
  final String? referenceType; // "sale", "purchase", "transfer", "manual"
  final String? employeeName; // Name of person who made change
  final String? notes; // Reason/description of change
  final double? totalValue; // quantity × price
  final String? operationId; // Idempotency/reconciliation key
  final String? inventoryLocation; // "shop" or "store"
  final Timestamp? occurredAt; // Business event date (may be backdated)
  final bool quantityEstimated; // Before/after came from offline cache

  StockTransaction({
    required this.transactionId,
    required this.productId,
    required this.quantity,
    this.delta,
    required this.previousQuantity,
    this.newQuantity, // Optional for backward compatibility
    required this.transactionType,
    required this.transactionOrigin,
    required this.timestamp,
    required this.userId,
    required this.price,
    this.referenceId, // Optional for backward compatibility
    this.referenceType, // Optional for backward compatibility
    this.employeeName, // Optional for backward compatibility
    this.notes, // Optional for backward compatibility
    this.totalValue, // Optional for backward compatibility
    this.operationId,
    this.inventoryLocation,
    this.occurredAt,
    this.quantityEstimated = false,
  });

  // Factory method to create a StockTransaction from Firestore snapshot
  static StockTransaction fromSnapshot(DocumentSnapshot snapshot) {
    final data =
        snapshot.data() as Map<String, dynamic>?; // Ensure safe access to data

    if (data == null) {
      throw Exception(
        "Document data is null for snapshot with ID: ${snapshot.id}",
      );
    }

    return StockTransaction(
      transactionId: snapshot.id,
      productId: data['productId'] ?? '',
      quantity: (data['quantity'] ?? 0.0) is int
          ? (data['quantity'] as int).toDouble()
          : (data['quantity'] ?? 0.0) as double,
      delta: data['delta'] is num ? (data['delta'] as num).toDouble() : null,
      previousQuantity: (data['previousQuantity'] ?? 0.0) is int
          ? (data['previousQuantity'] as int).toDouble()
          : (data['previousQuantity'] ?? 0.0) as double,
      newQuantity: data['newQuantity'] != null
          ? ((data['newQuantity'] ?? 0.0) is int
                ? (data['newQuantity'] as int).toDouble()
                : (data['newQuantity'] ?? 0.0) as double)
          : null, // Backward compatible - old transactions won't have this
      transactionType: data['transactionType'] ?? '',
      transactionOrigin: data['transactionOrigin'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      userId: data['userId'] ?? '',
      price: (data['price'] ?? 0.0) is int
          ? (data['price'] as int).toDouble()
          : (data['price'] ?? 0.0) as double,
      referenceId: data['referenceId'], // Backward compatible
      referenceType: data['referenceType'], // Backward compatible
      employeeName: data['employeeName'], // Backward compatible
      notes: data['notes'], // Backward compatible
      totalValue: data['totalValue'] != null
          ? ((data['totalValue'] ?? 0.0) is int
                ? (data['totalValue'] as int).toDouble()
                : (data['totalValue'] ?? 0.0) as double)
          : null, // Backward compatible
      operationId: data['operationId']?.toString(),
      inventoryLocation: data['inventoryLocation']?.toString(),
      occurredAt: data['occurredAt'] is Timestamp
          ? data['occurredAt'] as Timestamp
          : null,
      quantityEstimated: data['quantityEstimated'] == true,
    );
  }

  // Method to convert StockTransaction instance to Firestore format
  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'transactionId': transactionId,
      'productId': productId,
      'quantity': quantity,
      'previousQuantity': previousQuantity,
      'transactionType': transactionType,
      'transactionOrigin': transactionOrigin,
      'timestamp': timestamp,
      'userId': userId,
      'price': price,
    };

    // Only add new fields if they have values (keeps old transactions clean)
    if (newQuantity != null) map['newQuantity'] = newQuantity!;
    if (delta != null) map['delta'] = delta!;
    if (referenceId != null) map['referenceId'] = referenceId!;
    if (referenceType != null) map['referenceType'] = referenceType!;
    if (employeeName != null) map['employeeName'] = employeeName!;
    if (notes != null) map['notes'] = notes!;
    if (totalValue != null) map['totalValue'] = totalValue!;
    if (operationId != null) map['operationId'] = operationId!;
    if (inventoryLocation != null) {
      map['inventoryLocation'] = inventoryLocation!;
    }
    if (occurredAt != null) map['occurredAt'] = occurredAt!;
    if (quantityEstimated) map['quantityEstimated'] = true;

    return map;
  }

  // Add the missing toMap method
  Map<String, dynamic> toMap() {
    return toFirestore(); // Reuse the toFirestore method for the toMap method
  }
}
