/// Remaining balance after a payment, using the client's total debt
/// across all credit items (not the leftover on the item just paid).
double clientTotalRemainingAfterPayment({
  required double clientTotalDebt,
  required double paymentAmount,
}) {
  final remaining = clientTotalDebt - paymentAmount;
  if (remaining.isNaN || remaining.isNegative) return 0;
  return remaining;
}
