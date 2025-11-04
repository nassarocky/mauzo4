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

  String _mapMethodToFundSource(String? method) {
    final m = (method ?? 'cash').toString().toLowerCase().trim();
    // Normalize common synonyms
    if (m == 'cash' || m.contains('cash')) return 'cash';
    if (m == 'bank' || m.contains('bank') || m.contains('cheque') || m.contains('check') || m.contains('pos') || m.contains('card')) return 'bank';
    if (m == 'mobile' || m.contains('mobile') || m.contains('lipa') || m.contains('mpesa') || m.contains('m-pesa') || m.contains('tigo') || m.contains('airtel')) return 'mobile';
    // Fallback
    return 'cash';
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

    final String currency = _baseCurrency();
    final double amount = expense.amount;
    final double fxRate = 1.0; // assuming same currency for now
    final double baseAmount = amount * fxRate;

    final Map<String, dynamic> payload = {
      'businessId': businessId,
      'fundSourceId': fundSourceId,
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

      final payload = {
        'businessId': businessId,
        'fundSourceId': fundSourceId,
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

      final payload = {
        'businessId': businessId,
        'fundSourceId': fundSourceId,
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

    final payload = {
      'businessId': businessId,
      'fundSourceId': fundSourceId,
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
