import 'package:get/get.dart';

/// Message shown at the bottom of receipts/invoices. Stored on business as [receiptFooterMessage].
String receiptFooterMessage(Map<String, dynamic> business) {
  final raw = business['receiptFooterMessage'];
  final s = raw?.toString().trim() ?? '';
  if (s.isNotEmpty) return s;
  return 'receipt_footer_default'.tr;
}
