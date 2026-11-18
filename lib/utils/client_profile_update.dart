/// Profile fields that may be changed when editing a registered client.
///
/// Debt, advance, and created date stay untouched so a later loan cannot be
/// overwritten by a name/phone edit.
Map<String, dynamic> buildClientProfileUpdate({
  required String clientId,
  required String name,
  required String phone,
  String? note,
  String? image,
}) {
  final trimmedId = clientId.trim();
  if (trimmedId.isEmpty) {
    throw ArgumentError.value(clientId, 'clientId', 'Client ID is required');
  }

  final trimmedName = name.trim();
  if (trimmedName.isEmpty) {
    throw ArgumentError.value(name, 'name', 'Client name is required');
  }

  return {
    'id': trimmedId,
    'name': trimmedName,
    'phone': phone.trim(),
    'note': (note ?? '').trim(),
    'image': image,
  };
}
