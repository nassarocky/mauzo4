import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/discount_rules.dart';

void main() {
  test('discount under the allowed percent of discountable items is allowed', () {
    expect(
      isCartDiscountAllowed(
        productsPrice: 1000,
        productsOriginalPrice: 1000,
        discountableSubtotal: 1000,
        discount: 50,
        discountPercent: 10,
      ),
      isTrue,
    );
  });

  test('discount over the allowed percent is blocked', () {
    expect(
      isCartDiscountAllowed(
        productsPrice: 1000,
        productsOriginalPrice: 1000,
        discountableSubtotal: 1000,
        discount: 200,
        discountPercent: 10,
      ),
      isFalse,
    );
  });

  test('items marked no-discount do not count towards the allowance', () {
    // 1000 cart, but only 200 of it can be discounted: 10% of 200 = 20.
    expect(
      isCartDiscountAllowed(
        productsPrice: 1000,
        productsOriginalPrice: 1000,
        discountableSubtotal: 200,
        discount: 50,
        discountPercent: 10,
      ),
      isFalse,
    );
    expect(
      isCartDiscountAllowed(
        productsPrice: 1000,
        productsOriginalPrice: 1000,
        discountableSubtotal: 200,
        discount: 15,
        discountPercent: 10,
      ),
      isTrue,
    );
  });

  test('cart of only no-discount items allows no discount', () {
    expect(
      isCartDiscountAllowed(
        productsPrice: 500,
        productsOriginalPrice: 500,
        discountableSubtotal: 0,
        discount: 1,
        discountPercent: 10,
      ),
      isFalse,
    );
  });

  test('allowed percent 0 still blocks everything, as before', () {
    expect(
      isCartDiscountAllowed(
        productsPrice: 1000,
        productsOriginalPrice: 1000,
        discountableSubtotal: 1000,
        discount: 1,
        discountPercent: 0,
      ),
      isFalse,
    );
  });

  test('lines priced above retail may be brought back down to retail', () {
    expect(
      isCartDiscountAllowed(
        productsPrice: 1200,
        productsOriginalPrice: 1000,
        discountableSubtotal: 0,
        discount: 200,
        discountPercent: 0,
      ),
      isTrue,
    );
  });
}
