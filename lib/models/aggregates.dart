import 'package:cloud_firestore/cloud_firestore.dart';

class PeriodAggregate {
  final double paymentsCash;
  final double paymentsBank;
  final double paymentsMobile;
  final double debtCollected;
  final double expensesTotal;
  final double purchasesPaidTotal;
  final double availableBalance;
  final String currency;
  final DateTime? startTime;
  final DateTime? updatedAt;

  PeriodAggregate({
    required this.paymentsCash,
    required this.paymentsBank,
    required this.paymentsMobile,
    required this.debtCollected,
    required this.expensesTotal,
    required this.purchasesPaidTotal,
    required this.availableBalance,
    required this.currency,
    required this.startTime,
    required this.updatedAt,
  });

  factory PeriodAggregate.fromMap(Map<String, dynamic> data) {
    double _num(x) {
      if (x == null) return 0.0;
      if (x is num) return x.toDouble();
      final v = double.tryParse(x.toString());
      return v ?? 0.0;
    }

    DateTime? _ts(v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return PeriodAggregate(
      paymentsCash: _num(data['paymentsCash']),
      paymentsBank: _num(data['paymentsBank']),
      paymentsMobile: _num(data['paymentsMobile']),
      debtCollected: _num(data['debtCollected']),
      expensesTotal: _num(data['expensesTotal']),
      purchasesPaidTotal: _num(data['purchasesPaidTotal']),
      availableBalance: _num(data['availableBalance']),
      currency: (data['currency'] ?? 'TZS').toString(),
      startTime: _ts(data['startTime']),
      updatedAt: _ts(data['updatedAt']),
    );
  }
}

class AggregatesMetaTotals {
  final double debtOutstandingTotal;
  final DateTime? updatedAt;

  AggregatesMetaTotals({
    required this.debtOutstandingTotal,
    required this.updatedAt,
  });

  factory AggregatesMetaTotals.fromMap(Map<String, dynamic> data) {
    double _num(x) {
      if (x == null) return 0.0;
      if (x is num) return x.toDouble();
      final v = double.tryParse(x.toString());
      return v ?? 0.0;
    }

    DateTime? _ts(v) {
      if (v is Timestamp) return v.toDate();
      return null;
    }

    return AggregatesMetaTotals(
      debtOutstandingTotal: _num(data['debtOutstandingTotal']),
      updatedAt: _ts(data['updatedAt']),
    );
  }
}
