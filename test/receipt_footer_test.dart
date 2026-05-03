import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/receipt_footer.dart';

void main() {
  group('paymentDetailShowsOnInvoice', () {
    test('matches UI default when key is missing or null', () {
      expect(paymentDetailShowsOnInvoice({}), isTrue);
      expect(paymentDetailShowsOnInvoice({'showOnInvoice': null}), isTrue);
    });
    test('respects explicit false', () {
      expect(paymentDetailShowsOnInvoice({'showOnInvoice': false}), isFalse);
      expect(paymentDetailShowsOnInvoice({'showOnInvoice': 'false'}), isFalse);
      expect(paymentDetailShowsOnInvoice({'showOnInvoice': '0'}), isFalse);
    });
    test('accepts common true representations', () {
      expect(paymentDetailShowsOnInvoice({'showOnInvoice': true}), isTrue);
      expect(paymentDetailShowsOnInvoice({'showOnInvoice': 'true'}), isTrue);
    });
  });

  group('receiptPaymentAccountLine', () {
    test('reads primary keys', () {
      expect(
        receiptPaymentAccountLine({'accountName': '  ACME LTD  '}),
        'ACME LTD',
      );
    });
    test('falls back to normalized key spelling', () {
      expect(
        receiptPaymentAccountLine({'Account_Name': 'Jane Doe'}),
        'Jane Doe',
      );
      expect(
        receiptPaymentAccountLine({'account name': 'Biz Co'}),
        'Biz Co',
      );
      expect(
        receiptPaymentAccountLine({'accountsName': 'Plural Key Ltd'}),
        'Plural Key Ltd',
      );
    });
    test('uses business fallback when row has no name', () {
      expect(
        receiptPaymentAccountLine(
          {'provider': 'CRDB', 'number': '123'},
          businessForFallback: {
            'paymentAccountName': 'My Company Ltd',
          },
        ),
        'My Company Ltd',
      );
    });
  });

  group('paymentDetailMapFromFirestore', () {
    test('lifts name from nested account map', () {
      final m = paymentDetailMapFromFirestore({
        'type': 'bank',
        'provider': 'NMB',
        'number': '001',
        'account': {'name': 'Nested Holdings'},
      });
      expect(m['accountName'], 'Nested Holdings');
    });
  });
}
