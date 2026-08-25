import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/models/stock_transaction.dart';

void main() {
  test('new stock transaction persists signed movement metadata', () {
    final transaction = StockTransaction(
      transactionId: 'sale_1_product_1_shop',
      productId: 'product_1',
      quantity: 5,
      delta: -5,
      previousQuantity: 20,
      newQuantity: 15,
      transactionType: 'removal',
      transactionOrigin: 'Sale',
      timestamp: Timestamp.fromMillisecondsSinceEpoch(1000),
      userId: 'business_1',
      price: 100,
      referenceId: 'sale_1',
      referenceType: 'sale',
      operationId: 'sale_1',
      inventoryLocation: 'shop',
      quantityEstimated: true,
    );

    final map = transaction.toMap();

    expect(map['quantity'], 5);
    expect(map['delta'], -5);
    expect(map['previousQuantity'], 20);
    expect(map['newQuantity'], 15);
    expect(map['operationId'], 'sale_1');
    expect(map['inventoryLocation'], 'shop');
    expect(map['quantityEstimated'], isTrue);
  });
}
