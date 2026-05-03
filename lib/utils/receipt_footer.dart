import 'package:get/get.dart';

/// Message shown at the bottom of receipts/invoices. Stored on business as [receiptFooterMessage].
String receiptFooterMessage(Map<String, dynamic> business) {
  final raw = business['receiptFooterMessage'];
  final s = raw?.toString().trim() ?? '';
  if (s.isNotEmpty) return s;
  return 'receipt_footer_default'.tr;
}

/// Same rule as [InvoicePaymentSettingsScreen] list tile: missing [showOnInvoice] defaults to ON.
/// Receipts/invoices must use this instead of `== true` or older rows (null / absent) are omitted.
bool paymentDetailShowsOnInvoice(Map<String, dynamic> m) {
  final v = m['showOnInvoice'];
  if (v == false) return false;
  final vs = v?.toString().trim().toLowerCase() ?? '';
  if (vs == 'false' || vs == '0' || vs == 'no') return false;
  return true;
}

/// Normalizes a Firestore / JSON payment-method map: string keys, flattens nested name fields.
Map<String, dynamic> paymentDetailMapFromFirestore(dynamic raw) {
  if (raw == null) return {};
  final Map<String, dynamic> base;
  if (raw is Map<String, dynamic>) {
    base = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  } else if (raw is Map) {
    base = Map<String, dynamic>.from(
      raw.map((k, v) => MapEntry(k.toString(), v)),
    );
  } else {
    return {};
  }

  bool accountNameMissingOrBlank() {
    final v = base['accountName'];
    if (v == null) return true;
    return v.toString().trim().isEmpty;
  }

  void copyNameFromInner(Map<String, dynamic> inner) {
    final im = Map<String, dynamic>.from(
      inner.map((k, v) => MapEntry(k.toString(), v)),
    );
    for (final nk in [
      'accountName',
      'account_name',
      'AccountName',
      'name',
      'holderName',
      'title',
      'label',
    ]) {
      final v = im[nk];
      if (v != null && v.toString().trim().isNotEmpty) {
        base['accountName'] = v.toString().trim();
        return;
      }
    }
  }

  for (final nestedKey in ['account', 'details', 'bankAccount', 'mobileAccount']) {
    if (!accountNameMissingOrBlank()) break;
    final nested = base[nestedKey];
    if (nested is Map) {
      copyNameFromInner(Map<String, dynamic>.from(
        nested.map((k, v) => MapEntry(k.toString(), v)),
      ));
    }
  }

  return base;
}

/// Holder / account name for invoice payment rows (supports common Firestore key variants).
///
/// Pass [businessForFallback] so a business-level name (e.g. set in Firebase) fills the column when
/// per-row names are missing or stored under non-standard keys.
String receiptPaymentAccountLine(
  dynamic detail, {
  Map<String, dynamic>? businessForFallback,
}) {
  final m = paymentDetailMapFromFirestore(detail);

  for (final key in [
    'accountName',
    'account_name',
    'AccountName',
    'accountsName',
    'AccountsName',
    'ACCOUNTS_NAME',
    'holderName',
    'holder',
    'accountHolder',
    'beneficiary',
    'accountHolderName',
    'beneficiaryName',
    'businessName',
    'payee',
    'recipient',
    'Accounts name',
    'ACCOUNTS NAME',
    'Account name',
  ]) {
    final v = m[key];
    if (v == null) continue;
    final s = v.toString().trim();
    if (s.isNotEmpty) return s;
  }
  final legacy = m['name'];
  if (legacy != null) {
    final s = legacy.toString().trim();
    if (s.isNotEmpty) return s;
  }
  // Imports / manual Firestore edits: keys that normalize to known tokens
  for (final e in m.entries) {
    final keyNorm = e.key
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll(' ', '');
    if (keyNorm == 'accountname' ||
        keyNorm == 'accountsname' ||
        keyNorm == 'holdername' ||
        keyNorm == 'accountholder' ||
        keyNorm == 'beneficiaryname' ||
        keyNorm == 'payeename' ||
        keyNorm == 'recipientname' ||
        keyNorm == 'businessname') {
      final s = e.value?.toString().trim() ?? '';
      if (s.isNotEmpty) return s;
    }
  }

  if (businessForFallback != null) {
    for (final key in [
      'paymentAccountName',
      'invoiceAccountName',
      'accountsName',
      'accountName',
      'paymentAccountsName',
      'defaultPaymentAccountName',
      'businessAccountName',
    ]) {
      final v = businessForFallback[key];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }

  return '';
}
