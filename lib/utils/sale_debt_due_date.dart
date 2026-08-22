class SaleDebtDueDate {
  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime defaultDueDate({
    required DateTime saleDate,
    required int defaultCreditDays,
  }) {
    final days = defaultCreditDays.clamp(0, 365);
    return startOfDay(saleDate).add(Duration(days: days));
  }

  static int creditDaysFrom({
    required DateTime saleDate,
    required DateTime dueDate,
  }) {
    final days = startOfDay(dueDate).difference(startOfDay(saleDate)).inDays;
    if (days < 0) return 0;
    if (days > 365) return 365;
    return days;
  }

  static DateTime lastSelectableDueDate(DateTime saleDate) =>
      startOfDay(saleDate).add(const Duration(days: 365));
}
