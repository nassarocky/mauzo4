/// Pretty-print business phone numbers for display (matches prior Settings formatting).
String formatBusinessPhoneDisplay(String? phoneNumber) {
  if (phoneNumber == null || phoneNumber.isEmpty) return '';

  final digits = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

  if (digits.startsWith('255')) {
    return '+255 ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
  if (digits.startsWith('254')) {
    return '+254 ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
  if (digits.startsWith('256')) {
    return '+256 ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
  if (digits.startsWith('250')) {
    return '+250 ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
  if (digits.startsWith('257')) {
    return '+257 ${digits.substring(3, 6)} ${digits.substring(6)}';
  }
  if (digits.startsWith('1')) {
    if (digits.length >= 10) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7, 11)}';
    }
  }

  return phoneNumber;
}
