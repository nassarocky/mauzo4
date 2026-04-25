import 'package:cloud_firestore/cloud_firestore.dart';

class FundSourceService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static const List<Map<String, dynamic>> defaultFundSources = [
    {
      'id': 'cash',
      'label': 'Cash',
      'value': 'cash',
      'ledgerType': 'cash',
      'isPermanent': true,
      'isDefault': true,
      'isActive': true,
    },
    {
      'id': 'bank',
      'label': 'Bank',
      'value': 'bank',
      'ledgerType': 'bank',
      'isPermanent': false,
      'isDefault': true,
      'isActive': true,
    },
    {
      'id': 'mobile',
      'label': 'Lipa Namba (Mobile)',
      'value': 'mobile',
      'ledgerType': 'mobile',
      'isPermanent': false,
      'isDefault': true,
      'isActive': true,
    },
    {
      'id': 'other',
      'label': 'Other Source',
      'value': 'other',
      'ledgerType': 'cash',
      'isPermanent': false,
      'isDefault': true,
      'isActive': true,
    },
  ];

  CollectionReference _col(String bizId) => firestore
      .collection('fundSources')
      .doc(bizId)
      .collection('userFundSources');

  /// Firestore may store isActive as bool, int (0/1), or string — normalize for UI filtering.
  static bool normalizeIsActive(dynamic v, {bool defaultActive = true}) {
    if (v == null) return defaultActive;
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v.toString().toLowerCase().trim();
    if (s == 'false' || s == '0' || s == 'no') return false;
    if (s == 'true' || s == '1' || s == 'yes') return true;
    return defaultActive;
  }

  Map<String, dynamic> _docToFundSourceMap(QueryDocumentSnapshot d) {
    final raw = d.data();
    final map = Map<String, dynamic>.from((raw is Map) ? raw as Map : <String, dynamic>{});
    map['id'] = d.id;
    // Ensure value/label exist (some legacy or manual docs omit them → dropdown breaks or filters items out)
    final String valueStr =
        (map['value'] ?? map['id'] ?? d.id).toString();
    map['value'] = valueStr.isNotEmpty ? valueStr : d.id;
    map['label'] = (map['label'] ?? map['name'] ?? map['value'] ?? d.id).toString();
    if (map['ledgerType'] == null && map['type'] != null) {
      map['ledgerType'] = map['type'];
    }
    final rawActive = map['isActive'];
    bool active = normalizeIsActive(rawActive, defaultActive: true);
    // Legacy/corrupt data: int 0 in Firestore for default rows was treated as "inactive"
    // in the app; real toggles use bool false from the client.
    if (rawActive is num &&
        rawActive == 0 &&
        const {'cash', 'bank', 'mobile', 'other'}.contains(d.id)) {
      active = true;
    }
    map['isActive'] = active;
    return map;
  }

  Future<List<Map<String, dynamic>>> loadFundSources([String? businessId]) async {
    final String bizId = businessId ?? '';
    if (bizId.isEmpty) return List.from(defaultFundSources);
    try {
      var snap = await _col(bizId).get();
      if (snap.docs.isEmpty) {
        await seedDefaults(bizId);
        snap = await _col(bizId).get();
      }
      if (snap.docs.isEmpty) {
        return List.from(defaultFundSources);
      }
      final list = snap.docs.map(_docToFundSourceMap).toList();
      list.sort((a, b) {
        if (a['isPermanent'] == true) return -1;
        if (b['isPermanent'] == true) return 1;
        final aDefault = a['isDefault'] == true ? 0 : 1;
        final bDefault = b['isDefault'] == true ? 0 : 1;
        if (aDefault != bDefault) return aDefault - bDefault;
        return (a['label'] ?? '').toString().compareTo((b['label'] ?? '').toString());
      });
      return list;
    } catch (e) {
      print('FundSourceService.loadFundSources error: $e');
      return List.from(defaultFundSources);
    }
  }

  Future<void> seedDefaults([String? businessId]) async {
    final String bizId = businessId ?? '';
    if (bizId.isEmpty) return;
    for (final fs in defaultFundSources) {
      final id = fs['id'] as String;
      final ref = _col(bizId).doc(id);
      final doc = await ref.get();
      final isPermanent = id == 'cash';
      if (!doc.exists) {
        await ref.set({
          ...fs,
          'isPermanent': isPermanent,
          'createdAt': Timestamp.now(),
        });
      } else {
        await ref.set({'isPermanent': isPermanent}, SetOptions(merge: true));
      }
    }
  }

  Future<void> addFundSource({
    required String businessId,
    required String label,
    required String ledgerType,
  }) async {
    if (businessId.isEmpty) return;
    final ref = _col(businessId).doc();
    await ref.set({
      'id': ref.id,
      'label': label.trim(),
      'value': ref.id,
      'ledgerType': ledgerType,
      'isPermanent': false,
      'isDefault': false,
      'isActive': true,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateFundSource(String id, {
    required String businessId,
    String? label,
    bool? isActive,
  }) async {
    if (businessId.isEmpty) return;
    final updates = <String, dynamic>{};
    if (label != null) updates['label'] = label.trim();
    if (isActive != null) updates['isActive'] = isActive;
    if (updates.isEmpty) return;
    await _col(businessId).doc(id).update(updates);
  }

  Future<void> deleteFundSource(String id, {required String businessId}) async {
    if (businessId.isEmpty) return;
    await _col(businessId).doc(id).delete();
  }

}
