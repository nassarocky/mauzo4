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
      expect(msg, contains('you owe TZS 99.50'));
    });

    test('custom template replaces placeholders', () {
      final msg = buildDebtReminderMessage(
        clientName: 'Asha',
        amount: 12000,
        currency: 'TZS',
        businessName: 'Duka',
        dueDateLabel: '28/08/2026',
        template: '{name} deni {amount} {currency} {business} {due}',
      );
      expect(msg, 'Asha deni TZS 12000 Duka 28/08/2026');
    });
  });

  group('SmsPack', () {
    test('defaults start at 100 SMS with TZS 30 then 25 from 1000', () {
      expect(SmsPack.defaults.first.credits, 100);
      expect(SmsPack.priceForCredits(100), 3000);
      expect(SmsPack.priceForCredits(1000), 25000);
      final hundred = SmsPack.defaults.firstWhere((p) => p.id == 'sms_100');
      expect(hundred.credits, 100);
      expect(hundred.price, 3000);
      final thousand = SmsPack.defaults.firstWhere((p) => p.id == 'sms_1000');
      expect(thousand.price, 25000);
    });
  });
}
