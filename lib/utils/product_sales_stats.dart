import '../models/sale_model.dart';
import 'report_date_range.dart';
import 'sale_line_quantity.dart';

/// One product's totals for the selected period.
class ProductSalesRow {
  ProductSalesRow({
    required this.id,
    required this.name,
    this.quantity = 0,
    this.revenue = 0,
    this.salesCount = 0,
  });

  final String id;
  final String name;

  /// Units sold, in the product's base (inventory) unit.
  double quantity;

  /// Sum of line price x quantity as sold.
  double revenue;

  /// Number of sales that included this product.
  int salesCount;
}

double _asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}

/// Most-sold products between [start] and [end] (both days inclusive).
///
/// When [productIds] is non-empty, only those products are counted.
/// Sorted by quantity sold, then revenue, both highest first.
List<ProductSalesRow> computeProductSalesStats(
  List<Sale> sales, {
  required DateTime start,
  required DateTime end,
  Set<String>? productIds,
  DateTime? now,
}) {
  final from = ReportDateRange.periodStart(start);
  final to = ReportDateRange.periodEnd(end, now: now);
  final filter = (productIds == null || productIds.isEmpty) ? null : productIds;
  final rows = <String, ProductSalesRow>{};

  for (final sale in sales) {
    if (sale.saleType == 'debt_repayment') continue;
    final saleDate = sale.date.toDate();
    if (saleDate.isBefore(from) || saleDate.isAfter(to)) continue;

    // Services on an unpaid sale are not counted until paid (same as Statistics).
    final bool debtBlocksServices = sale.debt.abs() > 0.01;
    final countedInThisSale = <String>{};

    for (final raw in sale.products) {
      if (raw is! Map) continue;
      final line = Map<String, dynamic>.from(raw);
      final String id = (line['id'] ?? '').toString();
      if (id.isEmpty) continue;
      if (filter != null && !filter.contains(id)) continue;
      final String itemType = (line['itemType'] ?? 'product').toString();
      if (itemType == 'service' && debtBlocksServices) continue;

      final row = rows.putIfAbsent(
        id,
        () => ProductSalesRow(
          id: id,
          name: (line['name'] ?? '').toString(),
        ),
      );
      row.quantity += saleLineBaseQuantity(line);
      row.revenue += _asDouble(line['price']) * saleLineDisplayQuantity(line);
      if (countedInThisSale.add(id)) row.salesCount += 1;
    }
  }

  final list = rows.values.toList();
  list.sort((a, b) {
    final byQty = b.quantity.compareTo(a.quantity);
    if (byQty != 0) return byQty;
    return b.revenue.compareTo(a.revenue);
  });
  return list;
}
