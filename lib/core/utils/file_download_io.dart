import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String> saveDownloadedFile({
  required String filename,
  required Uint8List bytes,
}) async {
  final root = await getApplicationDocumentsDirectory();
  final dir = Directory('${root.path}/gshub_downloads');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
