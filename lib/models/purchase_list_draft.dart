import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseListDraft {
  const PurchaseListDraft({
    required this.id,
    required this.businessId,
    required this.supplierId,
    required this.supplierName,
    required this.supplierPhone,
    required this.products,
    required this.status,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    this.note = '',
    this.lastSentAt,
    this.sendCount = 0,
    this.convertedPurchaseId,
    this.convertedAt,
  });

  final String id;
  final String businessId;
  final String supplierId;
  final String supplierName;
  final String supplierPhone;
  final List<Map<String, dynamic>> products;
  final String status;
  final String createdBy;
  final String createdByName;
  final String note;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final Timestamp? lastSentAt;
  final int sendCount;
  final String? convertedPurchaseId;
  final Timestamp? convertedAt;

  factory PurchaseListDraft.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    final now = Timestamp.now();
    return PurchaseListDraft(
      id: snapshot.id,
      businessId: (data['businessId'] ?? data['owner'] ?? '').toString(),
      supplierId: (data['supplierId'] ?? '').toString(),
      supplierName: (data['supplierName'] ?? '').toString(),
      supplierPhone: (data['supplierPhone'] ?? '').toString(),
      products: (data['products'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      status: (data['status'] ?? 'draft').toString(),
      createdBy: (data['createdBy'] ?? '').toString(),
      createdByName: (data['createdByName'] ?? '').toString(),
      note: (data['note'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp ? data['createdAt'] : now,
      updatedAt: data['updatedAt'] is Timestamp ? data['updatedAt'] : now,
      lastSentAt:
          data['lastSentAt'] is Timestamp ? data['lastSentAt'] : null,
      sendCount: (data['sendCount'] as num?)?.toInt() ?? 0,
      convertedPurchaseId: data['convertedPurchaseId']?.toString(),
      convertedAt:
          data['convertedAt'] is Timestamp ? data['convertedAt'] : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'owner': businessId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'supplierPhone': supplierPhone,
      'products': products,
      'status': status,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'note': note,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'sendCount': sendCount,
      if (lastSentAt != null) 'lastSentAt': lastSentAt,
      if (convertedPurchaseId != null)
        'convertedPurchaseId': convertedPurchaseId,
      if (convertedAt != null) 'convertedAt': convertedAt,
    };
  }

  double get totalQuantity => products.fold<double>(
        0,
        (total, item) =>
            total + ((item['quantity'] as num?)?.toDouble() ?? 0),
      );
}
