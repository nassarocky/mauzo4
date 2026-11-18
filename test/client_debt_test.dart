import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/client_debt.dart';

void main() {
  group('clientTotalRemainingAfterPayment', () {
    test('uses total client debt across items, not the paid item only', () {
      // Two credit sales: 5000 + 8000. Partial pay 2000 on the first item.
      expect(
        clientTotalRemainingAfterPayment(
          clientTotalDebt: 13000,
          paymentAmount: 2000,
        ),
        11000,
      );
    });

    test('is zero when the payment clears every item', () {
      expect(
        clientTotalRemainingAfterPayment(
          clientTotalDebt: 3000,
          paymentAmount: 3000,
        ),
        0,
      );
    });

    test('does not go negative', () {
      expect(
        clientTotalRemainingAfterPayment(
          clientTotalDebt: 1000,
          paymentAmount: 1500,
        ),
        0,
      );
    });
  });
}
