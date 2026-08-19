import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/models/sms_pack_model.dart';
import 'package:mauzo/utils/debt_reminder_message.dart';
import 'package:mauzo/utils/sms_phone.dart';

void main() {
  group('normalizeSmsPhone', () {
    test('converts test number 0765908208 to Tanzania E.164 digits', () {
      expect(normalizeSmsPhone('0765908208'), '255765908208');
      expect(normalizeSmsPhone('+255 765 908 208'), '255765908208');
      expect(isValidSmsPhone('0765908208'), isTrue);
      expect(isValidSmsPhone(''), isFalse);
    });
  });

  group('buildDebtReminderMessage', () {
    test('Swahili reminder includes client debt and shop', () {
      final msg = buildDebtReminderMessage(
        clientName: 'Asha',
        amount: 15000,
        currency: 'TZS',
        businessName: 'Duka la Mauzo',
      );
      expect(msg, contains('Asha'));
      expect(msg, contains('15000'));
      expect(msg, contains('Duka la Mauzo'));
      expect(msg, contains('deni'));
      expect(countSmsSegments(msg), 1);
    });

    test('English reminder uses owe wording', () {
      final msg = buildDebtReminderMessage(
        clientName: 'John',
        amount: 99.5,
        currency: 'TZS',
        businessName: 'Shop',
        lang: 'en',
      );
      expect(msg, contains('you owe 99.50 TZS'));
    });
  });

  group('SmsPack', () {
    test('defaults include billed packs paid to Hesabu Mauzo', () {
      expect(SmsPack.defaults.length, 4);
      expect(SmsPack.defaults.first.price, greaterThan(0));
      final hundred = SmsPack.defaults.firstWhere((p) => p.id == 'sms_100');
      expect(hundred.credits, 100);
      expect(hundred.price, 5000);
    });
  });
}
