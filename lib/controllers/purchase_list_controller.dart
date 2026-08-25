import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/purchase_list_draft.dart';
import '../models/supplier_model.dart';
import '../utils/constants.dart';
import 'business_controller.dart';
import 'profile_controller.dart';

class PurchaseListController extends GetxController {
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  final drafts = <PurchaseListDraft>[].obs;
  final isLoading = false.obs;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  String get businessId => _businessController.businessId.value;

  CollectionReference<Map<String, dynamic>> get _draftsRef => firestore
      .collection('purchaseLists')
      .doc(businessId)
      .collection('drafts');

  @override
  void onInit() {
    super.onInit();
    bindDrafts();
  }

  void bindDrafts() {
    _subscription?.cancel();
    if (businessId.isEmpty) {
      drafts.clear();
      return;
    }
    _subscription = _draftsRef
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      drafts.value = snapshot.docs
          .map(PurchaseListDraft.fromSnapshot)
          .where((draft) => draft.status != 'converted')
          .toList();
    });
  }

  Future<String> saveDraft({
    String? draftId,
    Supplier? supplier,
    required List<Map<String, dynamic>> products,
    String note = '',
  }) async {
    if (businessId.isEmpty) throw Exception('Business ID is missing');
    if (products.isEmpty) throw Exception('Select at least one product');

    final ref = draftId == null || draftId.isEmpty
        ? _draftsRef.doc()
        : _draftsRef.doc(draftId);
    final creating = draftId == null || draftId.isEmpty;
    final profile = _profileController.user;
    final data = <String, dynamic>{
      'businessId': businessId,
      'owner': businessId,
      'supplierId': supplier?.id ?? '',
      'supplierName': supplier?.name ?? '',
      'supplierPhone': supplier?.phone ?? '',
      'products': products,
      'status': 'draft',
      'createdBy':
          (profile['id'] ?? FirebaseAuth.instance.currentUser?.uid ?? '')
              .toString(),
      'createdByName': (profile['name'] ?? '').toString(),
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (creating) 'createdAt': FieldValue.serverTimestamp(),
      if (creating) 'sendCount': 0,
    };
    await ref.set(data, SetOptions(merge: true));
    return ref.id;
  }

  Future<void> deleteDraft(String draftId) async {
    if (draftId.isEmpty) return;
    await _draftsRef.doc(draftId).delete();
  }

  Future<void> markConverted(
    String draftId,
    String purchaseId,
  ) async {
    if (draftId.isEmpty || purchaseId.isEmpty) return;
    await _draftsRef.doc(draftId).update({
      'status': 'converted',
      'convertedPurchaseId': purchaseId,
      'convertedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }
}
