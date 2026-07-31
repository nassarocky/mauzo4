/// Result of resolving how Imelipwa (paid / selling total) should adjust discount.
class ImelipwaDiscountAdjustment {
  const ImelipwaDiscountAdjustment({
    required this.allowed,
    this.nextDiscount,
  });

  final bool allowed;

  /// When non-null, replace the current discount. When null, leave discount unchanged.
  final double? nextDiscount;
}

/// Pure rules for Imelipwa edits vs catalog price and existing discount.
///
/// - amount ≥ catalog → discount becomes `catalog - amount` (0 or markup)
/// - amount < catalog + debt allowed → keep positive discount; clear markup (negative)
/// - amount < catalog + debt not allowed → reject, leave discount unchanged
ImelipwaDiscountAdjustment resolveImelipwaDiscountAdjustment({
  required double amountMainCurrency,
  required double catalog,
  required double currentDiscount,
  required bool debtAllowed,
}) {
  if (!amountMainCurrency.isFinite || amountMainCurrency < 0) {
    return const ImelipwaDiscountAdjustment(allowed: true);
  }
  if (amountMainCurrency + 1e-9 >= catalog) {
    return ImelipwaDiscountAdjustment(
      allowed: true,
      nextDiscount: catalog - amountMainCurrency,
    );
  }
  if (!debtAllowed) {
    return const ImelipwaDiscountAdjustment(allowed: false);
  }
  if (currentDiscount < 0) {
    return const ImelipwaDiscountAdjustment(allowed: true, nextDiscount: 0);
  }
  return const ImelipwaDiscountAdjustment(allowed: true);
}
