/// Base (inventory) units for a sale/invoice line. New lines set [baseQuantity];
/// legacy lines only have [quantity] in base units.
double saleLineBaseQuantity(Map<String, dynamic> product) {
  final b = product['baseQuantity'];
  if (b != null) return (b as num).toDouble();
  final q = product['quantity'];
  if (q is num) return q.toDouble();
  return double.tryParse(q?.toString() ?? '0') ?? 0.0;
}

/// Quantity in the unit the line was sold in (for receipts / display).
double saleLineDisplayQuantity(Map<String, dynamic> product) {
  final q = product['quantity'];
  if (q is num) return q.toDouble();
  return double.tryParse(q?.toString() ?? '0') ?? 0.0;
}

String? saleLineUomLabel(Map<String, dynamic> product) {
  final s = product['saleUomLabel']?.toString();
  if (s != null && s.isNotEmpty) return s;
  return null;
}

/// Quantity text for UI lists, e.g. `2` or `2 Dozen` when [saleUomLabel] is set.
String saleLineQuantityWithUomLabel(Map<String, dynamic> product) {
  final dq = saleLineDisplayQuantity(product);
  final qtyStr = dq == dq.roundToDouble()
      ? dq.toStringAsFixed(0)
      : dq.toStringAsFixed(2);
  final uom = saleLineUomLabel(product);
  if (uom != null && uom.trim().isNotEmpty) {
    return '$qtyStr $uom';
  }
  return qtyStr;
}
