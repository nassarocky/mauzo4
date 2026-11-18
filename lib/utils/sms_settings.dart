class SmsSettings {
  static const String afterModeOff = 'off';
  static const String afterModeDays = 'days';
  static const String afterModeDaily = 'daily';
  static const String afterModeWeekly = 'weekly';

  final int defaultCreditDays;
  final List<int> reminderDaysBefore;
  final List<int> reminderDaysAfter;
  final String reminderAfterMode;
  final int reminderMaxCount;
  final String debtReminderTemplate;
  final bool dailyDigestEnabled;
  /// Hour (0–23) in East Africa Time for the daily sales/profit SMS.
  final int dailyDigestHour;
  /// Minute (0–59) in East Africa Time for the daily sales/profit SMS.
  final int dailyDigestMinute;
  final bool expiryAlertEnabled;
  final bool lowStockAlertEnabled;
  final bool advanceSmsEnabled;
  final bool debtPaymentSmsEnabled;

  const SmsSettings({
    this.defaultCreditDays = 7,
    this.reminderDaysBefore = const [3, 1, 0],
    this.reminderDaysAfter = const [],
    this.reminderAfterMode = afterModeOff,
    this.reminderMaxCount = 5,
    this.debtReminderTemplate = '',
    this.dailyDigestEnabled = false,
    this.dailyDigestHour = 20,
    this.dailyDigestMinute = 0,
    this.expiryAlertEnabled = false,
    this.lowStockAlertEnabled = false,
    this.advanceSmsEnabled = true,
    this.debtPaymentSmsEnabled = true,
  });

  static int clampHour(dynamic raw, {int fallback = 20}) {
    final n = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (n == null) return fallback;
    return n.clamp(0, 23).toInt();
  }

  static int clampMinute(dynamic raw, {int fallback = 0}) {
    final n = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
    if (n == null) return fallback;
    return n.clamp(0, 59).toInt();
  }

  String get dailyDigestTimeLabel {
    final h = dailyDigestHour.toString().padLeft(2, '0');
    final m = dailyDigestMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static List<int> _parseDayList(dynamic raw, {required bool allowZero}) {
    if (raw is! List) return const [];
    final days = raw
        .map((e) => (e as num?)?.toInt())
        .whereType<int>()
        .where((n) => allowZero ? n >= 0 && n <= 60 : n > 0 && n <= 60)
        .toSet()
        .toList();
    days.sort((a, b) => allowZero ? b.compareTo(a) : a.compareTo(b));
    return days;
  }

  static String normalizeAfterMode(String? raw, List<int> afterDays) {
    final mode = (raw ?? '').toLowerCase();
    if (mode == afterModeDaily || mode == afterModeWeekly) return mode;
    if (mode == afterModeDays) {
      return afterDays.isNotEmpty ? afterModeDays : afterModeOff;
    }
    if (mode == afterModeOff) return afterModeOff;
    return afterDays.isNotEmpty ? afterModeDays : afterModeOff;
  }

  factory SmsSettings.fromMap(dynamic raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    var before = _parseDayList(map['reminderDaysBefore'], allowZero: true);
    if (before.isEmpty) before = const [3, 1, 0];
    final after = _parseDayList(map['reminderDaysAfter'], allowZero: false);
    final template = (map['debtReminderTemplate'] ?? '').toString().trim();
    return SmsSettings(
      defaultCreditDays:
          ((map['defaultCreditDays'] as num?)?.toInt() ?? 7).clamp(0, 365).toInt(),
      reminderDaysBefore: before,
      reminderDaysAfter: after,
      reminderAfterMode: normalizeAfterMode(
        map['reminderAfterMode']?.toString(),
        after,
      ),
      reminderMaxCount:
          ((map['reminderMaxCount'] as num?)?.toInt() ?? 5).clamp(1, 30).toInt(),
      debtReminderTemplate:
          template.length > 600 ? template.substring(0, 600) : template,
      dailyDigestEnabled: map['dailyDigestEnabled'] == true,
      dailyDigestHour: clampHour(map['dailyDigestHour']),
      dailyDigestMinute: clampMinute(map['dailyDigestMinute']),
      expiryAlertEnabled: map['expiryAlertEnabled'] == true,
      lowStockAlertEnabled: map['lowStockAlertEnabled'] == true,
      advanceSmsEnabled: map['advanceSmsEnabled'] != false,
      debtPaymentSmsEnabled: map['debtPaymentSmsEnabled'] != false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'defaultCreditDays': defaultCreditDays,
      'reminderDaysBefore': reminderDaysBefore,
      'reminderDaysAfter': reminderDaysAfter,
      'reminderAfterMode': reminderAfterMode,
      'reminderMaxCount': reminderMaxCount,
      'debtReminderTemplate': debtReminderTemplate,
      'dailyDigestEnabled': dailyDigestEnabled,
      'dailyDigestHour': dailyDigestHour,
      'dailyDigestMinute': dailyDigestMinute,
      'expiryAlertEnabled': expiryAlertEnabled,
      'lowStockAlertEnabled': lowStockAlertEnabled,
      'advanceSmsEnabled': advanceSmsEnabled,
      'debtPaymentSmsEnabled': debtPaymentSmsEnabled,
    };
  }

  SmsSettings copyWith({
    int? defaultCreditDays,
    List<int>? reminderDaysBefore,
    List<int>? reminderDaysAfter,
    String? reminderAfterMode,
    int? reminderMaxCount,
    String? debtReminderTemplate,
    bool? dailyDigestEnabled,
    int? dailyDigestHour,
    int? dailyDigestMinute,
    bool? expiryAlertEnabled,
    bool? lowStockAlertEnabled,
    bool? advanceSmsEnabled,
    bool? debtPaymentSmsEnabled,
  }) {
    final after = reminderDaysAfter ?? this.reminderDaysAfter;
    final template = debtReminderTemplate ?? this.debtReminderTemplate;
    return SmsSettings(
      defaultCreditDays: defaultCreditDays ?? this.defaultCreditDays,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
      reminderDaysAfter: after,
      reminderAfterMode: normalizeAfterMode(
        reminderAfterMode ?? this.reminderAfterMode,
        after,
      ),
      reminderMaxCount: reminderMaxCount ?? this.reminderMaxCount,
      debtReminderTemplate:
          template.length > 600 ? template.substring(0, 600) : template,
      dailyDigestEnabled: dailyDigestEnabled ?? this.dailyDigestEnabled,
      dailyDigestHour: clampHour(
        dailyDigestHour ?? this.dailyDigestHour,
        fallback: this.dailyDigestHour,
      ),
      dailyDigestMinute: clampMinute(
        dailyDigestMinute ?? this.dailyDigestMinute,
        fallback: this.dailyDigestMinute,
      ),
      expiryAlertEnabled: expiryAlertEnabled ?? this.expiryAlertEnabled,
      lowStockAlertEnabled: lowStockAlertEnabled ?? this.lowStockAlertEnabled,
      advanceSmsEnabled: advanceSmsEnabled ?? this.advanceSmsEnabled,
      debtPaymentSmsEnabled:
          debtPaymentSmsEnabled ?? this.debtPaymentSmsEnabled,
    );
  }
}

double _smsLineNumber(dynamic raw) {
  if (raw is num) return raw.toDouble();
  if (raw == null) return 0;
  return double.tryParse(raw.toString().replaceAll(',', '')) ?? 0;
}

List<Map<String, dynamic>> productLinesForSms(Iterable products) {
  return products.map((raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return {
      'name': (map['name'] ?? '').toString(),
      'qty': _smsLineNumber(map['quantity'] ?? map['count'] ?? 1),
      'price': _smsLineNumber(map['price'] ?? map['unitPrice']),
    };
  }).where((e) => (e['name'] as String).trim().isNotEmpty).toList();
}
