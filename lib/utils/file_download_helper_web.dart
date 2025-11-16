import 'dart:typed_data';

/// Web implementation stub - actual web download is handled in the main helper
Future<void> saveAndShareFileMobile(
  Uint8List bytes,
  String fileName,
  String? shareText,
) async {
  // This should never be called on web, but providing a no-op implementation
  throw UnsupportedError('Use web download directly');
}
