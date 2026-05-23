import 'package:flutter/material.dart';

/// Normalizes date ranges for Funga Hesabu / closed-book reports.
class ReportDateRange {
  /// Inclusive start: 00:00:00 on the selected calendar day.
  static DateTime periodStart(DateTime date) {
    return DateUtils.dateOnly(date);
  }

  /// Inclusive end:
  /// - If [date] is today: up to [now] (e.g. report run at 6:00 PM on 15 Apr).
  /// - Otherwise: 23:59:59.999 on that calendar day (full day included).
  static DateTime periodEnd(DateTime date, {DateTime? now}) {
    final DateTime clock = now ?? DateTime.now();
    final DateTime endDay = DateUtils.dateOnly(date);
    final DateTime today = DateUtils.dateOnly(clock);
    if (endDay == today) {
      return clock;
    }
    return DateTime(
      endDay.year,
      endDay.month,
      endDay.day,
      23,
      59,
      59,
      999,
    );
  }
}
