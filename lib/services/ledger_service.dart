import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../controllers/business_controller.dart';
import '../controllers/profile_controller.dart';
import '../models/expences.dart';

class LedgerService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final BusinessController _businessController = Get.find();
  final ProfileController _profileController = Get.find();

  String _businessId() {
    // Prefer the business map like other controllers in this app
    return _businessController.business['id'] ?? _businessController.businessId.value ?? '';
  }

  String _baseCurrency() {
    return _businessController.business['mainCurrency'] ?? 'TZS';
  }

  /// Stored on each ledger row as [fundSourceId]. Must match fund source [value] so
  /// [FundsSummary] per-source totals align with transactions (custom sources use doc id as value).
  /// Bucket totals (cash/bank/mobile) elsewhere use [BusinessController.getLedgerTypeForMethod] on the raw method.
  String _mapMethodToFundSource(String? method) {
    final original = (method ?? 'cash').toString().trim();
    if (original.isEmpty) return 'cash';
    // Custom / configured fund sources: keep stable id (matches fund source catalog).
    if (_businessController.isKnownFundSourceKey(original)) {
      return original;
    }
    final m = original.toLowerCase();
    // Legacy payment-method ids from older clients
    if (m == 'bank_transfer' || m == 'check') return 'bank';
    if (m == 'mobile_money') return 'mobile';
    // Built-in synonyms (substring heuristics for free-text methods)
    if (m == 'cash' || m.contains('cash')) return 'cash';
    if (m == 'bank' || m.contains('bank') || m.contains('cheque') ||
        m.contains('check') || m.contains('pos') || m.contains('card')) {
      return 'bank';
    }
    if (m == 'mobile' || m.contains('mobile') || m.contains('lipa') ||
        m.contains('mpesa') || m.contains('m-pesa') || m.contains('tigo') ||
        m.contains('airtel')) {
      return 'mobile';
    }
    if (m == 'other') return 'other';
    // Custom fund source: keep stable id (usually Firestore doc id), not ledgerType bucket
    return original;
  }

  Future<void> postExpenseOut(Expense expense) async {
    final String businessId = _businessId();
    if (businessId.isEmpty) {
      print('❌ LedgerService.postExpenseOut: businessId empty');
      return;
    }

    // Idempotency: same expense id + line index + fund source
    final String lineIndex = '0';
    final String fundSourceId = expense.fundSource; // transitional: using enum value as source id
    final String idempotencyKey = 'expense:${expense.id}:$lineIndex:$fundSourceId';
    final String docId = idempotencyKey.replaceAll(':', '__');
    final String paymentLabel =
        _businessController.paymentMethodLabelForValue(expense.fundSource);

    final String currency = _baseCurrency();
    final double amount = expense.amount;
    final double fxRate = 1.0; // assuming same currency for now
    final double baseAmount = amount * fxRate;

    final Map<String, dynamic> payload = {
      'businessId': businessId,
      'fundSourceId': fundSourceId,
      'paymentMethodValue': expense.fundSource,
      'paymentMethodLabel': paymentLabel,
      'direction': 'out',
      'amount': amount,
      'currency': currency,
      'baseAmount': baseAmount,
      'baseCurrency': currency,
      'fxRate': fxRate,
      'transactionType': 'expense',
      'referenceType': 'expense',
      'referenceId': expense.id,
      'lineIndex': 0,
      'counterpartyType': 'none',
      'counterpartyId': null,
      'counterpartyName': null,
      'note': expense.fundSource == 'other' ? (expense.fundSourceNote) : null,
      'postedAt': expense.date,
      'createdAt': Timestamp.now(),
      'createdBy': _profileController.user['id'],
      'idempotencyKey': idempotencyKey,
      'reversalOfLedgerId': null,
      'reconciled': false,
      'reconciliationId': null,
      'reconciliationDate': null,
    };

    final docRef = firestore
        .collection('ledger')
        .doc(businessId)
        .collection('entries')
        .doc(docId);

    final existing = await docRef.get();
    if (existing.exists) {
      print('ℹ️ LedgerService.postExpenseOut: idempotent, skipping existing $docId');
      return;
    }

    await docRef.set(payload);
    print('✅ LedgerService.postExpenseOut: posted OUT ${amount.toStringAsFixed(2)} $currency from $fundSourceId for expense ${expense.id}');
  }

  Future<void> postPurchaseOut({
    required String purchaseId,
    required List<dynamic> payments,
    required Timestamp postedAt,
    String? supplierId,
    String? supplierName,
  }) async {
    final String businessId = _businessId();
    if (businessId.isEmpty) {
      print('❌ LedgerService.postPurchaseOut: businessId empty');
      return;
    }

    final String currency = _baseCurrency();
    for (int i = 0; i < payments.length; i++) {
      final p = payments[i] as Map<String, dynamic>;
      final double amount = (p['amount'] is int)
          ? (p['amount'] as int).toDouble()
          : ((p['amount'] ?? 0.0) as num).toDouble();
      if (amount <= 0) continue;
      final String method = (p['method'] ?? 'cash').toString();
      final String fundSourceId = _mapMethodToFundSource(method);
      final String idempotencyKey = 'purchase:$purchaseId:$i:$fundSourceId';
      final String docId = idempotencyKey.replaceAll(':', '__');
      final String purchasePayLabel =
          _businessController.paymentMethodLabelForValue(method);

      final payload = {
        'businessId': businessId,
        'fundSourceId': fundSourceId,
        'paymentMethodValue': method,
        'paymentMethodLabel': purchasePayLabel,
        'direction': 'out',
        'amount': amount,
        'currency': currency,
        'baseAmount': amount,
        'baseCurrency': currency,
        'fxRate': 1.0,
        'transactionType': 'purchase',
        'referenceType': 'purchase',
        'referenceId': purchaseId,
        'lineIndex': i,
        'counterpartyType': supplierId != null && supplierId.isNotEmpty ? 'supplier' : 'none',
        'counterpartyId': supplierId,
        'counterpartyName': supplierName,
        'note': null,
        'postedAt': postedAt,
        'createdAt': Timestamp.now(),
        'createdBy': _profileController.user['id'],
        'idempotencyKey': idempotencyKey,
        'reversalOfLedgerId': null,
        'reconciled': false,
        'reconciliationId': null,
        'reconciliationDate': null,
      };

      final docRef = firestore
          .collection('ledger')
          .doc(businessId)
          .collection('entries')
          .doc(docId);

      final existing = await docRef.get();
      if (existing.exists) {
        print('ℹ️ LedgerService.postPurchaseOut: idempotent, skipping existing $docId');
        continue;
      }
      await docRef.set(payload);
      print('✅ LedgerService.postPurchaseOut: OUT ${amount.toStringAsFixed(2)} $currency from $fundSourceId for purchase $purchaseId');
    }
  }

  Future<void> postSaleIn({
    required String saleId,
    required List<dynamic> payments,
    required Timestamp postedAt,
    String? clientId,
    String? clientName,
  }) async {
    final String businessId = _businessId();
    if (businessId.isEmpty) {
      print('❌ LedgerService.postSaleIn: businessId empty');
      return;
    }

    final String currency = _baseCurrency();
    for (int i = 0; i < payments.length; i++) {
      final p = payments[i] as Map<String, dynamic>;
      final double amount = (p['amount'] is int)
          ? (p['amount'] as int).toDouble()
          : ((p['amount'] ?? 0.0) as num).toDouble();
      if (amount <= 0) continue;
      final String method = (p['method'] ?? 'cash').toString();
      final String fundSourceId = _mapMethodToFundSource(method);
      final String idempotencyKey = 'sale:$saleId:$i:$fundSourceId:${postedAt.seconds}';
      final String docId = idempotencyKey.replaceAll(':', '__');
      final String paymentLabel =
          _businessController.paymentMethodLabelForValue(method);

      final payload = {
        'businessId': businessId,
        'fundSourceId': fundSourceId,
        'paymentMethodValue': method,
        'paymentMethodLabel': paymentLabel,
        'direction': 'in',
        'amount': amount,
        'currency': currency,
        'baseAmount': amount,
        'baseCurrency': currency,
        'fxRate': 1.0,
        'transactionType': 'sale',
        'referenceType': 'sale',
        'referenceId': saleId,
        'lineIndex': i,
        'counterpartyType': clientId != null && clientId.isNotEmpty ? 'client' : 'none',
        'counterpartyId': clientId,
        'counterpartyName': clientName,
        'note': null,
        'postedAt': postedAt,
        'createdAt': Timestamp.now(),
        'createdBy': _profileController.user['id'],
        'idempotencyKey': idempotencyKey,
        'reversalOfLedgerId': null,
        'reconciled': false,
        'reconciliationId': null,
        'reconciliationDate': null,
      };

      final docRef = firestore
          .collection('ledger')
          .doc(businessId)
          .collection('entries')
          .doc(docId);

      final existing = await docRef.get();
      if (existing.exists) {
        print('ℹ️ LedgerService.postSaleIn: idempotent, skipping existing $docId');
        continue;
      }
      await docRef.set(payload);
      print('✅ LedgerService.postSaleIn: IN ${amount.toStringAsFixed(2)} $currency to $fundSourceId for sale $saleId');
    }
  }

  Future<void> deleteSaleLedgerEntries({
    required String saleId,
    required List<dynamic> payments,
    required Timestamp postedAt,
  }) async {
    final String businessId = _businessId();
    if (businessId.isEmpty) {
      print('❌ LedgerService.deleteSaleLedgerEntries: businessId empty');
      return;
    }

    if (payments.isEmpty) {
      final String idempotencyKey = 'sale:$saleId:0:cash:${postedAt.seconds}';
      final String docId = idempotencyKey.replaceAll(':', '__');
      final docRef = firestore
          .collection('ledger')
          .doc(businessId)
          .collection('entries')
          .doc(docId);
      final existing = await docRef.get();
      if (existing.exists) {
        await docRef.delete();
        print('✅ LedgerService.deleteSaleLedgerEntries: deleted $docId');
      }
      return;
    }

    for (int i = 0; i < payments.length; i++) {
      final p = payments[i] as Map<String, dynamic>;
      final String method = (p['method'] ?? 'cash').toString();
      final String fundSourceId = _mapMethodToFundSource(method);
      final String idempotencyKey = 'sale:$saleId:$i:$fundSourceId:${postedAt.seconds}';
      final String docId = idempotencyKey.replaceAll(':', '__');

      final docRef = firestore
          .collection('ledger')
          .doc(businessId)
          .collection('entries')
          .doc(docId);

      final existing = await docRef.get();
      if (existing.exists) {
        await docRef.delete();
        print('✅ LedgerService.deleteSaleLedgerEntries: deleted $docId');
      } else {
        print('ℹ️ LedgerService.deleteSaleLedgerEntries: $docId not found, skipping');
      }
    }
  }

  Future<void> postSupplierDebtPaymentOut({
    required String debtId,
    required double amount,
    required String method,
    required Timestamp postedAt,
  }) async {
    final String businessId = _businessId();
    if (businessId.isEmpty) {
      print('❌ LedgerService.postSupplierDebtPaymentOut: businessId empty');
      return;
    }
    if (amount <= 0) return;

    final String currency = _baseCurrency();
    final String fundSourceId = _mapMethodToFundSource(method);
    final String idempotencyKey = 'supplier_payment:$debtId:0:$fundSourceId:${postedAt.seconds}';
    final String docId = idempotencyKey.replaceAll(':', '__');
    final String supplierPayLabel =
        _businessController.paymentMethodLabelForValue(method);

    final payload = {
      'businessId': businessId,
      'fundSourceId': fundSourceId,
      'paymentMethodValue': method,
      'paymentMethodLabel': supplierPayLabel,
      'direction': 'out',
      'amount': amount,
      'currency': currency,
      'baseAmount': amount,
      'baseCurrency': currency,
      'fxRate': 1.0,
      'transactionType': 'supplier_payment',
      'referenceType': 'supplier_debt',
      'referenceId': debtId,
      'lineIndex': 0,
      'counterpartyType': 'supplier',
      'counterpartyId': null,
      'counterpartyName': null,
      'note': null,
      'postedAt': postedAt,
      'createdAt': Timestamp.now(),
      'createdBy': _profileController.user['id'],
      'idempotencyKey': idempotencyKey,
      'reversalOfLedgerId': null,
      'reconciled': false,
      'reconciliationId': null,
      'reconciliationDate': null,
    };

    final docRef = firestore
        .collection('ledger')
        .doc(businessId)
        .collection('entries')
        .doc(docId);

    final existing = await docRef.get();
    if (existing.exists) {
      print('ℹ️ LedgerService.postSupplierDebtPaymentOut: idempotent, skipping existing $docId');
      return;
    }
    await docRef.set(payload);
    print('✅ LedgerService.postSupplierDebtPaymentOut: OUT ${amount.toStringAsFixed(2)} $currency from $fundSourceId for supplier debt $debtId');
  }
}
