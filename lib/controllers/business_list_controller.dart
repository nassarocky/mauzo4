import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  Future<void> addNewBusiness(String name) async {
    try {
      // ✅ Step 1: Get the authenticated user's UID
      String? userId = _profileController.user['id'];



      if (userId == null) {
        print("[ERROR] No authenticated user found.");
        return;
      }

      print("[DEBUG] Authenticated userId: $userId");

      // ✅ Step 2: Generate a new business ID
      String newBusinessId = FirebaseFirestore.instance.collection('businesses').doc().id;

      print("[DEBUG] New business ID: $newBusinessId");

      // ✅ Step 3: Prepare business data
      final Map<String, dynamic> currentBusiness = _businessController.business.isEmpty
          ? {}
          : _businessController.business;

      Map<String, dynamic> newBusinessData = {
        'name': name,
        'email': currentBusiness['email'] ?? '',
        'phone': currentBusiness['phone'] ?? '',
        'tin': currentBusiness['tin'] ?? '',
        'allowSalesView': currentBusiness['allowSalesView'] ?? true,
        'subscriptionStatus': currentBusiness['subscriptionStatus'] ?? 'subscription_ontrial',
        'discountPercent': currentBusiness['discountPercent'] ?? 0,
        'categories': currentBusiness['categories'] ?? [],
        'manufacturer': currentBusiness['manufacturer'] ?? [],
        'location': currentBusiness['location'] ?? [],
        'debtEnabled': currentBusiness['debtEnabled'] ?? true,
        'expireWarning': currentBusiness['expireWarning'] ?? 30,
        'mainCurrency': currentBusiness['mainCurrency'] ?? 'TZS',
        'reset_time': DateTime.now(),
        'secondaryCurrency': currentBusiness['secondaryCurrency'] ?? '',
        'date': DateTime.now(),
        'id': newBusinessId,
        'ownerId': userId,
        'reserve': 0.0,
        'additionalDouble1': 0.0,
        'additionalDouble2': 0.0,
        'additionalString1': '',
        'additionalString2': '',
        'additionalList1': [],
        'additionalList2': [],
      };

      print("[DEBUG] Business data prepared: $newBusinessData");

      // ✅ Step 4: Save the business document
      await FirebaseFirestore.instance.collection('businesses').doc(newBusinessId).set(newBusinessData);

      print("[SUCCESS] Business created successfully!");


      // ✅ Step 6: Update gmanusers document
      DocumentReference userDocRef = FirebaseFirestore.instance.collection('gmanusers').doc(userId);

      DocumentSnapshot userDoc = await userDocRef.get();

      if (userDoc.exists) {
        List<dynamic> businesses = userDoc['business'] ?? [];

        // Check if business already exists in the list
        if (!businesses.contains(newBusinessId)) {
          businesses.insert(0, newBusinessId); // Insert the new business at the beginning
        }

        // ✅ Update the business list
        await userDocRef.update({
          'business': businesses,
        });

        print("[SUCCESS] gmanusers business list updated successfully!");



        // ✅ Step 5: Add user to the employees collection for this business
        await FirebaseFirestore.instance
            .collection('employees')
            .doc(newBusinessId)
            .collection('userEmployees')
            .doc(userId) // Use userId here for consistency
            .set({
          ..._profileController.user, // Assuming _profileController.user has all fields
          'business': [newBusinessId], // You can add the business explicitly too
        }, SetOptions(merge: true));

        print("[SUCCESS] User added to employees subcollection.");


        // ✅ Step 7: Update state in controllers and preferences
        await _businessController.updateBusinessId(newBusinessId);
        await Preferences.setBusiness(newBusinessId);

        Get.forceAppUpdate(); // Refresh UI
      } else {
        print("[ERROR] gmanusers document not found for user: $userId");
      }

    } catch (error) {
      print("[EXCEPTION] Failed to add new business: $error");
    }
  }


}
