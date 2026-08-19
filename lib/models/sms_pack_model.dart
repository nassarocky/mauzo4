class SmsPack {
  final String id;
  final int credits;
  final int price;
  final String label;

  const SmsPack({
    required this.id,
    required this.credits,
    required this.price,
    required this.label,
  });

  factory SmsPack.fromMap(Map<String, dynamic> data) {
    return SmsPack(
      id: (data['id'] ?? '').toString(),
      credits: (data['credits'] as num?)?.toInt() ?? 0,
      price: (data['price'] as num?)?.toInt() ?? 0,
      label: (data['label'] ?? '').toString(),
    );
  }

  static const List<SmsPack> defaults = [
    SmsPack(id: 'sms_50', credits: 50, price: 3000, label: 'SMS 50'),
    SmsPack(id: 'sms_100', credits: 100, price: 5000, label: 'SMS 100'),
    SmsPack(id: 'sms_500', credits: 500, price: 20000, label: 'SMS 500'),
    SmsPack(id: 'sms_1000', credits: 1000, price: 35000, label: 'SMS 1000'),
  ];
}
