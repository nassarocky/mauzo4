class Payment {
  final double amount;
  final String currency;
  // Payment method categorization: 'cash', 'bank', 'mobile' (e.g., lipa namba)
  final String method;

  Payment({required this.amount, required this.currency, this.method = 'cash'});

  // Convenience helpers for serialization
  Map<String, dynamic> toMap() => {
        'amount': amount,
        'currency': currency,
        'method': method,
      };

  static Payment fromMap(Map<String, dynamic> map) => Payment(
        amount: (map['amount'] ?? 0.0).toDouble(),
        currency: map['currency'] ?? '',
        method: map['method'] ?? 'cash',
      );
}
