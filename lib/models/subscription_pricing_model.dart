import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPricingModel {
  final Map<String, int> tier1; // 1 business
  final Map<String, int> tier2; // 2 businesses
  final Map<String, int> tier3; // 3 businesses
  final Map<String, int> tier4; // 4 businesses
  final Map<String, int> tier5Plus; // 5+ businesses
  final Map<String, String> durationSeconds;
  final Timestamp? lastUpdated;
  final String? updatedBy;

  SubscriptionPricingModel({
    required this.tier1,
    required this.tier2,
    required this.tier3,
    required this.tier4,
    required this.tier5Plus,
    required this.durationSeconds,
    this.lastUpdated,
    this.updatedBy,
  });

  factory SubscriptionPricingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return SubscriptionPricingModel(
      tier1: Map<String, int>.from(data['tier1'] ?? {}),
      tier2: Map<String, int>.from(data['tier2'] ?? {}),
      tier3: Map<String, int>.from(data['tier3'] ?? {}),
      tier4: Map<String, int>.from(data['tier4'] ?? {}),
      tier5Plus: Map<String, int>.from(data['tier5Plus'] ?? {}),
      durationSeconds: Map<String, String>.from(data['durationSeconds'] ?? {}),
      lastUpdated: data['lastUpdated'] as Timestamp?,
      updatedBy: data['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tier1': tier1,
      'tier2': tier2,
      'tier3': tier3,
      'tier4': tier4,
      'tier5Plus': tier5Plus,
      'durationSeconds': durationSeconds,
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  Map<String, int> getPricesForBusinessCount(int count) {
    if (count == 1) return tier1;
    if (count == 2) return tier2;
    if (count == 3) return tier3;
    if (count == 4) return tier4;
    return tier5Plus; // 5 or more
  }

  static SubscriptionPricingModel getDefault() {
    return SubscriptionPricingModel(
      tier1: {
        'week': 5000,
        'month': 15000,
        'sixMonths': 75000,
        'year': 130000,
      },
      tier2: {
        'week': 10000,
        'month': 30000,
        'sixMonths': 150000,
        'year': 260000,
      },
      tier3: {
        'week': 15000,
        'month': 45000,
        'sixMonths': 225000,
        'year': 390000,
      },
      tier4: {
        'week': 20000,
        'month': 60000,
        'sixMonths': 300000,
        'year': 520000,
      },
      tier5Plus: {
        'week': 25000,
        'month': 75000,
        'sixMonths': 375000,
        'year': 650000,
      },
      durationSeconds: {
        'week': '604800',
        'month': '2592000',
        'sixMonths': '15552000',
        'year': '31622400',
      },
    );
  }
}
