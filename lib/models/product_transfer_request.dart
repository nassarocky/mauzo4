import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

class ProductTransferRequest {
  final String id;
  final String productId;
  final String fromBusinessId;
  final String toBusinessId;
  final String status; // 'pending', 'accepted', 'rejected'
  final String requestedByUserId;
  final String? respondedByUserId;
  final Timestamp requestedAt;
  final Timestamp? respondedAt;
  final double quantity; // Current quantity of the product
  final double transferQuantity; // Quantity to be transferred
  final String productName; // Name of the product being transferred
  final String? productOwner; // Actual owner of the product
  final List<Map<String, dynamic>>? products; // For batch transfers

  ProductTransferRequest({
    required this.id,
    required this.productId,
    required this.fromBusinessId,
    required this.toBusinessId,
    required this.status,
    required this.requestedByUserId,
    this.respondedByUserId,
    required this.requestedAt,
    this.respondedAt,
    required this.quantity,
    required this.transferQuantity,
    required this.productName,
    this.productOwner,
    this.products, // Add products to constructor
  });

  factory ProductTransferRequest.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Document data is null for snapshot with ID: ${snapshot.id}');
    }
    // Parse products array if present
    List<Map<String, dynamic>>? productsList;
    if (data.containsKey('products') && data['products'] is List) {
      productsList = (data['products'] as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      // If Firestore returns List<dynamic>, convert each to Map<String, dynamic>
      if (productsList.isEmpty && (data['products'] as List).isNotEmpty) {
        productsList = (data['products'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
    return ProductTransferRequest(
      id: snapshot.id,
      productId: data['productId'] ?? '',
      fromBusinessId: data['fromBusinessId'] ?? '',
      toBusinessId: data['toBusinessId'] ?? '',
      status: data['status'] ?? 'pending',
      requestedByUserId: data['requestedByUserId'] ?? '',
      respondedByUserId: data['respondedByUserId'],
      requestedAt: data['requestedAt'] ?? Timestamp.now(),
      respondedAt: data['respondedAt'],
      quantity: (data['quantity'] ?? 0.0).toDouble(),
      transferQuantity: (data['transferQuantity'] ?? 0.0).toDouble(),
      productName: data['productName'] ?? 'Unknown Product',
      productOwner: data['productOwner'],
      products: productsList,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = {
      'productId': productId,
      'fromBusinessId': fromBusinessId,
      'toBusinessId': toBusinessId,
      'status': status,
      'requestedByUserId': requestedByUserId,
      'respondedByUserId': respondedByUserId,
      'requestedAt': requestedAt,
      'respondedAt': respondedAt,
      'quantity': quantity,
      'transferQuantity': transferQuantity,
      'productName': productName,
      'productOwner': productOwner,
    };
    if (products != null) {
      map['products'] = products;
    }
    return map;
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'productId': productId,
      'fromBusinessId': fromBusinessId,
      'toBusinessId': toBusinessId,
      'status': status,
      'requestedByUserId': requestedByUserId,
      'respondedByUserId': respondedByUserId,
      'requestedAt': requestedAt,
      'respondedAt': respondedAt,
      'quantity': quantity,
      'transferQuantity': transferQuantity,
      'productName': productName,
      'productOwner': productOwner,
    };
    if (products != null) {
      map['products'] = products;
    }
    return map;
  }

  Future<void> acceptRequest() async {
    final result = await FirebaseFunctions.instance
      .httpsCallable('acceptTransferRequest')
      .call({
        'fromBusinessId': fromBusinessId,
        'toBusinessId': toBusinessId,
        'productId': productId,
        'transferRequestId': id,
        'quantity': transferQuantity,
      });
  }
} 