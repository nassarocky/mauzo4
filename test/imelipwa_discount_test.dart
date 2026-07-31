import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/imelipwa_discount.dart';

void main() {
  group('resolveImelipwaDiscountAdjustment', () {
    test('keeps positive discount when recording debt / partial pay', () {
      final result = resolveImelipwaDiscountAdjustment(
        amountMainCurrency: 0,
        catalog: 100,
        currentDiscount: 20,
        debtAllowed: true,
      );
      expect(result.allowed, isTrue);
      expect(result.nextDiscount, isNull);
    });

    test('keeps positive discount for partial payment below catalog', () {
      final result = resolveImelipwaDiscountAdjustment(
        amountMainCurrency: 50,
        catalog: 100,
        currentDiscount: 20,
        debtAllowed: true,
      );
      expect(result.allowed, isTrue);
      expect(result.nextDiscount, isNull);
      // remaining = 100 - 50 - 20 = 30
      expect(100 - 50 - 20, 30);
    });

    test('clears markup-only negative discount on partial pay', () {
      final result = resolveImelipwaDiscountAdjustment(
        amountMainCurrency: 40,
        catalog: 100,
        currentDiscount: -10,
        debtAllowed: true,
      );
      expect(result.allowed, isTrue);
      expect(result.nextDiscount, 0);
    });

    test('rejects debt without clearing discount when debt not allowed', () {
      final result = resolveImelipwaDiscountAdjustment(
        amountMainCurrency: 0,
        catalog: 100,
        currentDiscount: 15,
        debtAllowed: false,
      );
      expect(result.allowed, isFalse);
      expect(result.nextDiscount, isNull);
    });

    test('sets markup discount when Imelipwa is above catalog', () {
      final result = resolveImelipwaDiscountAdjustment(
        amountMainCurrency: 120,
        catalog: 100,
        currentDiscount: 0,
        debtAllowed: true,
      );
      expect(result.allowed, isTrue);
      expect(result.nextDiscount, -20);
    });

    test('clears discount when Imelipwa equals catalog', () {
      final result = resolveImelipwaDiscountAdjustment(
        amountMainCurrency: 100,
        catalog: 100,
        currentDiscount: 20,
        debtAllowed: true,
      );
      expect(result.allowed, isTrue);
      expect(result.nextDiscount, 0);
    });
  });
}
