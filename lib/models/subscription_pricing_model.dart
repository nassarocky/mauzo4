import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionPricingModel {
  final Map<String, int> tier1; // 1 business
  final Map<String, int> tier2; // 2 businesses
  final Map<String, int> tier3; // 3 businesses
  final Map<String, int> tier4; // 4 businesses
  final Map<String, int> tier5Plus; // 5 businesses; 6+ add [extraShop] per shop
  /// Optional per-shop add-on from the 6th shop. Missing = derived from tier4 -> tier5Plus.
  final Map<String, int> extraShop;
  final Map<String, String> durationSeconds;
  final Timestamp? lastUpdated;
  final String? updatedBy;

  SubscriptionPricingModel({
    required this.tier1,
    required this.tier2,
    required this.tier3,
    required this.tier4,
    required this.tier5Plus,
    this.extraShop = const {},
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
      extraShop: Map<String, int>.from(data['extraShop'] ?? {}),
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
      if (extraShop.isNotEmpty) 'extraShop': extraShop,
      'durationSeconds': durationSeconds,
      'lastUpdated': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    };
  }

  /// Per-shop increment from the 6th shop: [extraShop], else the tier4 -> tier5Plus
  /// step, else the single-shop price.
  int extraShopIncrement(String key) {
    final custom = extraShop[key] ?? 0;
    if (custom > 0) return custom;
    final t4 = tier4[key] ?? 0;
    final t5 = tier5Plus[key] ?? 0;
    if (t4 > 0 && t5 > t4) return t5 - t4;
    return tier1[key] ?? 0;
  }

  Map<String, int> getPricesForBusinessCount(int count) {
    if (count <= 1) return tier1;
    if (count == 2) return tier2;
    if (count == 3) return tier3;
    if (count == 4) return tier4;
    if (count == 5) return tier5Plus;

    // 6 or more: every extra shop adds to the 5-shop price.
    final extraShops = count - 5;
    return {
      for (final entry in tier5Plus.entries)
        if (entry.value > 0)
          entry.key: entry.value + extraShops * extraShopIncrement(entry.key),
    };
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
