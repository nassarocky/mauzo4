import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/models/client_model.dart';
import 'package:mauzo/utils/advance_summary.dart';

Client client(
  String id,
  double advance,
  List<Map<String, dynamic>> txns,
) {
  return Client(
    id: id,
    owner: 'o',
    name: id,
    phone: '',
    date: Timestamp.fromDate(DateTime(2026, 1, 1)),
    advance: advance,
    advanceTransactions: txns,
  );
}

Map<String, dynamic> txn(double amount, DateTime time) => {
  'amount': amount,
  'time': Timestamp.fromDate(time),
};

void main() {
  final start = DateTime(2026, 9, 1);
  final end = DateTime(2026, 9, 30, 23, 59, 59);

  test('collects only deposits inside the period and totals balances', () {
    final summary = computeAdvanceSummary(
      [
        client('a', 5000, [
          txn(3000, DateTime(2026, 9, 5)),
          txn(4000, DateTime(2026, 8, 20)), // before period
          txn(-2000, DateTime(2026, 9, 10)), // used
        ]),
        client('b', 1500, [
          txn(1500, DateTime(2026, 9, 30, 12)),
          txn(900, DateTime(2026, 10, 1)), // after period
        ]),
      ],
      start: start,
      end: end,
    );
    expect(summary.collectedInPeriod, 4500);
    expect(summary.usedInPeriod, 2000);
    expect(summary.totalBalance, 6500);
  });

  test('empty or malformed history gives zeros and ignores negative balance', () {
    final summary = computeAdvanceSummary(
      [
        client('c', 0, const []),
        client('d', -100, [
          {'amount': 'x', 'time': 'bad'},
        ]),
      ],
      start: start,
      end: end,
    );
    expect(summary.collectedInPeriod, 0);
    expect(summary.usedInPeriod, 0);
    expect(summary.totalBalance, 0);
  });
}
