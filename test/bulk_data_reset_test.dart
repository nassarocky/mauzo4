import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/bulk_data_reset.dart';

void main() {
  group('canPerformBulkDataReset', () {
    test('allows owner and manager only', () {
      expect(canPerformBulkDataReset('owner'), isTrue);
      expect(canPerformBulkDataReset('manager'), isTrue);
      expect(canPerformBulkDataReset('Owner'), isTrue);
      expect(canPerformBulkDataReset('cashier'), isFalse);
      expect(canPerformBulkDataReset('sales_person'), isFalse);
      expect(canPerformBulkDataReset('employee'), isFalse);
      expect(canPerformBulkDataReset('agent'), isFalse);
      expect(canPerformBulkDataReset(null), isFalse);
    });
  });

  group('bulkDataResetTargets', () {
    test('stock actions hit shop products and store stock', () {
      final targets = bulkDataResetTargets(
        action: BulkDataResetAction.zeroStocks,
        businessId: 'biz-1',
        ownerId: 'owner-1',
      );
      expect(targets.map((t) => t.path).toList(), [
        'products/biz-1/userProducts',
        'store/owner-1/userStore',
      ]);
      expect(
        bulkDataResetDeletesDocuments(BulkDataResetAction.zeroStocks),
        isFalse,
      );
      expect(
        bulkDataResetDeletesDocuments(BulkDataResetAction.deleteStocks),
        isTrue,
      );
    });

    test('sales and expenses use the business collections', () {
      expect(
        bulkDataResetTargets(
          action: BulkDataResetAction.deleteSales,
          businessId: 'biz-1',
          ownerId: 'owner-1',
        ).single.path,
        'sales/biz-1/userSales',
      );
      expect(
        bulkDataResetTargets(
          action: BulkDataResetAction.deleteExpenses,
          businessId: 'biz-1',
          ownerId: 'owner-1',
        ).single.path,
        'expenses/biz-1/userExpenses',
      );
    });
  });
}
