import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/Desktop file save and share implementation
Future<void> saveAndShareFileMobile(
  Uint8List bytes,
  String fileName,
  String? shareText,
) async {
  final directory = await getApplicationDocumentsDirectory();
  final filePath = "${directory.path}/$fileName";
  final file = File(filePath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);

  await Share.shareXFiles(
    [XFile(filePath)],
    text: shareText ?? fileName,
  );
}
