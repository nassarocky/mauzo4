import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/theme_controller.dart';
import 'package:mauzo/controllers/pay_role_controller.dart';
import 'package:mauzo/controllers/payment_controller.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/constants.dart';
import '../utils/preferences.dart';


class AuthController extends GetxController {
  static AuthController instance = Get.find();
  final ProfileController _profileController = Get.put(ProfileController());
  final BusinessController _businessController = Get.put(BusinessController());
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Rx<User?> _user;
  final RxBool isLoading = false.obs;
  final phoneNumber = ''.obs;
  final loginSuccess = false.obs;
  final RxString mainCurrency = 'TZS'.obs;  // Default value set to TZS
  final RxString secondaryCurrency = ''.obs;
  final GetStorage _storage = GetStorage();
  bool get isUserAuthenticated => FirebaseAuth.instance.currentUser != null;
  @override
  void onReady() {
    super.onReady();
    _user = Rx<User?>(_auth.currentUser);
    _user.bindStream(_auth.authStateChanges());
    ever(_user, _setInitialScreen);
  }

  _setInitialScreen(User? user) async {
    Future.delayed(Duration.zero, () async {
      if (Preferences.isLoggedIn()) {
        await _profileController.updateUserData();
        await _businessController.updateBusinessData();
        
        // Initialize automatic payment generation after user data is loaded
        _initializePaymentGeneration();
        
        Get.offAllNamed('/home');
      } else if (user == null) {
        Get.offAllNamed('/login');
      }
    });
  }

  void _initializePaymentGeneration() async {
    try {
      // Import controllers dynamically to avoid circular dependencies
      final payRoleController = Get.put(PayRoleController());
      final paymentController = Get.put(PaymentController());
      
      // Wait a bit for controllers to initialize
      await Future.delayed(const Duration(seconds: 2));
      
      // Initialize automatic payment generation
      await paymentController.initializeAutomaticPayments();
      
      print('Automatic payment generation initialized');
    } catch (e) {
      print('Error initializing automatic payment generation: $e');
    }
  }
  // Reset password method
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Get.snackbar(
        "Password Reset",
        "A password reset link has been sent to $email",
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        'TRY AGAIN',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
  Future<void> register(
      String name,
      String email,
      String phone,
      String password,
      String business,
      String mainCurrency,
      String secondaryCurrency,
      ) async {
    phoneNumber.value = phone;
    try {
      isLoading.value = true;

      // Register the user with Firebase Authentication
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Generate a new document in the 'businesses' collection with an auto-generated ID
      DocumentReference businessDocRef = _firestore.collection('businesses').doc();

      // Get the generated business ID
      String businessId = businessDocRef.id;

      // Generate a unique store ID (e.g., using UUID or a combination)
      String uniqueStoreId = "${businessId}_${DateTime.now().millisecondsSinceEpoch}"; // Use a combination of business ID and timestamp
      await _storage.erase();
      // Save business data to Firestore, including the generated business ID and unique store ID
      await businessDocRef.set({
        'name': business,
        'email': email,
        'phone': phoneNumber.value,
        'subscriptionStatus': 'subscription_ontrial',
        'tin': 'TIN',
        'categories': [],
        'manufacturer': [],
        'location': [],
        'debtEnabled': true,
        'discountPercent':10,
        'mainCurrency': mainCurrency,
        'reset_time': DateTime.now(),
        'expireWarning':30,
        'allowSalesView':true,
        'secondaryCurrency': secondaryCurrency,
        'date': DateTime.now(),
        'id': businessId,  // Save the generated ID in the document
        'ownerId': userCredential.user!.uid,
        'reserve': 0.0,  // Initialize the reserve field with a default value of 0.0
        'additionalDouble1': 0.0,  // Initialize new double fields with default values
        'additionalDouble2': 0.0,
        'additionalString1': 'true',  // Initialize new string fields with default values
        'additionalString2': uniqueStoreId,  // Store the unique store ID here
        'additionalList1': [],  // Initialize new list fields with default values
        'additionalList2': [],
      });

      // Add user to the 'gmanusers' collection with role 'owner' and the created business
      await _firestore.collection('gmanusers').doc(userCredential.user!.uid).set({
        'id': userCredential.user!.uid,
        'email': email,
        'role': 'owner',
        'phone': phoneNumber.value,
        'name': name,
        'password': password,
        'maxBusiness': 2,
        'business': [businessId],  // Store the newly created business ID in the user's document
        'image': '',
        'date': DateTime.now(),
      });

      await firestore
          .collection('employees')
          .doc(businessId)
      // Document for the busniess ID in the 'employees' collection
          .collection('userEmployees')
          .doc(userCredential.user!.uid)
      // Document for the user in the 'userEmployees' sub-collection
          .set({
        'id': userCredential.user!.uid,
        'email': email,
        'role': 'owner',
        'phone': phoneNumber.value,
        'name': name,
        'password':'password',
        'maxBusiness': 2,
        'business': [businessId],
        // Store the newly created business ID in the user's document
        'image': '',
        'date': DateTime.now(),
      }, SetOptions(merge: true));
      // Merge with the existing document if any

      // Save user preferences locally (if you have a local storage mechanism)
      await Preferences.setPhone(phoneNumber.value);
      await Preferences.setEmail(email);
      await Preferences.setEnabletDebt(true);
      await Preferences.setBusiness(businessId);
      await Preferences.setLoggedIn(true);


      // Navigate to the home screen
      print(_auth.currentUser?.uid);
      Get.offAllNamed('/home');
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Authentication errors
      if (e.code == 'weak-password') {
        throw Exception('Password is too weak.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('Email is already in use.');
      } else if (e.code == 'invalid-email') {
        throw Exception('Invalid email format.');
      } else {
        throw Exception('An unexpected error occurred.');
      }
    } finally {
      isLoading.value = false;  // Stop loading after completion
    }
  }


  Future<void> login(String email, String password) async {
    isLoading.value = true;
    loginSuccess.value = false;

    try {
      // Attempt to sign in the user using Firebase Authentication
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user?.uid == null || userCredential.user!.uid.isEmpty) {
        throw Exception('User ID is missing.');
      }
      // Fetch the user's document from Firestore using their UID
      DocumentSnapshot userSnapshot = await _firestore
          .collection('gmanusers')
          .doc(userCredential.user!.uid)
          .get();

      if (userSnapshot.exists) {
        var userData = userSnapshot.data() as Map<String, dynamic>;
        // Get the business list and take the first value if available
        List businessList = userData['business'] ?? [];
        String firstBusiness = businessList.isNotEmpty ? businessList[0] : '';
        // Save the fetched user data to preferences
        _profileController.role.value=userData['role'] ?? '';
        _profileController.emailId.value=email;
        _businessController.businessId.value=firstBusiness;

        print('Role checkin auth: ${_profileController.role.value}');
        print('Email check in auth ${_profileController.emailId.value}');
        print('Business ID:check in auth ${_businessController.businessId.value}');
        await Preferences.setPhone(userData['phone'] ?? '');
        await Preferences.setEmail(email);
        await Preferences.setBusiness(firstBusiness); // Store the first value of the business list
        await Preferences.setLoggedIn(true);
        await _profileController.updateUserData();
        await _businessController.updateBusinessData();
        // Set login success and navigate to home
        loginSuccess.value = true;
        //  print('UID check: ${_auth.currentUser?.uid}');
        //  print('email check: ${email}');
        Get.offAllNamed('/home');
      } else {
        throw Exception('User document not found in Firestore.');
      }
    } on FirebaseAuthException catch (e) {
      // Handle Firebase Authentication errors   await _profileController.updateUserData(); with detailed logging
      debugPrint("FirebaseAuthException code: ${e.code}, message: ${e.message}");

      String errorMessage = 'An unexpected error occurred.';
      if (e.code == 'user-not-found') {
        errorMessage = 'User not found.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided.';
      }

      // Show error snackbar for 5 seconds
      Get.snackbar(
        'Login Failed',
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );

    } catch (e) {
      // Handle general errors
      debugPrint("General error: ${e.toString()}");

      Get.snackbar(
        'Login Failed',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false; // Stop the loading indicator after the process is done
    }
  }

  Future<void> logout() async {
    try {

      _profileController.clearUser();
      _businessController.clearBusiness();
      await _auth.signOut();
      await Preferences.setLoggedIn(false);

      Get.deleteAll();
      Get.put(ThemeController());

      // Reset AuthController properties
      phoneNumber.value = '';
      mainCurrency.value = 'TZS'; // Reset to default
      secondaryCurrency.value = '';
      isLoading.value = false;
      loginSuccess.value = false;

      // Navigate to the login screen
      Get.offAllNamed('/login');
    } catch (e) {
      _showErrorSnackbar('Logout failed: ${e.toString()}');
    }
  }

  void deleteAllControllers() {
    // Delete all controllers forcefully


    //Get.delete<BusinessController>(force: true);
    // Get.delete<ProfileController>(force: true);
  }

  void _showErrorSnackbar(String message) {
    Get.snackbar("Error", message, snackPosition: SnackPosition.BOTTOM);
  }



}