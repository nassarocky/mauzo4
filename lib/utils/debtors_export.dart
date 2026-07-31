/// One customer row for debtors Excel/PDF export.
class DebtorExportRow {
  const DebtorExportRow({
    required this.name,
    required this.phone,
    required this.amount,
  });

  final String name;
  final String phone;
  final double amount;
}

/// Builds sorted debtor rows (amount > 0, highest debt first).
List<DebtorExportRow> buildDebtorExportRows({
  required Iterable<String> names,
  required Iterable<String> phones,
  required Iterable<double> amounts,
}) {
  final nameList = names.toList();
  final phoneList = phones.toList();
  final amountList = amounts.toList();
  final n = nameList.length;
  if (phoneList.length != n || amountList.length != n) {
    throw ArgumentError('names, phones, and amounts must have the same length');
  }

  final rows = <DebtorExportRow>[];
  for (var i = 0; i < n; i++) {
    final amount = amountList[i];
    if (amount <= 0.0001) continue;
    final name = nameList[i].trim();
    rows.add(DebtorExportRow(
      name: name.isEmpty ? '—' : name,
      phone: phoneList[i].trim(),
      amount: amount,
    ));
  }
  rows.sort((a, b) => b.amount.compareTo(a.amount));
  return rows;
}

double sumDebtorAmounts(Iterable<DebtorExportRow> rows) {
  double total = 0;
  for (final row in rows) {
    total += row.amount;
  }
  return total;
}
