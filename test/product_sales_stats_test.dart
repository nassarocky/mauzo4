import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/models/sale_model.dart';
import 'package:mauzo/utils/product_sales_stats.dart';

Sale _sale(
  DateTime date,
  List<Map<String, dynamic>> products, {
  double debt = 0,
  String? saleType,
}) {
  return Sale(
    id: 's',
    client: '',
    clientname: '',
    employeeId: '',
    employeeName: '',
    owner: '',
    frominvoice: false,
    date: Timestamp.fromDate(date),
    products: products,
    price: 0,
    buyingPrice: 0,
    payment: 0,
    debt: debt,
    discount: 0,
    comment: '',
    saleType: saleType,
  );
}

void main() {
  final now = DateTime(2026, 11, 20, 12);

  test('ranks products by quantity and totals revenue', () {
    final sales = [
      _sale(DateTime(2026, 11, 2, 9), [
        {'id': 'a', 'name': 'Sugar', 'price': 100, 'quantity': 2},
        {'id': 'b', 'name': 'Rice', 'price': 50, 'quantity': 10},
      ]),
      _sale(DateTime(2026, 11, 3, 9), [
        {'id': 'a', 'name': 'Sugar', 'price': 100, 'quantity': 4},
      ]),
    ];
    final rows = computeProductSalesStats(
      sales,
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 30),
      now: now,
    );
    expect(rows.map((r) => r.id), ['b', 'a']);
    expect(rows[0].quantity, 10);
    expect(rows[0].revenue, 500);
    expect(rows[1].quantity, 6);
    expect(rows[1].revenue, 600);
    expect(rows[1].salesCount, 2);
  });

  test('a single selected day includes that whole day', () {
    final sales = [
      _sale(DateTime(2026, 11, 4, 0, 5), [
        {'id': 'a', 'name': 'Sugar', 'price': 10, 'quantity': 1},
      ]),
      _sale(DateTime(2026, 11, 4, 23, 50), [
        {'id': 'a', 'name': 'Sugar', 'price': 10, 'quantity': 1},
      ]),
      _sale(DateTime(2026, 11, 5, 0, 1), [
        {'id': 'a', 'name': 'Sugar', 'price': 10, 'quantity': 5},
      ]),
    ];
    final rows = computeProductSalesStats(
      sales,
      start: DateTime(2026, 11, 4),
      end: DateTime(2026, 11, 4),
      now: now,
    );
    expect(rows.single.quantity, 2);
  });

  test('only selected products are counted', () {
    final sales = [
      _sale(DateTime(2026, 11, 2), [
        {'id': 'a', 'name': 'Sugar', 'price': 1, 'quantity': 1},
        {'id': 'b', 'name': 'Rice', 'price': 1, 'quantity': 1},
      ]),
    ];
    final rows = computeProductSalesStats(
      sales,
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 30),
      productIds: {'b'},
      now: now,
    );
    expect(rows.map((r) => r.id), ['b']);
  });

  test('base quantity is used for units and sold quantity for revenue', () {
    final sales = [
      _sale(DateTime(2026, 11, 2), [
        {
          'id': 'a',
          'name': 'Eggs',
          'price': 6000,
          'quantity': 2,
          'baseQuantity': 24,
          'saleUomLabel': 'Dozen',
        },
      ]),
    ];
    final rows = computeProductSalesStats(
      sales,
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 30),
      now: now,
    );
    expect(rows.single.quantity, 24);
    expect(rows.single.revenue, 12000);
  });

  test('services on an unpaid sale and debt repayments are skipped', () {
    final sales = [
      _sale(DateTime(2026, 11, 2), [
        {
          'id': 's1',
          'name': 'Repair',
          'itemType': 'service',
          'price': 100,
          'quantity': 1,
        },
      ], debt: 100),
      _sale(DateTime(2026, 11, 2), [
        {'id': 'a', 'name': 'Sugar', 'price': 1, 'quantity': 1},
      ], saleType: 'debt_repayment'),
    ];
    final rows = computeProductSalesStats(
      sales,
      start: DateTime(2026, 11, 1),
      end: DateTime(2026, 11, 30),
      now: now,
    );
    expect(rows, isEmpty);
  });
}
