import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/client_model.dart';

class AdvanceSummary {
  const AdvanceSummary({
    required this.collectedInPeriod,
    required this.usedInPeriod,
    required this.totalBalance,
  });

  /// Money customers deposited as advance during the period.
  final double collectedInPeriod;

  /// Advance that was deducted from customers during the period.
  final double usedInPeriod;

  /// Advance currently held for all customers (what is still available).
  final double totalBalance;
}

/// Builds the advance figures for a report.
///
/// [collectedInPeriod] adds every positive advance entry whose time is between
/// [start] and [end] (inclusive). [usedInPeriod] adds the reductions
/// (negative entries) in the same window, as a positive number.
/// [totalBalance] is the sum of every client's current advance (never below 0).
AdvanceSummary computeAdvanceSummary(
  Iterable<Client> clients, {
  required DateTime start,
  required DateTime end,
}) {
  double collected = 0;
  double used = 0;
  double balance = 0;

  for (final client in clients) {
    if (client.advance > 0) balance += client.advance;

    for (final entry in client.advanceTransactions) {
      if (entry is! Map) continue;
      final time = _toDateTime(entry['time']);
      if (time == null || time.isBefore(start) || time.isAfter(end)) continue;
      final raw = entry['amount'];
      final amount = raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
      if (amount > 0) {
        collected += amount;
      } else if (amount < 0) {
        used += -amount;
      }
    }
  }

  return AdvanceSummary(
    collectedInPeriod: collected,
    usedInPeriod: used,
    totalBalance: balance,
  );
}

DateTime? _toDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
