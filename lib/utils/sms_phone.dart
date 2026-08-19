/// Normalize a client phone to digits with a country code (default Tanzania 255).
String normalizeSmsPhone(String? raw, {String defaultCountry = '255'}) {
  final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('0') && digits.length == 10) {
    return '$defaultCountry${digits.substring(1)}';
  }
  if (digits.length == 9 && !digits.startsWith(defaultCountry)) {
    return '$defaultCountry$digits';
  }
  return digits;
}

bool isValidSmsPhone(String? raw) {
  final n = normalizeSmsPhone(raw);
  return n.length >= 11 && n.length <= 15;
}
