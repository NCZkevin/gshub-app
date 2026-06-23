import 'dart:typed_data';

Future<String> saveDownloadedFile({
  required String filename,
  required Uint8List bytes,
}) {
  throw UnsupportedError('当前平台暂不支持保存文件');
}
