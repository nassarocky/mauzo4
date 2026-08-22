import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/sale_debt_due_date.dart';

void main() {
  group('SaleDebtDueDate', () {
    test('defaults due date from sale day plus credit days', () {
      final due = SaleDebtDueDate.defaultDueDate(
        saleDate: DateTime(2026, 8, 21, 15, 40),
        defaultCreditDays: 7,
      );
      expect(due, DateTime(2026, 8, 28));
    });

    test('same-day due date is 0 credit days', () {
      expect(
        SaleDebtDueDate.creditDaysFrom(
          saleDate: DateTime(2026, 8, 21, 9),
          dueDate: DateTime(2026, 8, 21, 18),
        ),
        0,
      );
    });

    test('picked due date is stored as days after the sale', () {
      expect(
        SaleDebtDueDate.creditDaysFrom(
          saleDate: DateTime(2026, 8, 21),
          dueDate: DateTime(2026, 9, 4),
        ),
        14,
      );
    });

    test('clamps negative and over-year credit days', () {
      expect(
        SaleDebtDueDate.creditDaysFrom(
          saleDate: DateTime(2026, 8, 21),
          dueDate: DateTime(2026, 8, 20),
        ),
        0,
      );
      expect(
        SaleDebtDueDate.creditDaysFrom(
          saleDate: DateTime(2026, 8, 21),
          dueDate: DateTime(2028, 8, 21),
        ),
        365,
      );
    });
  });
}
