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

  static int priceForCredits(int credits) {
    if (credits < 100) return 0;
    if (credits >= 1000) return credits * 25;
    return credits * 30;
  }

  static const List<SmsPack> defaults = [
    SmsPack(id: 'sms_100', credits: 100, price: 3000, label: 'SMS 100'),
    SmsPack(id: 'sms_200', credits: 200, price: 6000, label: 'SMS 200'),
    SmsPack(id: 'sms_500', credits: 500, price: 15000, label: 'SMS 500'),
    SmsPack(id: 'sms_1000', credits: 1000, price: 25000, label: 'SMS 1000'),
    SmsPack(id: 'sms_2000', credits: 2000, price: 50000, label: 'SMS 2000'),
  ];
}
