import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../controllers/business_controller.dart';
import '../controllers/profile_controller.dart';

class FundSourceService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  Future<void> ensureDefaultCashFundSource([
    String? businessId,
  ]) async {
    final String bizId = businessId ?? _businessController.business['id'] ?? _businessController.businessId.value ?? '';
    if (bizId.isEmpty) return;

    final String currency = _businessController.business['mainCurrency'] ?? 'TZS';
    final cashRef = firestore
        .collection('fundSources')
        .doc(bizId)
        .collection('userFundSources')
        .doc('cash');

    final doc = await cashRef.get();
    if (doc.exists) return; // Already seeded

    await cashRef.set({
      'businessId': bizId,
      'name': 'Cash',
      'type': 'cash',
      'currency': currency,
      'isActive': true,
      'isDefault': true,
      'note': null,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      'createdBy': _profileController.user['id'],
      'updatedBy': _profileController.user['id'],
    });
  }

  Future<void> ensureDefaultBankAndMobile([
    String? businessId,
  ]) async {
    final String bizId = businessId ?? _businessController.business['id'] ?? _businessController.businessId.value ?? '';
    if (bizId.isEmpty) return;

    final String currency = _businessController.business['mainCurrency'] ?? 'TZS';

    final bankRef = firestore
        .collection('fundSources')
        .doc(bizId)
        .collection('userFundSources')
        .doc('bank');
    final bankDoc = await bankRef.get();
    if (!bankDoc.exists) {
      await bankRef.set({
        'businessId': bizId,
        'name': 'Bank',
        'type': 'bank',
        'currency': currency,
        'isActive': true,
        'isDefault': false,
        'note': null,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': _profileController.user['id'],
        'updatedBy': _profileController.user['id'],
      });
    }

    final mobileRef = firestore
        .collection('fundSources')
        .doc(bizId)
        .collection('userFundSources')
        .doc('mobile');
    final mobileDoc = await mobileRef.get();
    if (!mobileDoc.exists) {
      await mobileRef.set({
        'businessId': bizId,
        'name': 'Mobile (Lipa Namba)',
        'type': 'mobile',
        'currency': currency,
        'isActive': true,
        'isDefault': false,
        'note': null,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'createdBy': _profileController.user['id'],
        'updatedBy': _profileController.user['id'],
      });
    }
  }
}
