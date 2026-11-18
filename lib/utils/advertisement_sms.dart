import 'debt_reminder_message.dart';

String applyAdvertisementTemplate(
  String template, {
  required String clientName,
  required String businessName,
}) {
  final name = clientName.trim().isEmpty ? 'Mteja' : clientName.trim();
  final business = businessName.trim().isEmpty
      ? 'Biashara'
      : businessName.trim();
  return template
      .replaceAll(RegExp(r'\{name\}', caseSensitive: false), name)
      .replaceAll(RegExp(r'\{client\}', caseSensitive: false), name)
      .replaceAll(RegExp(r'\{business\}', caseSensitive: false), business)
      .replaceAll(RegExp(r'\{shop\}', caseSensitive: false), business)
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

int advertisementSmsSegments(
  String template, {
  required String clientName,
  required String businessName,
}) {
  return countSmsSegments(
    applyAdvertisementTemplate(
      template,
      clientName: clientName,
      businessName: businessName,
    ),
  );
}
