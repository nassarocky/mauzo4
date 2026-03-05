import 'dart:async';

import 'package:get/get.dart';
import 'package:mauzo/models/aggregates.dart';
import 'package:mauzo/services/firestore_db.dart';

class AggregatesController extends GetxController {
  StreamSubscription<PeriodAggregate?>? _periodSub;
  StreamSubscription<AggregatesMetaTotals?>? _metaSub;

  final period = Rxn<PeriodAggregate>();
  final meta = Rxn<AggregatesMetaTotals>();

  @override
  void onInit() {
    super.onInit();
    try {
      _periodSub = FirestoreDb().getCurrentPeriodAggregate().listen((data) {
        period.value = data;
      });
      _metaSub = FirestoreDb().getAggregatesMetaTotals().listen((data) {
        meta.value = data;
      });
    } catch (_) {}
  }

  double get paymentsCash => period.value?.paymentsCash ?? 0.0;
  double get paymentsBank => period.value?.paymentsBank ?? 0.0;
  double get paymentsMobile => period.value?.paymentsMobile ?? 0.0;
  double get debtCollected => period.value?.debtCollected ?? 0.0;
  double get expensesTotal => period.value?.expensesTotal ?? 0.0;
  double get purchasesPaidTotal => period.value?.purchasesPaidTotal ?? 0.0;
  double get availableBalance => period.value?.availableBalance ?? 0.0;
  String get currency => period.value?.currency ?? 'TZS';
  DateTime? get updatedAt => period.value?.updatedAt;
  double get inflows => paymentsCash + paymentsBank + paymentsMobile;

  double get debtOutstandingTotal => meta.value?.debtOutstandingTotal ?? 0.0;

  @override
  void onClose() {
    _periodSub?.cancel();
    _metaSub?.cancel();
    super.onClose();
  }
}
