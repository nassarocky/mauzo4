import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;

class FileDownloadHelper {
  /// Downloads a file on web or shares it on mobile platforms
  static Future<void> downloadOrShareFile({
    required Uint8List bytes,
    required String fileName,
    String? shareText,
  }) async {
    if (kIsWeb) {
      // Web: Download using blob
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // Mobile/Desktop: Use the mobile helper
      throw UnimplementedError(
        'Mobile download should use file_download_helper_mobile.dart directly',
      );
    }
  }
}
