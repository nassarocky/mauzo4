import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mauzo/models/product_model.dart';
import 'package:mauzo/models/stock_transaction.dart';

class InventoryMovementService {
  InventoryMovementService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _safeId(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  static DocumentReference<Map<String, dynamic>> transactionRef({
    required String businessId,
    required String operationId,
    required String productId,
    String suffix = 'shop',
  }) {
    final id =
        '${_safeId(operationId)}_${_safeId(productId)}_${_safeId(suffix)}';
    return _firestore
        .collection('transactions')
        .doc(businessId)
        .collection('usersTransactions')
        .doc(id);
  }

  static Map<String, dynamic> historyData({
    required String transactionId,
    required Product product,
    required double delta,
    required double previousQuantity,
    required String origin,
    required String businessId,
    required String operationId,
    required String referenceId,
    required String referenceType,
    required String employeeName,
    String inventoryLocation = 'shop',
    String? notes,
    Timestamp? occurredAt,
    bool quantityEstimated = false,
  }) {
    final timestamp = Timestamp.now();
    final newQuantity = previousQuantity + delta;
    final transaction = StockTransaction(
      transactionId: transactionId,
      productId: product.id,
      quantity: delta.abs(),
      delta: delta,
      previousQuantity: previousQuantity,
      newQuantity: newQuantity,
      transactionType: delta < 0 ? 'removal' : 'addition',
      transactionOrigin: origin,
      timestamp: timestamp,
      userId: businessId,
      price: product.price,
      referenceId: referenceId,
      referenceType: referenceType,
      employeeName: employeeName,
      notes: notes,
      totalValue: delta.abs() * product.price,
      operationId: operationId,
      inventoryLocation: inventoryLocation,
      occurredAt: occurredAt,
      quantityEstimated: quantityEstimated,
    ).toMap();
    transaction['serverTimestamp'] = FieldValue.serverTimestamp();
    return transaction;
  }

  /// Adds an offline-safe stock delta and its audit row to one write batch.
  ///
  /// [previousQuantity] is an offline estimate only. The signed [delta] is the
  /// authoritative movement and composes safely with movements from other
  /// devices through [FieldValue.increment].
  static void addIncrementToBatch({
    required WriteBatch batch,
    required String businessId,
    required Product product,
    required double delta,
    required String origin,
    required String operationId,
    required String referenceId,
    required String referenceType,
    required String employeeName,
    String inventoryLocation = 'shop',
    String? notes,
  }) {
    if (delta == 0 || product.itemType == 'service') return;

    final productRef = _firestore
        .collection('products')
        .doc(businessId)
        .collection('userProducts')
        .doc(product.id);
    final historyRef = transactionRef(
      businessId: businessId,
      operationId: operationId,
      productId: product.id,
      suffix: inventoryLocation,
    );

    batch.update(productRef, {'quantity': FieldValue.increment(delta)});
    batch.set(
      historyRef,
      historyData(
        transactionId: historyRef.id,
        product: product,
        delta: delta,
        previousQuantity: product.quantity,
        origin: origin,
        businessId: businessId,
        operationId: operationId,
        referenceId: referenceId,
        referenceType: referenceType,
        employeeName: employeeName,
        inventoryLocation: inventoryLocation,
        notes: notes,
        quantityEstimated: true,
      ),
    );
  }
}
