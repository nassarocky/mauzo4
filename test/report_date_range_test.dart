import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mauzo/utils/report_date_range.dart';

void main() {
  test('periodStart is midnight on selected day', () {
    final start = ReportDateRange.periodStart(DateTime(2026, 4, 2, 15, 30));
    expect(start, DateTime(2026, 4, 2));
  });

  test('periodEnd on past day includes full day until 23:59:59.999', () {
    final now = DateTime(2026, 5, 22, 14, 0);
    final end = ReportDateRange.periodEnd(DateTime(2026, 4, 15), now: now);
    expect(end.year, 2026);
    expect(end.month, 4);
    expect(end.day, 15);
    expect(end.hour, 23);
    expect(end.minute, 59);
    expect(end.second, 59);
    expect(end.millisecond, 999);
  });

  test('periodEnd on today uses current clock time', () {
    final now = DateTime(2026, 4, 15, 18, 0);
    final end = ReportDateRange.periodEnd(DateTime(2026, 4, 15), now: now);
    expect(end, now);
  });
}
