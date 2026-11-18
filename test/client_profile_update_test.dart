import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/client_profile_update.dart';

void main() {
  group('buildClientProfileUpdate', () {
    test('writes name, phone, note and image without touching debt', () {
      final data = buildClientProfileUpdate(
        clientId: 'client-1',
        name: '  Asha  ',
        phone: ' 0765908208 ',
        note: ' regular ',
        image: 'https://example.com/a.png',
      );

      expect(data['id'], 'client-1');
      expect(data['name'], 'Asha');
      expect(data['phone'], '0765908208');
      expect(data['note'], 'regular');
      expect(data['image'], 'https://example.com/a.png');
      expect(data.containsKey('debt'), isFalse);
      expect(data.containsKey('advance'), isFalse);
      expect(data.containsKey('date'), isFalse);
      expect(data.containsKey('owner'), isFalse);
    });

    test('allows clearing phone and note on a client saved before a loan', () {
      final data = buildClientProfileUpdate(
        clientId: 'client-2',
        name: 'Juma',
        phone: '',
        note: null,
        image: '',
      );

      expect(data['name'], 'Juma');
      expect(data['phone'], '');
      expect(data['note'], '');
      expect(data['image'], '');
    });

    test('rejects a missing client id or name', () {
      expect(
        () => buildClientProfileUpdate(
          clientId: '  ',
          name: 'Asha',
          phone: '0765908208',
        ),
        throwsArgumentError,
      );
      expect(
        () => buildClientProfileUpdate(
          clientId: 'client-1',
          name: '   ',
          phone: '0765908208',
        ),
        throwsArgumentError,
      );
    });
  });
}
