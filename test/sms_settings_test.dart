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
