import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import '../utils/app_navigation.dart';
import '../utils/constants.dart';
import '../utils/preferences.dart';
import '../services/referral_attribution_service.dart';
import '../utils/business_shop_location.dart';

/// Firestore shop address fields on new business documents.
Map<String, dynamic> _shopLocationPatchForCreate({
  String? shopCountry,
  String? shopCity,
  String? shopStreet,
}) {
  final co = (shopCountry ?? '').trim();
  return BusinessShopLocation.firestoreFields(
    country: co.isEmpty ? BusinessShopLocation.defaultCountry : co,
    city: (shopCity ?? '').trim(),
    street: (shopStreet ?? '').trim(),
  );
}

/// When the user signs up with phone only, store this placeholder email (matches [AuthController.registerWithPhone]).
String emailDerivedFromPhoneE164(String phoneE164) {
  final digits = phoneE164.replaceAll(RegExp(r'[^0-9]'), '');
  return '$digits@hesabumauzo.app';
}

String _resolvedSignupEmail({String? explicitEmail, required String phoneE164}) {
  if (explicitEmail != null && explicitEmail.trim().isNotEmpty) {
    return explicitEmail.trim();
  }
  return emailDerivedFromPhoneE164(phoneE164);
}

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
  final RxBool otpSent = false.obs;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  bool get isUserAuthenticated => FirebaseAuth.instance.currentUser != null;

  /// True after cold-start routing; prevents auth token refresh from resetting the stack to /home.
  bool _authBootstrapDone = false;

  /// [signupPromoCode] from the register form wins over silent pending install/deep-link code.
  Future<Map<String, dynamic>> _installReferrerFieldMap({
    String? signupPromoCode,
  }) async {
    final fromForm =
        ReferralAttributionService.normalizeReferrerCode(signupPromoCode);
    if (fromForm != null && fromForm.isNotEmpty) {
      return {
        'installReferrerCode': fromForm,
        'installReferrerAttributedAt': FieldValue.serverTimestamp(),
      };
    }
    final code = await ReferralAttributionService.getPendingCode();
    if (code == null || code.isEmpty) return {};
    return {
      'installReferrerCode': code,
      'installReferrerAttributedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _clearReferralAfterSuccessfulSignup() async {
    await ReferralAttributionService.clearPending();
  }

  /// Windows/desktop uses the web Firestore channel; the auth token may not be
  /// attached to the first request immediately after sign-in.
  Future<void> _ensureAuthTokenReady(User user) async {
    await user.getIdToken(true);
    await _auth.authStateChanges().firstWhere(
          (u) => u?.uid == user.uid,
          orElse: () => user,
        );
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchGmanUserDoc(
    String uid,
  ) async {
    Future<DocumentSnapshot<Map<String, dynamic>>> read() {
      return _firestore.collection('gmanusers').doc(uid).get();
    }

    try {
      return await read();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      final user = _auth.currentUser;
      if (user == null || user.uid != uid) rethrow;
      debugPrint('Firestore permission-denied on gmanusers/$uid; refreshing auth token...');
      await _ensureAuthTokenReady(user);
      return await read();
    }
  }

  String _resolveActiveBusinessId(List<dynamic> businessList) {
    if (businessList.isEmpty) return '';
    final saved = Preferences.getBusiness();
    if (saved.isNotEmpty && businessList.contains(saved)) {
      return saved;
    }
    return businessList.first.toString();
  }

  String _friendlyLoginError(Object e) {
    if (e is FirebaseException) {
      if (e.code == 'permission-denied') {
        return 'Could not load your account data. Close the app, check your internet connection, and try again.';
      }
      return e.message ?? e.code;
    }
    final text = e.toString();
    if (text.contains('permission-denied') ||
        text.contains('Missing or insufficient permissions')) {
      return 'Could not load your account data. Close the app, check your internet connection, and try again.';
    }
    return text;
  }

  @override
  void onReady() {
    super.onReady();
    _user = Rx<User?>(_auth.currentUser);
    _user.bindStream(_auth.authStateChanges());
    ever(_user, _onAuthUserChanged);
    Future.microtask(() => _runInitialAuthRouting());
  }

  void _resetAuthBootstrap() {
    _authBootstrapDone = false;
  }

  /// Only react to sign-out while the app is running — never force /home on token refresh.
  void _onAuthUserChanged(User? user) {
    if (user != null) return;
    if (!Preferences.isLoggedIn()) {
      if (!AppNavigation.isCurrentRoute('/login')) {
        AppNavigation.logUnexpectedRedirect('auth stream signed out');
        _resetAuthBootstrap();
        AppNavigation.offAllNamed('/login', reason: 'auth_signed_out');
      }
    }
  }

  Future<void> _runInitialAuthRouting() async {
    if (_authBootstrapDone) return;

    final user = _auth.currentUser;
    if (!Preferences.isLoggedIn() || user == null) {
      _authBootstrapDone = true;
      if (!AppNavigation.isCurrentRoute('/login')) {
        AppNavigation.offAllNamed('/login', reason: 'bootstrap_logged_out');
      }
      return;
    }

    await _ensureAuthTokenReady(user);
    await _profileController.updateUserData();
    await _businessController.updateBusinessData();
    _initializePaymentGeneration();
    _authBootstrapDone = true;

    final route = AppNavigation.currentRoute();
    if (route == '/login' || route == '/' || route.isEmpty) {
      AppNavigation.offAllNamed('/home', reason: 'bootstrap_logged_in');
    }
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
  // Reset password via email link (email-registered users)
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

  // Reset password via OTP (phone-registered users).
  // Verifies the OTP, signs in with custom token, then updates the password.
  Future<void> resetPasswordWithOtp({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    isLoading.value = true;
    try {
      final result = await _functions.httpsCallable('verifyOtp').call({
        'phone': phone,
        'code': code,
      });
      final customToken = result.data['token'] as String;
      final userCred = await _auth.signInWithCustomToken(customToken);
      await userCred.user!.updatePassword(newPassword);
      Get.snackbar(
        'Success',
        'Password reset successfully.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
      AppNavigation.offAllNamed('/login', reason: 'password_reset_done');
    } on FirebaseFunctionsException catch (e) {
      Get.snackbar('Error', e.message ?? e.code,
          snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  /// Support-only: sets a user's password via Cloud Function. Caller must be listed in
  /// Firestore `support_admins/{uid}` or have Auth custom claim `admin: true`.
  ///
  /// Prefer [customerPhoneOrEmail]: if it contains `@` it is sent as email, otherwise as phone.
  /// Or pass [targetUid], [email], and [phone] separately.
  Future<void> adminResetUserPassword({
    required String newPassword,
    String? customerPhoneOrEmail,
    String? targetUid,
    String? email,
    String? phone,
  }) async {
    if (newPassword.length < 8) {
      Get.snackbar('Error', 'Password must be at least 8 characters.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    String? outEmail;
    String? outPhone;
    String? outUid = targetUid?.trim();
    final combined = customerPhoneOrEmail?.trim();
    if (combined != null && combined.isNotEmpty) {
      if (combined.contains('@')) {
        outEmail = combined;
      } else {
        outPhone = combined;
      }
    } else {
      if (email != null && email.isNotEmpty) outEmail = email.trim();
      if (phone != null && phone.isNotEmpty) outPhone = phone.trim();
    }

    if ((outUid == null || outUid.isEmpty) &&
        (outEmail == null || outEmail.isEmpty) &&
        (outPhone == null || outPhone.isEmpty)) {
      Get.snackbar('Error', 'Enter the customer\'s phone number or email.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    isLoading.value = true;
    try {
      final payload = <String, dynamic>{'newPassword': newPassword};
      if (outUid != null && outUid.isNotEmpty) {
        payload['targetUid'] = outUid;
      }
      if (outEmail != null && outEmail.isNotEmpty) payload['email'] = outEmail;
      if (outPhone != null && outPhone.isNotEmpty) payload['phone'] = outPhone;

      await _functions.httpsCallable('adminResetUserPassword').call(payload);
      Get.snackbar(
        'Done',
        'Password updated. Tell the user the new temporary password.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on FirebaseFunctionsException catch (_) {
      Get.snackbar(
        'Error',
        'You are not authorized.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (_) {
      Get.snackbar(
        'Error',
        'You are not authorized.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> register(
      String name,
      String email,
      String phone,
      String password,
      String business,
      String mainCurrency,
      String secondaryCurrency, {
      String? signupPromoCode,
      String? shopCountry,
      String? shopCity,
      String? shopStreet,
      }) async {
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
      final Map<String, dynamic> installReferral =
          await _installReferrerFieldMap(signupPromoCode: signupPromoCode);
      // Save business data to Firestore, including the generated business ID and unique store ID
      await businessDocRef.set({
        'name': business,
        'email': email,
        'phone': phoneNumber.value,
        ...installReferral,
        'subscriptionStatus': 'subscription_ontrial',
        'trialStart': FieldValue.serverTimestamp(),
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
        'additionalString1': 'false', // Purchases UI off for staff until owner enables
        'additionalString2': uniqueStoreId,  // Store the unique store ID here
        'additionalList1': [],  // Initialize new list fields with default values
        'additionalList2': [],
        ..._shopLocationPatchForCreate(
          shopCountry: shopCountry,
          shopCity: shopCity,
          shopStreet: shopStreet,
        ),
      });

      // Add user to the 'gmanusers' collection with role 'owner' and the created business
      await _firestore.collection('gmanusers').doc(userCredential.user!.uid).set({
        'id': userCredential.user!.uid,
        'email': email,
        'role': 'owner',
        'phone': phoneNumber.value,
        'name': name,
        'maxBusiness': 2,
        'business': [businessId],  // Store the newly created business ID in the user's document
        'image': '',
        'date': DateTime.now(),
        ...installReferral,
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
      await Preferences.setEnablePurchases('false');

      await _clearReferralAfterSuccessfulSignup();

      // Navigate to the home screen
      print(_auth.currentUser?.uid);
      AppNavigation.offAllNamed('/home', reason: 'auth_login');
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


  Future<void> registerWithPhone({
    required String name,
    required String phone,
    required String password,
    required String business,
    required String mainCurrencyVal,
    required String secondaryCurrencyVal,
    String? signupPromoCode,
    String? shopCountry,
    String? shopCity,
    String? shopStreet,
  }) async {
    isLoading.value = true;
    phoneNumber.value = phone;
    try {
      // Derive a unique email for Firebase Auth from the phone number.
      // Firebase Auth enforces uniqueness, so email-already-in-use ≡ phone already registered.
      final derivedEmail = emailDerivedFromPhoneE164(phone);

      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: derivedEmail,
        password: password,
      );

      final businessDocRef = _firestore.collection('businesses').doc();
      final businessId = businessDocRef.id;
      final uniqueStoreId =
          '${businessId}_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.erase();

      final Map<String, dynamic> installReferral =
          await _installReferrerFieldMap(signupPromoCode: signupPromoCode);
      await businessDocRef.set({
        'name': business,
        'email': derivedEmail,
        'phone': phone,
        ...installReferral,
        'subscriptionStatus': 'subscription_ontrial',
        'trialStart': FieldValue.serverTimestamp(),
        'tin': 'TIN',
        'categories': [],
        'manufacturer': [],
        'location': [],
        'debtEnabled': true,
        'discountPercent': 10,
        'mainCurrency': mainCurrencyVal,
        'reset_time': DateTime.now(),
        'expireWarning': 30,
        'allowSalesView': true,
        'secondaryCurrency': secondaryCurrencyVal,
        'date': DateTime.now(),
        'id': businessId,
        'ownerId': userCredential.user!.uid,
        'reserve': 0.0,
        'additionalDouble1': 0.0,
        'additionalDouble2': 0.0,
        'additionalString1': 'false',
        'additionalString2': uniqueStoreId,
        'additionalList1': [],
        'additionalList2': [],
        ..._shopLocationPatchForCreate(
          shopCountry: shopCountry,
          shopCity: shopCity,
          shopStreet: shopStreet,
        ),
      });

      await _firestore
          .collection('gmanusers')
          .doc(userCredential.user!.uid)
          .set({
        'id': userCredential.user!.uid,
        'email': derivedEmail,
        'role': 'owner',
        'phone': phone,
        'name': name,
        'maxBusiness': 2,
        'business': [businessId],
        'image': '',
        'date': DateTime.now(),
        ...installReferral,
      });

      await firestore
          .collection('employees')
          .doc(businessId)
          .collection('userEmployees')
          .doc(userCredential.user!.uid)
          .set({
        'id': userCredential.user!.uid,
        'email': derivedEmail,
        'role': 'owner',
        'phone': phone,
        'name': name,
        'maxBusiness': 2,
        'business': [businessId],
        'image': '',
        'date': DateTime.now(),
      }, SetOptions(merge: true));

      await Preferences.setPhone(phone);
      await Preferences.setEmail(derivedEmail);
      await Preferences.setEnabletDebt(true);
      await Preferences.setBusiness(businessId);
      await Preferences.setLoggedIn(true);
      await Preferences.setEnablePurchases('false');
      await _clearReferralAfterSuccessfulSignup();
      AppNavigation.offAllNamed('/home', reason: 'auth_login');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('This phone number is already registered.');
      } else if (e.code == 'weak-password') {
        throw Exception('Password is too weak. Use at least 8 characters.');
      } else {
        throw Exception(e.message ?? 'Registration failed.');
      }
    }
    // Exception (phone exists) propagates to UI
    finally {
      isLoading.value = false;
    }
  }

  Future<void> startPhoneVerification(String phoneE164) async {
    isLoading.value = true;
    otpSent.value = false;
    phoneNumber.value = phoneE164;
    try {
      await _functions.httpsCallable('sendOtp').call({'phone': phoneE164});
      otpSent.value = true;
      Get.snackbar(
        'OTP Sent',
        'A verification code was sent to $phoneE164',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on FirebaseFunctionsException catch (e) {
      Get.snackbar(
        'Failed to Send OTP',
        e.message ?? e.code,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      Get.snackbar('Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> confirmOtp({
    required String smsCode,
    required String name,
    required String business,
    required String mainCurrency,
    required String secondaryCurrency,
    String? email,
    String? password,
    String? shopCountry,
    String? shopCity,
    String? shopStreet,
  }) async {
    isLoading.value = true;
    try {
      // Call verifyOtp Cloud Function – returns a Firebase custom token
      final result = await _functions.httpsCallable('verifyOtp').call({
        'phone': phoneNumber.value,
        'code': smsCode,
      });
      final customToken = result.data['token'] as String;
      final userCred = await _auth.signInWithCustomToken(customToken);
      final user = userCred.user;
      if (user == null) throw Exception('Sign-in with custom token failed');
      await _ensureAuthTokenReady(user);

      // Determine if user doc exists
      final userDoc = await _fetchGmanUserDoc(user.uid);
      if (!userDoc.exists) {
        final resolvedEmail = _resolvedSignupEmail(
          explicitEmail: email,
          phoneE164: phoneNumber.value,
        );
        final businessId = await _bootstrapUserAndBusiness(
          user: user,
          name: name,
          phoneE164: phoneNumber.value,
          businessName: business,
          mainCurrency: mainCurrency,
          secondaryCurrency: secondaryCurrency,
          email: resolvedEmail,
          shopCountry: shopCountry,
          shopCity: shopCity,
          shopStreet: shopStreet,
        );

        // Optionally link email/password if provided
        if (email != null && email.isNotEmpty && password != null && password.length >= 8) {
          try {
            await user.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
            await _firestore.collection('gmanusers').doc(user.uid).set({'email': email}, SetOptions(merge: true));
          } catch (e) {
            // If linking fails (e.g., already in use), continue silently
          }
        }

        await Preferences.setPhone(phoneNumber.value);
        await Preferences.setEmail(
          (email != null && email.isNotEmpty)
              ? email.trim()
              : resolvedEmail,
        );
        await Preferences.setBusiness(businessId);
        await Preferences.setEnabletDebt(true);
        await Preferences.setLoggedIn(true);
        await _profileController.updateUserData();
        await _businessController.updateBusinessData();
        AppNavigation.offAllNamed('/home', reason: 'auth_login');
        return;
      }

      // If user already exists (phone login), set prefs and go home
      await ReferralAttributionService.clearPending();
      final userData = userDoc.data() as Map<String, dynamic>;
      final List biz = userData['business'] ?? [];
      final String firstBusiness = _resolveActiveBusinessId(biz);
      await Preferences.setPhone(userData['phone'] ?? phoneNumber.value);
      if ((userData['email'] ?? '').toString().isNotEmpty) {
        await Preferences.setEmail(userData['email']);
      }
      await Preferences.setBusiness(firstBusiness);
      await Preferences.setEnabletDebt(true);
      await Preferences.setLoggedIn(true);
      await _profileController.updateUserData();
      await _businessController.updateBusinessData();
      AppNavigation.offAllNamed('/home', reason: 'auth_login');
    } on FirebaseFunctionsException catch (e) {
      Get.snackbar(
        'OTP Error',
        e.message ?? e.code,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 6),
      );
    } catch (e) {
      Get.snackbar('OTP Error', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      isLoading.value = false;
    }
  }

  Future<String> _bootstrapUserAndBusiness({
    required User user,
    required String name,
    required String phoneE164,
    required String businessName,
    required String mainCurrency,
    required String secondaryCurrency,
    required String email,
    String? shopCountry,
    String? shopCity,
    String? shopStreet,
  }) async {
    // Create business
    DocumentReference businessDocRef = _firestore.collection('businesses').doc();
    String businessId = businessDocRef.id;
    String uniqueStoreId = "${businessId}_${DateTime.now().millisecondsSinceEpoch}";

    final Map<String, dynamic> installReferral = await _installReferrerFieldMap();
    await businessDocRef.set({
      'name': businessName,
      'email': email,
      'phone': phoneE164,
      ...installReferral,
      'subscriptionStatus': 'subscription_ontrial',
      'trialStart': FieldValue.serverTimestamp(),
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
      'id': businessId,
      'ownerId': user.uid,
      'reserve': 0.0,
      'additionalDouble1': 0.0,
      'additionalDouble2': 0.0,
      'additionalString1': 'false',
      'additionalString2': uniqueStoreId,
      'additionalList1': [],
      'additionalList2': [],
      ..._shopLocationPatchForCreate(
        shopCountry: shopCountry,
        shopCity: shopCity,
        shopStreet: shopStreet,
      ),
    });

    // gmanusers
    await _firestore.collection('gmanusers').doc(user.uid).set({
      'id': user.uid,
      'email': email,
      'role': 'owner',
      'phone': phoneE164,
      'name': name,
      'maxBusiness': 2,
      'business': [businessId],
      'image': '',
      'date': DateTime.now(),
      ...installReferral,
    });

    // employees
    await firestore
        .collection('employees')
        .doc(businessId)
        .collection('userEmployees')
        .doc(user.uid)
        .set({
      'id': user.uid,
      'email': email,
      'role': 'owner',
      'phone': phoneE164,
      'name': name,
      'maxBusiness': 2,
      'business': [businessId],
      'image': '',
      'date': DateTime.now(),
    }, SetOptions(merge: true));

    await _clearReferralAfterSuccessfulSignup();

    return businessId;
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
      final user = userCredential.user;
      if (user == null || user.uid.isEmpty) {
        throw Exception('User ID is missing.');
      }
      await _ensureAuthTokenReady(user);
      // Fetch the user's document from Firestore using their UID
      DocumentSnapshot userSnapshot = await _fetchGmanUserDoc(user.uid);

      if (userSnapshot.exists) {
        var userData = userSnapshot.data() as Map<String, dynamic>;
        // Get the business list and take the first value if available
        List businessList = userData['business'] ?? [];
        String firstBusiness = _resolveActiveBusinessId(businessList);
        if (firstBusiness.isEmpty) {
          throw Exception(
            'Your account is not linked to a business. Ask your shop owner to re-assign you.',
          );
        }
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
        await ReferralAttributionService.clearPending();
        // Set login success and navigate to home
        loginSuccess.value = true;
        //  print('UID check: ${_auth.currentUser?.uid}');
        //  print('email check: ${email}');
        AppNavigation.offAllNamed('/home', reason: 'auth_login');
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
        _friendlyLoginError(e),
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
      _resetAuthBootstrap();

      Get.deleteAll();
      Get.put(ThemeController());

      // Reset AuthController properties
      phoneNumber.value = '';
      mainCurrency.value = 'TZS'; // Reset to default
      secondaryCurrency.value = '';
      isLoading.value = false;
      loginSuccess.value = false;

      AppNavigation.offAllNamed('/login', reason: 'logout');
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