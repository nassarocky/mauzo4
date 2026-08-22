String formatDebtSmsAmount(double amount) {
  if ((amount - amount.round()).abs() < 0.005) {
    return amount.round().toString();
  }
  return amount.toStringAsFixed(2);
}

String formatSmsMoney(double amount, String currency) {
  final cur = currency.trim().isEmpty ? 'TZS' : currency.trim();
  return '$cur ${formatDebtSmsAmount(amount)}';
}

String defaultDebtReminderTemplate({String lang = 'sw'}) {
  if (lang == 'en') {
    return 'Hello {name}, you owe {currency} {amount} to {business}. Due {due}. Please pay. Thank you.';
  }
  return 'Habari {name}, una deni la {currency} {amount} kwa {business}. Tarehe ya malipo {due}. Tafadhali lipa. Asante.';
}

String applyDebtReminderTemplate(
  String template, {
  required String clientName,
  required double amount,
  required String currency,
  required String businessName,
  String? dueDateLabel,
}) {
  final name = clientName.trim().isEmpty ? 'Mteja' : clientName.trim();
  final biz = businessName.trim().isEmpty ? 'duka' : businessName.trim();
  final cur = currency.trim().isEmpty ? 'TZS' : currency.trim();
  final amt = formatDebtSmsAmount(amount);
  final due = (dueDateLabel ?? '').trim();
  return template
      .replaceAll(RegExp(r'\{amount\}\s*\{currency\}', caseSensitive: false), '{currency} {amount}')
      .replaceAll(RegExp(r'\{name\}', caseSensitive: false), name)
      .replaceAll(RegExp(r'\{client\}', caseSensitive: false), name)
      .replaceAll(RegExp(r'\{amount\}', caseSensitive: false), amt)
      .replaceAll(RegExp(r'\{currency\}', caseSensitive: false), cur)
      .replaceAll(RegExp(r'\{business\}', caseSensitive: false), biz)
      .replaceAll(RegExp(r'\{shop\}', caseSensitive: false), biz)
      .replaceAll(RegExp(r'\{due\}', caseSensitive: false), due)
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

/// Client-side preview of the reminder the Cloud Function will send.
String buildDebtReminderMessage({
  required String clientName,
  required double amount,
  required String currency,
  required String businessName,
  String? dueDateLabel,
  String? template,
  String lang = 'sw',
}) {
  final custom = (template ?? '').trim();
  if (custom.isNotEmpty) {
    return applyDebtReminderTemplate(
      custom,
      clientName: clientName,
      amount: amount,
      currency: currency,
      businessName: businessName,
      dueDateLabel: dueDateLabel,
    );
  }
  final name = clientName.trim().isEmpty ? 'Mteja' : clientName.trim();
  final biz = businessName.trim().isEmpty ? 'duka' : businessName.trim();
  final money = formatSmsMoney(amount, currency);
  final due = (dueDateLabel ?? '').trim();
  if (lang == 'en') {
    final extra = due.isEmpty ? '' : ' Due $due.';
    return 'Hello $name, you owe $money to $biz.$extra Please pay. Thank you.';
  }
  final extra = due.isEmpty ? '' : ' Tarehe ya malipo $due.';
  return 'Habari $name, una deni la $money kwa $biz.$extra Tafadhali lipa. Asante.';
}

int countSmsSegments(String text) {
  if (text.isEmpty) return 0;
  const gsmBasic =
      "@£\$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?"
      "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà";
  var gsm = true;
  for (final ch in text.split('')) {
    if (!gsmBasic.contains(ch)) {
      gsm = false;
      break;
    }
  }
  final singleLimit = gsm ? 160 : 70;
  final concatLimit = gsm ? 153 : 67;
  if (text.length <= singleLimit) return 1;
  return (text.length / concatLimit).ceil();
}
