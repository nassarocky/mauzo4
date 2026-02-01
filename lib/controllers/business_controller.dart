import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/business_model.dart';
import '../utils/constants.dart';
import '../utils/preferences.dart';

class BusinessController extends GetxController {
  final Rx<Map<String, dynamic>> _business = Rx<Map<String, dynamic>>({});
  Map<String, dynamic> get business => _business.value;
  final Rx<String> businessId = "".obs;

  Future<void> updateBusinessId(String businessIdd) async {
    if (businessIdd.isNotEmpty) {
      print('Updating businessId to: $businessIdd'); // Debugging
      businessId.value = businessIdd; // Update the reactive businessId
      await Preferences.setBusiness(businessIdd); // Persist the business ID
      await updateBusinessData(); // Fetch and update the business data
      print('businessId updated to: ${businessId.value}'); // Confirm update
    } else {
      print('Business ID is empty, skipping update.');
    }
  }
  void clearBusiness() {
   _business.value.clear(); // Clear the contents of the reactive map
    businessId.value = '';   // Reset the reactive businessId
  }
/*
  Future<bool> hasInternetConnection({int timeoutSeconds = 6}) async {
    // Step 1: Check if Wi-Fi or mobile data is turned on
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult == ConnectivityResult.none) {
      return false; // No network connection
    }

    // Step 2: Check if internet is reachable with a timeout
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        Duration(seconds: timeoutSeconds),
        onTimeout: () {
          return [];
        },
      );
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true; // Internet is accessible
      }
    } catch (e) {
      return false;
    }

    return false; // Internet is not accessible
  }*/
  Future<void> updateBusinessData() async {
    try {
      if (businessId.value.isNotEmpty) {
        print('Fetching business data for ID: ${businessId.value}'); // Debugging

        var snapshot = await firestore
            .collection('businesses')
            .doc(businessId.value) // 🔥 direct document access
            .get();

        if (snapshot.exists) {
          var business = BusinessModel.fromSnapshot(snapshot);

          _business.value = {
            'name': business.name,
            'categories': business.categories,
            'expenseCategories': business.expenseCategories,
            'units': business.additionalList1,
            'manufacturer': business.manufacturer,
            'location': business.location,
            'email': business.email,
            'logo': business.logo,
            'expireWarning': business.expireWarning,
            'allowSalesView': business.allowSalesView,
            'discountPercent': business.discountPercent,
            'phone': business.phone,
            'tin': business.tin,
            'debtEnabled': business.debtEnabled,
            'multiFundEnabled': business.multiFundEnabled,
            'reset_time': business.reset_time,
            'subscriptionStatus': business.subscriptionStatus,
            'id': business.id,
            'owner': business.ownerId,
            'storeId': business.additionalString2,
            'purchases': business.additionalString1,
            'mainCurrency': business.mainCurrency,
            'secondaryCurrency': business.secondaryCurrency,
            'date': business.date,
            'trialStart': business.trialStart,
            'paymentStart': business.paymentStart,
            'paymentLast': business.paymentLast,
          };

          print('Business data updated: ${_business.value}');
        } else {
          print('No business found for ID: ${businessId.value}');
          _business.value = {};
        }

      } else {
        print('Business ID is empty, cannot fetch business data.');
      }
    } catch (e) {
      print('Error fetching business data: $e');
      errorSnackbar('Error fetching business data: $e');
    }
    update(); // Notify listeners of state changes
  }



  Future<void> copyProductsToNewBusiness() async {
    String oldBusinessId = 'zwj25mxWE2mg8Uo8zGzl';
    String newBusinessId = 'o1CkKYKjlvhXKnoII2lrYSUtAax1';
    try {
      // Reference to the original products collection
      final oldProductsRef = firestore
          .collection('products')
          .doc(oldBusinessId)
          .collection('userProducts');

      // Reference to the new store products collection
      final newStoreRef = firestore
          .collection('store')
          .doc(newBusinessId)
          .collection('userStore');

      // Get all products from the old business collection
      final oldProductsSnapshot = await oldProductsRef.get();

      // Loop through each product
      for (var oldProductDoc in oldProductsSnapshot.docs) {
        var oldProductData = oldProductDoc.data();
        String productId = oldProductDoc.id;  // Use the same ID as the original product

        // Prepare new product data with quantity explicitly set to zero
        final newProductData = {
          ...oldProductData,  // Copy existing fields
          'quantity': 0,  // Set the quantity to zero
        };

        // Use the same document ID for the store product in the new business
        final newProductRef = newStoreRef.doc(productId);

        // Set the new product data in the store collection with quantity set to zero
        await newProductRef.set(newProductData);
      }

      print("Products copied successfully to store with quantity set to zero!");
      successSnackbar("Products copied successfully to store with quantity set to zero!");
    } catch (e) {
      print("Failed to copy products: $e");
    }
  }


  // Method to add a new business


  Future<bool> isAccountActive() async {
    await updateBusinessData();
    return _business.value['subscriptionStatus'] == 'subscription_ok' || _business.value['subscriptionStatus'] == 'subscription_ontrial';
  }

  // Get subscription expiry date (works for both trial and paid)
  DateTime? getSubscriptionExpiryDate() {
    // PAID BUSINESS: Use paymentLast
    if (_business.value['paymentLast'] != null) {
      return (_business.value['paymentLast'] as Timestamp).toDate();
    }
    
    // TRIAL BUSINESS: Calculate trialStart + 30 days
    if (_business.value['trialStart'] != null) {
      final trialStart = (_business.value['trialStart'] as Timestamp).toDate();
      return trialStart.add(Duration(days: 30));
    }
    
    // NEW BUSINESS: No dates set yet
    return null;
  }

  // Calculate days until subscription expires
  int? getDaysUntilSubscriptionExpiry() {
    final expiryDate = getSubscriptionExpiryDate();
    if (expiryDate == null) return null;
    
    final now = DateTime.now();
    final difference = expiryDate.difference(now);
    
    return difference.inDays;
  }

  // Check if should show subscription warning
  bool shouldShowSubscriptionWarning() {
    final daysLeft = getDaysUntilSubscriptionExpiry();
    if (daysLeft == null) return false;
    
    // Show warning 7 days before expiry
    const warningThreshold = 7;
    return daysLeft >= 0 && daysLeft <= warningThreshold;
  }

  // Get subscription type for display
  String getSubscriptionType() {
    if (_business.value['paymentLast'] != null) {
      return 'Paid';
    }
    if (_business.value['trialStart'] != null) {
      return 'Trial';
    }
    // Fallback: check subscriptionStatus if no date fields
    final status = _business.value['subscriptionStatus'];
    if (status == 'subscription_ontrial') {
      return 'Trial';
    }
    if (status == 'subscription_ok') {
      return 'Paid';
    }
    return 'Unknown';
  }

  // Get formatted expiry date string
  String? getFormattedExpiryDate() {
    final expiryDate = getSubscriptionExpiryDate();
    if (expiryDate == null) return null;
    
    return '${expiryDate.day.toString().padLeft(2, '0')}.${expiryDate.month.toString().padLeft(2, '0')}.${expiryDate.year}';
  }
}
