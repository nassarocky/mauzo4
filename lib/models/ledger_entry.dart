import 'package:cloud_firestore/cloud_firestore.dart';

class LedgerEntry {
  final String id;
  final String businessId;
  final String fundSourceId; // e.g., 'cash', 'bank', 'mobile', or a fund source doc id
  final String direction; // 'in' | 'out'
  final double amount; // native currency amount
  final String currency; // native currency ISO
  final double baseAmount; // base currency amount
  final String baseCurrency; // base currency ISO
  final double fxRate; // baseAmount = amount * fxRate
  final String transactionType; // e.g., 'expense', 'purchase', 'sale', 'transfer', 'adjustment'
  final String referenceType; // 'expense' | 'purchase' | 'sale' | 'supplier_debt' | 'client_debt' | 'transfer' | 'system'
  final String referenceId; // originating document id
  final int lineIndex; // for split payments
  final String? counterpartyType; // 'supplier' | 'client' | 'none'
  final String? counterpartyId;
  final String? counterpartyName;
  final String? note;
  final Timestamp postedAt; // business event time
  final Timestamp createdAt; // system creation time
  final String? createdBy; // user id
  final String idempotencyKey; // used to avoid duplicates
  final String? reversalOfLedgerId; // if this row reverses another
  final bool reconciled;
  final String? reconciliationId;
  final Timestamp? reconciliationDate;

  LedgerEntry({
    required this.id,
    required this.businessId,
    required this.fundSourceId,
    required this.direction,
    required this.amount,
    required this.currency,
    required this.baseAmount,
    required this.baseCurrency,
    required this.fxRate,
    required this.transactionType,
    required this.referenceType,
    required this.referenceId,
    required this.lineIndex,
    this.counterpartyType,
    this.counterpartyId,
    this.counterpartyName,
    this.note,
    required this.postedAt,
    required this.createdAt,
    this.createdBy,
    required this.idempotencyKey,
    this.reversalOfLedgerId,
    this.reconciled = false,
    this.reconciliationId,
    this.reconciliationDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'businessId': businessId,
      'fundSourceId': fundSourceId,
      'direction': direction,
      'amount': amount,
      'currency': currency,
      'baseAmount': baseAmount,
      'baseCurrency': baseCurrency,
      'fxRate': fxRate,
      'transactionType': transactionType,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'lineIndex': lineIndex,
      'counterpartyType': counterpartyType,
      'counterpartyId': counterpartyId,
      'counterpartyName': counterpartyName,
      'note': note,
      'postedAt': postedAt,
      'createdAt': createdAt,
      'createdBy': createdBy,
      'idempotencyKey': idempotencyKey,
      'reversalOfLedgerId': reversalOfLedgerId,
      'reconciled': reconciled,
      'reconciliationId': reconciliationId,
      'reconciliationDate': reconciliationDate,
    };
  }
}
