import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../models/inventory_loss_model.dart';
import '../models/product_model.dart';
import '../models/stock_transaction.dart';
import 'business_controller.dart';
import 'profile_controller.dart';
import '../constants/transaction_constants.dart';
import '../utils/constants.dart';
import '../utils/operation_error_message.dart';

class InventoryLossController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  final losses = <InventoryLoss>[].obs;
  StreamSubscription<List<InventoryLoss>>? _lossSubscription;
  final isLoading = false.obs;
  final showAllTime = false.obs; // Toggle between current period and all time
  bool _isStreamActive = false; // Track if stream is currently active

  @override
  void onInit() {
    super.onInit();
    // Don't load data on init - wait for screen to be opened
    print('✅ InventoryLossController initialized (lazy loading mode)');
  }

  @override
  void onClose() {
    stopListening();
    super.onClose();
  }

  // Start listening to losses - called when screen opens
  void startListening() {
    if (_isStreamActive) {
      print('⚠️ Loss stream already active, skipping');
      return;
    }
    print('🔊 Starting inventory loss stream');
    _isStreamActive = true;
    _bindLossStream();
  }

  // Stop listening - called when screen closes
  void stopListening() {
    if (_lossSubscription != null) {
      print('🔇 Stopping inventory loss stream');
      _lossSubscription?.cancel();
      _lossSubscription = null;
      _isStreamActive = false;
    }
  }

  // Toggle between current period and all time
  void toggleTimeFilter() {
    showAllTime.value = !showAllTime.value;
    if (_isStreamActive) {
      _bindLossStream(); // Rebind only if stream is active
    }
  }

  // Bind to Firestore stream with optional reset_time filter
  void _bindLossStream() {
    final String? businessId = _businessController.business['id'];
    if (businessId == null || businessId.isEmpty) {
      print('❌ Business ID is null, cannot bind loss stream');
      return;
    }

    // Cancel existing subscription
    _lossSubscription?.cancel();

    print('🔍 Binding inventory loss stream for business: $businessId');
    print('📅 Show all time: ${showAllTime.value}');

    Query query = _firestore
        .collection('inventoryLosses')
        .doc(businessId)
        .collection('userLosses')
        .orderBy('dateRecorded', descending: true);

    // Apply reset_time filter if not showing all time
    if (!showAllTime.value) {
      final resetTime = _businessController.business['reset_time'];
      if (resetTime != null) {
        print('📅 Filtering from reset_time: $resetTime');
        query = query.where('dateRecorded', isGreaterThanOrEqualTo: resetTime);
      }
    }

    _lossSubscription = query
        .snapshots()
        .map((snapshot) {
          print('✅ Received ${snapshot.docs.length} loss records');
          return snapshot.docs
              .map((doc) => InventoryLoss.fromSnapshot(doc))
              .toList();
        })
        .listen((lossData) {
          losses.value = lossData;
        });
  }

  // Record a new inventory loss
  Future<bool> recordLoss({
    required Product product,
    required double quantity,
    required String lossType,
    required String reason,
    required DateTime dateOccurred,
    String? imageUrl,
  }) async {
    try {
      isLoading.value = true;
      final String? businessId = _businessController.business['id'];
      final String? userId = _profileController.user['id'];
      final String? userName = _profileController.user['name'];

      if (businessId == null || userId == null) {
        errorSnackbar('Business or user information missing');
        return false;
      }

      // Validate quantity
      if (quantity <= 0) {
        errorSnackbar('Quantity must be greater than 0');
        return false;
      }

      final lossRef = _firestore
          .collection('inventoryLosses')
          .doc(businessId)
          .collection('userLosses')
          .doc();
      final transactionRef = _firestore
          .collection('transactions')
          .doc(businessId)
          .collection('usersTransactions')
          .doc();
      final productRef = _firestore
          .collection('products')
          .doc(businessId)
          .collection('userProducts')
          .doc(product.id);
      final createdAt = DateTime.now();
      final createdTimestamp = Timestamp.fromDate(createdAt);
      final occurredTimestamp = Timestamp.fromDate(dateOccurred);

      await _firestore.runTransaction((fireTx) async {
        final productSnapshot = await fireTx.get(productRef);
        if (!productSnapshot.exists) {
          throw Exception('Product no longer exists');
        }
        final productData = productSnapshot.data()!;
        final rawQuantity = productData['quantity'];
        final currentQuantity = rawQuantity is num
            ? rawQuantity.toDouble()
            : 0.0;
        if (quantity > currentQuantity) {
          throw Exception(
            'Loss quantity cannot exceed available stock ($currentQuantity)',
          );
        }
        final rawBuyingPrice =
            productData['buyingPrice'] ?? product.buyingPrice;
        final buyingPrice = rawBuyingPrice is num
            ? rawBuyingPrice.toDouble()
            : 0.0;
        final newQuantity = currentQuantity - quantity;
        final totalValue = quantity * buyingPrice;
        final loss = InventoryLoss(
          id: lossRef.id,
          businessId: businessId,
          productId: product.id,
          productName: (productData['name'] ?? product.name).toString(),
          productCode: (productData['code'] ?? product.code).toString(),
          quantity: quantity,
          unitPrice: buyingPrice,
          totalValue: totalValue,
          lossType: lossType,
          reason: reason,
          imageUrl: imageUrl,
          dateOccurred: dateOccurred,
          dateRecorded: createdAt,
          recordedBy: userId,
          recordedByName: userName ?? 'Unknown',
          transactionId: transactionRef.id,
        );
        final history =
            StockTransaction(
              transactionId: transactionRef.id,
              productId: product.id,
              quantity: quantity,
              previousQuantity: currentQuantity,
              newQuantity: newQuantity,
              transactionType: TransactionTypes.removal,
              transactionOrigin: _getTransactionOrigin(lossType),
              timestamp: createdTimestamp,
              userId: userId,
              price: buyingPrice,
              employeeName: userName ?? 'Unknown',
              notes: reason,
              referenceId: lossRef.id,
              referenceType: 'inventory_loss',
              totalValue: totalValue,
            ).toMap()..addAll({
              'delta': -quantity,
              'referenceId': lossRef.id,
              'referenceType': 'inventory_loss',
              'inventoryLocation': 'shop',
              'occurredAt': occurredTimestamp,
              'operationId': lossRef.id,
              'serverTimestamp': FieldValue.serverTimestamp(),
            });

        fireTx.update(productRef, {
          'quantity': newQuantity,
          'total': newQuantity,
        });
        fireTx.set(lossRef, loss.toFirestore());
        fireTx.set(transactionRef, history);
      });

      successSnackbar('Loss recorded successfully');
      return true;
    } catch (e) {
      print('❌ Error recording loss: $e');
      errorSnackbar(operationErrorMessage(e));
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  // Get transaction origin based on loss type
  String _getTransactionOrigin(String lossType) {
    switch (lossType) {
      case 'damaged':
        return TransactionOrigins.damaged;
      case 'expired':
        return TransactionOrigins.expired;
      case 'stolen':
        return TransactionOrigins.stolen;
      case 'spoiled':
        return TransactionOrigins.spoiled;
      default:
        return TransactionOrigins.other;
    }
  }

  // Delete a loss record (admin only)
  Future<bool> deleteLoss(String lossId) async {
    try {
      final String? businessId = _businessController.business['id'];
      if (businessId == null) {
        errorSnackbar('Business information missing');
        return false;
      }

      await _firestore
          .collection('inventoryLosses')
          .doc(businessId)
          .collection('userLosses')
          .doc(lossId)
          .delete();

      successSnackbar('Loss record deleted');
      return true;
    } catch (e) {
      print('❌ Error deleting loss: $e');
      errorSnackbar('Failed to delete loss');
      return false;
    }
  }

  // Get losses filtered by type
  List<InventoryLoss> getLossesByType(String lossType) {
    return losses.where((loss) => loss.lossType == lossType).toList();
  }

  // Get losses for a specific product
  List<InventoryLoss> getLossesByProduct(String productId) {
    return losses.where((loss) => loss.productId == productId).toList();
  }

  // Get losses within date range
  List<InventoryLoss> getLossesByDateRange(DateTime start, DateTime end) {
    return losses.where((loss) {
      return loss.dateOccurred.isAfter(start) &&
          loss.dateOccurred.isBefore(end.add(Duration(days: 1)));
    }).toList();
  }

  // Calculate total loss value
  double getTotalLossValue() {
    return losses.fold(0.0, (sum, loss) => sum + loss.totalValue);
  }

  // Calculate total loss value by type
  double getLossValueByType(String lossType) {
    return losses
        .where((loss) => loss.lossType == lossType)
        .fold(0.0, (sum, loss) => sum + loss.totalValue);
  }

  // Calculate total loss value within date range
  double getLossValueByDateRange(DateTime start, DateTime end) {
    return getLossesByDateRange(
      start,
      end,
    ).fold(0.0, (sum, loss) => sum + loss.totalValue);
  }

  // Get loss statistics
  Map<String, dynamic> getLossStatistics() {
    final totalLosses = losses.length;
    final totalValue = getTotalLossValue();

    final Map<String, int> countByType = {};
    final Map<String, double> valueByType = {};

    for (var loss in losses) {
      countByType[loss.lossType] = (countByType[loss.lossType] ?? 0) + 1;
      valueByType[loss.lossType] =
          (valueByType[loss.lossType] ?? 0) + loss.totalValue;
    }

    return {
      'totalLosses': totalLosses,
      'totalValue': totalValue,
      'countByType': countByType,
      'valueByType': valueByType,
    };
  }
}
