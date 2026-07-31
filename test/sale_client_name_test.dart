import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/sale_client_name.dart';

void main() {
  group('saleClientDisplayName', () {
    test('uses registered client name when present', () {
      expect(
        saleClientDisplayName(
          lookedUpClientName: 'Registered',
          saleClientName: 'Typed',
        ),
        'Registered',
      );
    });

    test('falls back to free-text sale clientname', () {
      expect(
        saleClientDisplayName(
          lookedUpClientName: '',
          saleClientName: 'Walk-in John',
        ),
        'Walk-in John',
      );
    });

    test('returns empty when both blank', () {
      expect(
        saleClientDisplayName(
          lookedUpClientName: '  ',
          saleClientName: '',
        ),
        '',
      );
    });
  });
}
