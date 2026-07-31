/// Display name for a sale's customer on receipts / exports.
/// Prefer the registered client name; fall back to free-text [saleClientName].
String saleClientDisplayName({
  required String lookedUpClientName,
  required String saleClientName,
}) {
  final lookedUp = lookedUpClientName.trim();
  if (lookedUp.isNotEmpty) return lookedUp;
  final fallback = saleClientName.trim();
  if (fallback.isNotEmpty) return fallback;
  return '';
}
