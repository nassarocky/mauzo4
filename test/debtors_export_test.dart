import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/debtors_export.dart';

void main() {
  group('buildDebtorExportRows', () {
    test('keeps only positive debts and sorts highest first', () {
      final rows = buildDebtorExportRows(
        names: ['Ada', 'Ben', 'Cara'],
        phones: ['1', '2', '3'],
        amounts: [100, 0, 250],
      );
      expect(rows.length, 2);
      expect(rows[0].name, 'Cara');
      expect(rows[0].amount, 250);
      expect(rows[1].name, 'Ada');
      expect(rows[1].amount, 100);
    });

    test('sumDebtorAmounts totals remaining debt', () {
      final rows = buildDebtorExportRows(
        names: ['A', 'B'],
        phones: ['', ''],
        amounts: [40.5, 9.5],
      );
      expect(sumDebtorAmounts(rows), 50);
    });
  });
}
