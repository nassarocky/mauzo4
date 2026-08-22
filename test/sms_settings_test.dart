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
}
