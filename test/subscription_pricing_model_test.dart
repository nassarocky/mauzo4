import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/models/subscription_pricing_model.dart';

void main() {
  final model = SubscriptionPricingModel.getDefault();

  test('1 to 5 shops use their tier, 0 counts as one', () {
    expect(model.getPricesForBusinessCount(0)['month'], 15000);
    expect(model.getPricesForBusinessCount(1)['month'], 15000);
    expect(model.getPricesForBusinessCount(4)['sixMonths'], 300000);
    expect(model.getPricesForBusinessCount(5)['month'], 75000);
  });

  test('price keeps growing after five shops', () {
    expect(model.getPricesForBusinessCount(6)['month'], 90000);
    expect(model.getPricesForBusinessCount(8)['month'], 120000);
    expect(
      model.getPricesForBusinessCount(10)['year']!,
      greaterThan(model.getPricesForBusinessCount(6)['year']!),
    );
  });

  test('extraShop override is used when configured', () {
    final custom = SubscriptionPricingModel(
      tier1: model.tier1,
      tier2: model.tier2,
      tier3: model.tier3,
      tier4: model.tier4,
      tier5Plus: model.tier5Plus,
      extraShop: const {'month': 10000},
      durationSeconds: model.durationSeconds,
    );
    expect(custom.getPricesForBusinessCount(7)['month'], 75000 + 2 * 10000);
    expect(custom.getPricesForBusinessCount(7)['week'], 25000 + 2 * 5000);
  });
}
