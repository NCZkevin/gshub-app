import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.io) 'file_download_io.dart'
    as impl;

Future<String> saveDownloadedFile({
  required String filename,
  required Uint8List bytes,
}) {
  return impl.saveDownloadedFile(filename: filename, bytes: bytes);
}
