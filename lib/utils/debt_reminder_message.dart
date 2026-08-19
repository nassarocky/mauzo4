String formatDebtSmsAmount(double amount) {
  if ((amount - amount.round()).abs() < 0.005) {
    return amount.round().toString();
  }
  return amount.toStringAsFixed(2);
}

/// Client-side preview of the reminder the Cloud Function will send.
String buildDebtReminderMessage({
  required String clientName,
  required double amount,
  required String currency,
  required String businessName,
  String lang = 'sw',
}) {
  final name = clientName.trim().isEmpty ? 'Mteja' : clientName.trim();
  final biz = businessName.trim().isEmpty ? 'duka' : businessName.trim();
  final cur = currency.trim().isEmpty ? 'TZS' : currency.trim();
  final amt = formatDebtSmsAmount(amount);
  if (lang == 'en') {
    return 'Hello $name, you owe $amt $cur to $biz. Please pay. Thank you.';
  }
  return 'Habari $name, una deni la $amt $cur kwa $biz. Tafadhali lipa. Asante.';
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
