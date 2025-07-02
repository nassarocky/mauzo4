import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:mauzo/controllers/profile_controller.dart';
import 'package:mauzo/controllers/business_controller.dart';
import 'package:mauzo/models/product_transfer_request.dart';
import 'package:mauzo/models/stock_transaction.dart';
import 'package:mauzo/services/firestore_db.dart';
import 'package:mauzo/utils/constants.dart';

class ProductTransferController extends GetxController {
  final ProfileController _profileController = Get.find();
  final BusinessController _businessController = Get.find();

  // Observable variables
  final incomingTransferRequests = <ProductTransferRequest>[].obs;
  final outgoingTransferRequests = <ProductTransferRequest>[].obs;
  final allTransferRequests = <ProductTransferRequest>[].obs;

  // Stream subscriptions
  StreamSubscription<List<ProductTransferRequest>>? _incomingSubscription;
  StreamSubscription<List<ProductTransferRequest>>? _outgoingSubscription;
  StreamSubscription<List<ProductTransferRequest>>? _allSubscription;

  @override
  void onInit() {
    super.onInit();
    try {
      // Use .listen instead of .bindStream - exactly like ProductController
      _incomingSubscription = FirestoreDb().getIncomingTransferRequests().listen((data) {
        incomingTransferRequests.value = data;
      });
      
      _outgoingSubscription = FirestoreDb().getOutgoingTransferRequests().listen((data) {
        outgoingTransferRequests.value = data;
      });
      
      _allSubscription = FirestoreDb().getAllTransferRequests().listen((data) {
        allTransferRequests.value = data;
      });
    } catch (e) {
      print("Error initializing ProductTransferController: $e");
    }
  }

  @override
  void onClose() {
    _incomingSubscription?.cancel();
    _outgoingSubscription?.cancel();
    _allSubscription?.cancel();
    super.onClose();
  }

  // Create a new transfer request
  Future<void> createTransferRequest({
    required String productId,
    required String fromBusinessId,
    required String toBusinessId,
    required String requestedByUserId,
    required double transferQuantity,
  }) async {
    try {
      final String? business = _businessController.businessId.value;
      if (business == null || business.isEmpty) {
        print('Business ID is null, cannot create transfer request.');
        errorSnackbar("Business ID is null");
        return;
      }

      if (transferQuantity <= 0) {
        throw Exception('Transfer quantity must be greater than 0');
      }

      print('Creating transfer request from $fromBusinessId to $toBusinessId for product $productId with quantity $transferQuantity');

      // Get the source product to check quantity
      final sourceProductRef = firestore
          .collection('products')
          .doc(fromBusinessId)
          .collection('userProducts')
          .doc(productId);

      final sourceProductDoc = await sourceProductRef.get();
      if (!sourceProductDoc.exists) {
        print('[Transfer] ERROR: Source product not found in business $fromBusinessId with product ID $productId');
        throw Exception('Source product not found in business $fromBusinessId');
      }

      final sourceProductData = sourceProductDoc.data() as Map<String, dynamic>;
      final currentQuantity = (sourceProductData['quantity'] ?? 0.0).toDouble();
      final productOwner = sourceProductData['owner'] ?? fromBusinessId;

      print('[Transfer] Found product: name=${sourceProductData['name']}, owner=$productOwner, currentQuantity=$currentQuantity');

      if (currentQuantity < transferQuantity) {
        throw Exception('Insufficient quantity. Available: $currentQuantity, Requested: $transferQuantity');
      }

      // Create transfer request in the fromBusiness collection
      final transferRef = firestore
          .collection('product_transfer_requests')
          .doc(fromBusinessId)
          .collection('userTransferRequests')
          .doc();

      final transferData = {
        'id': transferRef.id,
        'productId': productId,
        'fromBusinessId': fromBusinessId,
        'toBusinessId': toBusinessId,
        'status': 'pending',
        'requestedByUserId': requestedByUserId,
        'respondedByUserId': null,
        'requestedAt': Timestamp.now(),
        'respondedAt': null,
        'quantity': currentQuantity, // Current quantity of the product
        'transferQuantity': transferQuantity, // Quantity to be transferred
        'productName': sourceProductData['name'] ?? 'Unknown Product',
        'productOwner': productOwner, // Store the actual product owner
      };

      await transferRef.set(transferData);
      print('Created transfer request in fromBusiness collection: ${transferRef.id}');

      // Also create a copy in the toBusiness collection for easy access
      final toBusinessRef = firestore
          .collection('product_transfer_requests')
          .doc(toBusinessId)
          .collection('userTransferRequests')
          .doc(transferRef.id);

      await toBusinessRef.set(transferData);
      print('Created transfer request in toBusiness collection: ${transferRef.id}');

      successSnackbar('Transfer request created successfully');
      
      // Force refresh the transfer requests to update UI immediately
      await refreshTransferRequests();
    } catch (e) {
      print('Error creating transfer request: $e');
      errorSnackbar('Error creating transfer request: $e');
      rethrow;
    }
  }

  // Accept a transfer request
  Future<void> acceptTransferRequest(String requestId, String responderUserId) async {
    try {
      final String? business = _businessController.businessId.value;
      if (business == null || business.isEmpty) {
        print('Business ID is null, cannot accept transfer request.');
        errorSnackbar("Business ID is null");
        return;
      }

      // Fetch transfer request
      final docRef = firestore
          .collection('product_transfer_requests')
          .doc(business)
          .collection('userTransferRequests')
          .doc(requestId);
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Transfer request not found');
      }
      final data = doc.data() as Map<String, dynamic>;
      final productId = data['productId'];
      String fromBusinessId = data['fromBusinessId'];
      final toBusinessId = data['toBusinessId'];
      final transferQuantity = (data['transferQuantity'] ?? 0.0).toDouble();

      print('[Transfer] Accepting: fromBusinessId=$fromBusinessId, toBusinessId=$toBusinessId, productId=$productId, transferQuantity=$transferQuantity');

      // Try to fetch the product from the source business
      DocumentReference sourceProductRef = firestore
          .collection('products')
          .doc(fromBusinessId)
          .collection('userProducts')
          .doc(productId);
      DocumentSnapshot sourceProductDoc = await sourceProductRef.get();

      // Fallback: If not found, try to fetch from the product's actual owner
      if (!sourceProductDoc.exists) {
        print('[Transfer] Product not found under fromBusinessId=$fromBusinessId. Trying fallback to product.owner...');
        // Try to get the owner from the transfer request data (if available)
        String? fallbackOwner = data['productOwner'] ?? data['owner'];
        if (fallbackOwner != null && fallbackOwner != fromBusinessId) {
          fromBusinessId = fallbackOwner;
          sourceProductRef = firestore
              .collection('products')
              .doc(fromBusinessId)
              .collection('userProducts')
              .doc(productId);
          sourceProductDoc = await sourceProductRef.get();
        }
      }

      if (!sourceProductDoc.exists) {
        print('[Transfer] ERROR: Source product not found in Firestore. fromBusinessId=$fromBusinessId, productId=$productId');
        errorSnackbar('Source product not found in business $fromBusinessId. Please check product ownership and try again.');
        return;
      }

      final sourceProductData = sourceProductDoc.data() as Map<String, dynamic>;
      final currentQuantity = (sourceProductData['quantity'] ?? 0.0).toDouble();

      if (currentQuantity < transferQuantity) {
        throw Exception('Insufficient quantity in source. Available: $currentQuantity, Requested: $transferQuantity');
      }

      // Update the transfer request status in both businesses
      final updateData = {
        'status': 'accepted',
        'respondedByUserId': responderUserId,
        'respondedAt': Timestamp.now(),
      };

      // Update in current business
      await docRef.update(updateData);
      print('Updated transfer request in current business');

      // Update in from business
      final fromBusinessRef = firestore
          .collection('product_transfer_requests')
          .doc(fromBusinessId)
          .collection('userTransferRequests')
          .doc(requestId);
      await fromBusinessRef.update(updateData);
      print('Updated transfer request in from business');

      // Reduce quantity in source business
      final newSourceQuantity = currentQuantity - transferQuantity;
      await sourceProductRef.update({'quantity': newSourceQuantity});
      print('Reduced quantity in source business from $currentQuantity to $newSourceQuantity');

      // Check if product exists in destination business
      final destProductRef = firestore
          .collection('products')
          .doc(toBusinessId)
          .collection('userProducts')
          .doc(productId);

      final destProductDoc = await destProductRef.get();

      if (destProductDoc.exists) {
        // Product exists in destination, add quantity
        final destProductData = destProductDoc.data() as Map<String, dynamic>;
        final destQuantity = (destProductData['quantity'] ?? 0.0).toDouble();
        final newQuantity = destQuantity + transferQuantity;

        await destProductRef.update({
          'quantity': newQuantity,
          'owner': toBusinessId, // Update owner to destination business
        });
        print('Added quantity to existing product in destination business from $destQuantity to $newQuantity');
      } else {
        // Product doesn't exist in destination, create it
        final newProductData = {
          ...sourceProductData,
          'quantity': transferQuantity,
          'owner': toBusinessId,
          'businessId': toBusinessId,
        };

        await destProductRef.set(newProductData);
        print('Created new product in destination business with quantity $transferQuantity');
      }

      // Log the transfer transaction in both businesses
      await _logTransferTransaction(
        fromBusinessId,
        productId,
        transferQuantity,
        currentQuantity,
        'transfer_out',
        'Product Transfer Out',
      );

      await _logTransferTransaction(
        toBusinessId,
        productId,
        transferQuantity,
        destProductDoc.exists ? (destProductDoc.data() as Map<String, dynamic>)['quantity'] ?? 0.0 : 0.0,
        'transfer_in',
        'Product Transfer In',
      );

      successSnackbar('Transfer request accepted successfully');
      
      // Force refresh the transfer requests to update UI immediately
      await refreshTransferRequests();
    } catch (e) {
      print('Error accepting transfer request: $e');
      errorSnackbar('Error accepting transfer request: $e');
      rethrow;
    }
  }

  // Helper method to log transfer transactions
  Future<void> _logTransferTransaction(
    String businessId,
    String productId,
    double quantity,
    double previousQuantity,
    String transactionType,
    String transactionOrigin,
  ) async {
    try {
      final transactionRef = firestore
          .collection('transactions')
          .doc(businessId)
          .collection('usersTransactions')
          .doc();

      final stockTransaction = StockTransaction(
        transactionId: transactionRef.id,
        productId: productId,
        quantity: quantity,
        previousQuantity: previousQuantity,
        transactionType: transactionType,
        transactionOrigin: transactionOrigin,
        timestamp: Timestamp.now(),
        userId: businessId,
        price: 0.0, // Price not relevant for transfers
      );

      await transactionRef.set(stockTransaction.toMap());
      print('Logged transfer transaction for business: $businessId');
    } catch (e) {
      print('Error logging transfer transaction: $e');
    }
  }

  // Reject a transfer request
  Future<void> rejectTransferRequest(String requestId, String responderUserId) async {
    try {
      final String? business = _businessController.businessId.value;
      if (business == null || business.isEmpty) {
        print('Business ID is null, cannot reject transfer request.');
        errorSnackbar("Business ID is null");
        return;
      }

      print('Rejecting transfer request: $requestId');

      final updateData = {
        'status': 'rejected',
        'respondedByUserId': responderUserId,
        'respondedAt': Timestamp.now(),
      };

      // Get the transfer request to find the from business
      final docRef = firestore
          .collection('product_transfer_requests')
          .doc(business)
          .collection('userTransferRequests')
          .doc(requestId);
      
      final doc = await docRef.get();
      if (!doc.exists) {
        throw Exception('Transfer request not found');
      }
      
      final data = doc.data() as Map<String, dynamic>;
      final fromBusinessId = data['fromBusinessId'];

      // Update in current business
      await docRef.update(updateData);
      print('Updated transfer request in current business');

      // Update in from business
      final fromBusinessRef = firestore
          .collection('product_transfer_requests')
          .doc(fromBusinessId)
          .collection('userTransferRequests')
          .doc(requestId);
      await fromBusinessRef.update(updateData);
      print('Updated transfer request in from business');

      successSnackbar('Transfer request rejected successfully');
      
      // Force refresh the transfer requests to update UI immediately
      await refreshTransferRequests();
    } catch (e) {
      print('Error rejecting transfer request: $e');
      errorSnackbar('Error rejecting transfer request: $e');
      rethrow;
    }
  }

  // Get business name by ID
  Future<String> getBusinessName(String businessId) async {
    try {
      final doc = await firestore
          .collection('businesses')
          .doc(businessId)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['name'] ?? businessId;
      }
      return businessId;
    } catch (e) {
      print('Error getting business name: $e');
      return businessId;
    }
  }

  // Get product details by ID
  Future<Map<String, dynamic>?> getProductDetails(String productId) async {
    try {
      final String? business = _businessController.businessId.value;
      if (business == null || business.isEmpty) {
        return null;
      }

      final productQuery = await firestore
          .collection('products')
          .doc(business)
          .collection('userProducts')
          .doc(productId)
          .get();

      if (productQuery.exists) {
        return productQuery.data();
      }
      return null;
    } catch (e) {
      print('Error getting product details: $e');
      return null;
    }
  }

  // Clear all transfer requests (for cleanup)
  void clearTransferRequests() {
    incomingTransferRequests.value.clear();
    outgoingTransferRequests.value.clear();
    allTransferRequests.value.clear();
  }

  // Manual refresh method to force update the lists
  Future<void> refreshTransferRequests() async {
    try {
      print('Manually refreshing transfer requests...');
      
      // Add a small delay to ensure Firestore updates are processed
      await Future.delayed(Duration(milliseconds: 500));
      
      // Force refresh by re-subscribing to streams
      _incomingSubscription?.cancel();
      _outgoingSubscription?.cancel();
      _allSubscription?.cancel();
      
      // Re-initialize streams
      _incomingSubscription = FirestoreDb().getIncomingTransferRequests().listen((data) {
        incomingTransferRequests.value = data;
        print('Refreshed incoming transfer requests: ${data.length} items');
      });
      
      _outgoingSubscription = FirestoreDb().getOutgoingTransferRequests().listen((data) {
        outgoingTransferRequests.value = data;
        print('Refreshed outgoing transfer requests: ${data.length} items');
      });
      
      _allSubscription = FirestoreDb().getAllTransferRequests().listen((data) {
        allTransferRequests.value = data;
        print('Refreshed all transfer requests: ${data.length} items');
      });
    } catch (e) {
      print('Error refreshing transfer requests: $e');
    }
  }

  // Transfer store products between businesses
  Future<void> createStoreTransferRequest({
    required String productId,
    required String fromBusinessId,
    required String toBusinessId,
    required double transferQuantity,
    required String requestedByUserId,
  }) async {
    try {
      print('Creating store transfer request from $fromBusinessId to $toBusinessId for product $productId with quantity $transferQuantity');

      // Get the source store product to check quantity
      final sourceStoreProductRef = firestore
          .collection('store')
          .doc(fromBusinessId)
          .collection('userStore')
          .doc(productId);

      final sourceStoreProductDoc = await sourceStoreProductRef.get();
      if (!sourceStoreProductDoc.exists) {
        print('[Store Transfer] ERROR: Source store product not found in business $fromBusinessId with product ID $productId');
        throw Exception('Source store product not found in business $fromBusinessId');
      }

      final sourceStoreProductData = sourceStoreProductDoc.data() as Map<String, dynamic>;
      final currentStoreQuantity = (sourceStoreProductData['quantity'] ?? 0.0).toDouble();
      final productOwner = sourceStoreProductData['owner'] ?? fromBusinessId;

      if (currentStoreQuantity < transferQuantity) {
        throw Exception('Insufficient store stock. Available: $currentStoreQuantity, Requested: $transferQuantity');
      }

      // Create transfer request in fromBusiness collection
      final fromTransferRef = firestore
          .collection('store_transfer_requests')
          .doc(fromBusinessId)
          .collection('userStoreTransferRequests')
          .doc();

      final transferData = {
        'id': fromTransferRef.id,
        'productId': productId,
        'fromBusinessId': fromBusinessId,
        'toBusinessId': toBusinessId,
        'status': 'pending',
        'requestedByUserId': requestedByUserId,
        'respondedByUserId': null,
        'requestedAt': Timestamp.now(),
        'respondedAt': null,
        'quantity': currentStoreQuantity,
        'transferQuantity': transferQuantity,
        'productName': sourceStoreProductData['name'] ?? 'Unknown Product',
        'productOwner': productOwner,
        'transferType': 'store', // Indicate this is a store transfer
      };

      await fromTransferRef.set(transferData);
      print('Created store transfer request in fromBusiness collection');

      // Create transfer request in toBusiness collection
      final toTransferRef = firestore
          .collection('store_transfer_requests')
          .doc(toBusinessId)
          .collection('userStoreTransferRequests')
          .doc(fromTransferRef.id);

      await toTransferRef.set(transferData);
      print('Created store transfer request in toBusiness collection');

      successSnackbar('Store transfer request created successfully');
      
      // Force refresh the transfer requests to update UI immediately
      await refreshTransferRequests();
    } catch (e) {
      print('Error creating store transfer request: $e');
      errorSnackbar('Error creating store transfer request: $e');
      rethrow;
    }
  }

  Future<void> acceptStoreTransferRequest(ProductTransferRequest request) async {
    try {
      print('Accepting store transfer request: ${request.id}');

      final data = request.toMap();
      String fromBusinessId = data['fromBusinessId'];
      String toBusinessId = data['toBusinessId'];
      String productId = data['productId'];
      double transferQuantity = (data['transferQuantity'] ?? 0.0).toDouble();
      String respondedByUserId = _businessController.businessId.value!;

      // Get source store product
      final sourceStoreProductRef = firestore
          .collection('store')
          .doc(fromBusinessId)
          .collection('userStore')
          .doc(productId);

      final sourceStoreProductDoc = await sourceStoreProductRef.get();
      
      // Fallback: If not found, try to fetch from the product's actual owner
      if (!sourceStoreProductDoc.exists) {
        print('[Store Transfer] Product not found under fromBusinessId=$fromBusinessId. Trying fallback to product.owner...');
        String? fallbackOwner = data['productOwner'] ?? data['owner'];
        if (fallbackOwner != null && fallbackOwner != fromBusinessId) {
          fromBusinessId = fallbackOwner;
          final fallbackSourceRef = firestore
              .collection('store')
              .doc(fromBusinessId)
              .collection('userStore')
              .doc(productId);
          final fallbackDoc = await fallbackSourceRef.get();
          if (fallbackDoc.exists) {
            print('[Store Transfer] Found product in fallback location: $fromBusinessId');
          } else {
            throw Exception('Store product not found in any location');
          }
        } else {
          throw Exception('Store product not found in business $fromBusinessId');
        }
      }

      final sourceStoreProductData = sourceStoreProductDoc.data() as Map<String, dynamic>;
      final currentSourceQuantity = (sourceStoreProductData['quantity'] ?? 0.0).toDouble();

      if (currentSourceQuantity < transferQuantity) {
        throw Exception('Insufficient store stock in source business');
      }

      // Get or create destination store product
      final destStoreProductRef = firestore
          .collection('store')
          .doc(toBusinessId)
          .collection('userStore')
          .doc(productId);

      final destStoreProductDoc = await destStoreProductRef.get();
      double currentDestQuantity = 0.0;

      if (destStoreProductDoc.exists) {
        final destStoreProductData = destStoreProductDoc.data() as Map<String, dynamic>;
        currentDestQuantity = (destStoreProductData['quantity'] ?? 0.0).toDouble();
      } else {
        // Create store product in destination if it doesn't exist
        final newStoreProductData = Map<String, dynamic>.from(sourceStoreProductData);
        newStoreProductData['quantity'] = 0.0;
        newStoreProductData['owner'] = toBusinessId;
        await destStoreProductRef.set(newStoreProductData);
      }

      // Update quantities
      final newSourceQuantity = currentSourceQuantity - transferQuantity;
      final newDestQuantity = currentDestQuantity + transferQuantity;

      await sourceStoreProductRef.update({'quantity': newSourceQuantity});
      await destStoreProductRef.update({'quantity': newDestQuantity});

      // Update transfer request status
      final fromTransferRef = firestore
          .collection('store_transfer_requests')
          .doc(fromBusinessId)
          .collection('userStoreTransferRequests')
          .doc(request.id);

      final toTransferRef = firestore
          .collection('store_transfer_requests')
          .doc(toBusinessId)
          .collection('userStoreTransferRequests')
          .doc(request.id);

      final updateData = {
        'status': 'accepted',
        'respondedByUserId': respondedByUserId,
        'respondedAt': Timestamp.now(),
      };

      await fromTransferRef.update(updateData);
      await toTransferRef.update(updateData);

      // Log transaction in both businesses
      final sourceTransactionRef = firestore
          .collection('transactions')
          .doc(fromBusinessId)
          .collection('usersTransactions')
          .doc();

      final sourceTransaction = StockTransaction(
          transactionId: sourceTransactionRef.id,
          productId: productId,
          quantity: transferQuantity,
          previousQuantity: currentSourceQuantity,
          transactionType: 'removal',
          transactionOrigin: 'Store Transfer Out',
          timestamp: Timestamp.now(),
          userId: respondedByUserId,
          price: (sourceStoreProductData['price'] ?? 0.0).toDouble()
      );

      await sourceTransactionRef.set(sourceTransaction.toMap());

      final destTransactionRef = firestore
          .collection('transactions')
          .doc(toBusinessId)
          .collection('usersTransactions')
          .doc();

      final destTransaction = StockTransaction(
          transactionId: destTransactionRef.id,
          productId: productId,
          quantity: transferQuantity,
          previousQuantity: currentDestQuantity,
          transactionType: 'addition',
          transactionOrigin: 'Store Transfer In',
          timestamp: Timestamp.now(),
          userId: respondedByUserId,
          price: (sourceStoreProductData['price'] ?? 0.0).toDouble()
      );

      await destTransactionRef.set(destTransaction.toMap());

      successSnackbar('Store transfer request accepted successfully');
      
      // Force refresh the transfer requests to update UI immediately
      await refreshTransferRequests();
    } catch (e) {
      print('Error accepting store transfer request: $e');
      errorSnackbar('Error accepting store transfer request: $e');
      rethrow;
    }
  }
} 