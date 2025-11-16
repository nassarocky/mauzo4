import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryLoss {
  final String id;
  final String businessId;
  final String productId;
  final String productName;
  final String productCode;
  final double quantity;
  final double unitPrice;
  final double totalValue;
  final String lossType; // 'damaged', 'expired', 'stolen', 'spoiled', 'other'
  final String reason;
  final String? imageUrl;
  final DateTime dateOccurred;
  final DateTime dateRecorded;
  final String recordedBy;
  final String recordedByName;
  final String? transactionId; // Link to transaction record

  InventoryLoss({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.quantity,
    required this.unitPrice,
    required this.totalValue,
    required this.lossType,
    required this.reason,
    this.imageUrl,
    required this.dateOccurred,
    required this.dateRecorded,
    required this.recordedBy,
    required this.recordedByName,
    this.transactionId,
  });

  // Create from Firestore snapshot
  factory InventoryLoss.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return InventoryLoss(
      id: snapshot.id,
      businessId: data['businessId'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productCode: data['productCode'] ?? '',
      quantity: (data['quantity'] ?? 0).toDouble(),
      unitPrice: (data['unitPrice'] ?? 0).toDouble(),
      totalValue: (data['totalValue'] ?? 0).toDouble(),
      lossType: data['lossType'] ?? 'other',
      reason: data['reason'] ?? '',
      imageUrl: data['imageUrl'],
      dateOccurred: (data['dateOccurred'] as Timestamp).toDate(),
      dateRecorded: (data['dateRecorded'] as Timestamp).toDate(),
      recordedBy: data['recordedBy'] ?? '',
      recordedByName: data['recordedByName'] ?? '',
      transactionId: data['transactionId'],
    );
  }

  // Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'businessId': businessId,
      'productId': productId,
      'productName': productName,
      'productCode': productCode,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalValue': totalValue,
      'lossType': lossType,
      'reason': reason,
      'imageUrl': imageUrl,
      'dateOccurred': Timestamp.fromDate(dateOccurred),
      'dateRecorded': Timestamp.fromDate(dateRecorded),
      'recordedBy': recordedBy,
      'recordedByName': recordedByName,
      'transactionId': transactionId,
    };
  }

  // Get display name for loss type
  String get lossTypeDisplayName {
    switch (lossType) {
      case 'damaged':
        return 'Damaged';
      case 'expired':
        return 'Expired';
      case 'stolen':
        return 'Stolen/Lost';
      case 'spoiled':
        return 'Spoiled';
      case 'other':
        return 'Other';
      default:
        return lossType;
    }
  }

  // Get icon for loss type
  static String getLossTypeIcon(String lossType) {
    switch (lossType) {
      case 'damaged':
        return '🔨'; // Damaged
      case 'expired':
        return '📅'; // Expired
      case 'stolen':
        return '🚨'; // Stolen
      case 'spoiled':
        return '🗑️'; // Spoiled
      case 'other':
        return '📋'; // Other
      default:
        return '❓';
    }
  }

  // Available loss types
  static List<Map<String, String>> get lossTypes => [
        {'value': 'damaged', 'label': 'Damaged'},
        {'value': 'expired', 'label': 'Expired'},
        {'value': 'stolen', 'label': 'Stolen/Lost'},
        {'value': 'spoiled', 'label': 'Spoiled'},
        {'value': 'other', 'label': 'Other'},
      ];
}
