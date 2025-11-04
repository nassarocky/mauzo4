import 'package:cloud_firestore/cloud_firestore.dart';

class FundSource {
  final String id; // e.g., 'cash', 'bank', 'mobile', 'other' or a custom id
  final String businessId;
  final String name; // Display name
  final String type; // 'cash' | 'bank' | 'mobile' | 'other'
  final String currency; // ISO, e.g., 'TZS'
  final bool isActive;
  final bool isDefault;
  final String? note;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String? createdBy;
  final String? updatedBy;

  FundSource({
    required this.id,
    required this.businessId,
    required this.name,
    required this.type,
    required this.currency,
    required this.isActive,
    required this.isDefault,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'name': name,
      'type': type,
      'currency': currency,
      'isActive': isActive,
      'isDefault': isDefault,
      'note': note,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  factory FundSource.fromMap(String id, Map<String, dynamic> data) {
    return FundSource(
      id: id,
      businessId: data['businessId'] ?? '',
      name: data['name'] ?? id,
      type: data['type'] ?? 'cash',
      currency: data['currency'] ?? 'TZS',
      isActive: (data['isActive'] ?? true) as bool,
      isDefault: (data['isDefault'] ?? false) as bool,
      note: data['note'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'],
      updatedBy: data['updatedBy'],
    );
  }
}
