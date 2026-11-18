/// Whether a cart discount may be applied.
///
/// Allowed when either:
/// - the discount only brings the total down to the original (retail) total
///   (lines were priced above retail), or
/// - it stays under the business "Allowed Discount Percent" of the part of the
///   cart that can be discounted ([discountableSubtotal]). Products marked
///   "no discount" are left out of that part.
bool isCartDiscountAllowed({
  required double productsPrice,
  required double productsOriginalPrice,
  required double discountableSubtotal,
  required double discount,
  required int discountPercent,
}) {
  if ((productsPrice - discount) >= productsOriginalPrice) return true;
  final double maxDiscount = (discountableSubtotal * discountPercent) / 100;
  return discount < maxDiscount;
}
