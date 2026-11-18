import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/sms_settings.dart';

void main() {
  test('lowStockAlertEnabled survives copyWith and fromMap', () {
    final on = const SmsSettings().copyWith(lowStockAlertEnabled: true);
    expect(on.lowStockAlertEnabled, isTrue);

    final off = on.copyWith(lowStockAlertEnabled: false);
    expect(off.lowStockAlertEnabled, isFalse);

    final roundTrip = SmsSettings.fromMap(on.toMap());
    expect(roundTrip.lowStockAlertEnabled, isTrue);
  });

  test('daily digest time defaults to 20:00 and survives copyWith', () {
    const defaults = SmsSettings();
    expect(defaults.dailyDigestHour, 20);
    expect(defaults.dailyDigestMinute, 0);
    expect(defaults.dailyDigestTimeLabel, '20:00');

    final morning = defaults.copyWith(
      dailyDigestEnabled: true,
      dailyDigestHour: 8,
      dailyDigestMinute: 30,
    );
    expect(morning.dailyDigestTimeLabel, '08:30');

    final roundTrip = SmsSettings.fromMap(morning.toMap());
    expect(roundTrip.dailyDigestEnabled, isTrue);
    expect(roundTrip.dailyDigestHour, 8);
    expect(roundTrip.dailyDigestMinute, 30);
  });

  test('daily digest hour and minute are clamped', () {
    expect(SmsSettings.clampHour(25), 23);
    expect(SmsSettings.clampHour(-1), 0);
    expect(SmsSettings.clampHour(null), 20);
    expect(SmsSettings.clampMinute(99), 59);
    expect(SmsSettings.clampMinute(-4), 0);
    expect(SmsSettings.clampMinute(null), 0);

    final parsed = SmsSettings.fromMap({
      'dailyDigestHour': 26,
      'dailyDigestMinute': -3,
    });
    expect(parsed.dailyDigestHour, 23);
    expect(parsed.dailyDigestMinute, 0);
  });

  test('invoice SMS lines preserve every product and unit price', () {
    final lines = productLinesForSms([
      {'name': 'Sugar', 'quantity': 2, 'price': 1500},
      {'name': 'Rice', 'quantity': 1, 'price': 2200},
    ]);

    expect(lines, hasLength(2));
    expect(lines[0], {'name': 'Sugar', 'qty': 2.0, 'price': 1500.0});
    expect(lines[1], {'name': 'Rice', 'qty': 1.0, 'price': 2200.0});
  });
}
