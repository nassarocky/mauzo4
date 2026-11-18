import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import '../models/business_model.dart';
import '../services/firestore_db.dart';
import '../utils/preferences.dart';
import 'business_controller.dart';

class BusinessListController extends GetxController {
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  final businesses = <BusinessModel>[].obs;
  StreamSubscription<List<BusinessModel>>? _businessSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      _businessSubscription = FirestoreDb().getBusiness().listen((data) {
        businesses.value = data;
      });
    } catch (e) {
      print("Error binding business stream: $e");
    }
  }

  @override
  void onClose() {
    _businessSubscription?.cancel();
    super.onClose();
  }

  void clearBusiness() {
    businesses.clear();
  }

  Future<void> addNewBusiness(
    String name, {
    String shopCountry = 'Tanzania',
    String shopCity = '',
    String shopStreet = '',
  }) async {
    final String? userId = _profileController.user['id'];
    if (userId == null) {
      throw Exception('No authenticated user found');
    }
    final String userRole = _profileController.user['role'] ?? '';
    if (userRole != 'owner') {
      throw Exception('Only business owners can create new businesses');
    }

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'us-central1')
          .httpsCallable('createOwnedBusiness');
      final result = await callable.call({
        'name': name,
        'shopCountry': shopCountry,
        'shopCity': shopCity,
        'shopStreet': shopStreet,
        'currentBusinessId': _businessController.business['id'] ?? '',
      });
      final String newBusinessId =
          (result.data as Map)['businessId']?.toString() ?? '';
      if (newBusinessId.isEmpty) {
        throw Exception('Shop was not created');
      }
      await _profileController.refreshUserData();
      await _businessController.updateBusinessId(newBusinessId);
      await Preferences.setBusiness(newBusinessId);
      Get.forceAppUpdate();
    } on FirebaseFunctionsException catch (error) {
      final message = (error.message ?? '').trim();
      throw Exception(
        message.isEmpty ? 'Failed to add the shop' : message,
      );
    }
  }


}
