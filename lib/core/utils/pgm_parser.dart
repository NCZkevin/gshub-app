import 'dart:typed_data';

/// PGM 文件解析结果
class PgmImage {
  final int width;
  final int height;
  final int maxVal;
  final Uint8List pixels; // 灰度像素，length = width * height

  const PgmImage({
    required this.width,
    required this.height,
    required this.maxVal,
    required this.pixels,
  });
}

/// 解析 ASCII PGM (P2) 或二进制 PGM (P5) 字节数据
PgmImage parsePgm(Uint8List bytes) {
  int pos = 0;

  String readToken() {
    // 跳过空白和注释
    while (pos < bytes.length) {
      if (bytes[pos] == 35) {
        // '#' 注释行
        while (pos < bytes.length && bytes[pos] != 10) {
          pos++;
        }
      } else if (bytes[pos] == 32 ||
          bytes[pos] == 9 ||
          bytes[pos] == 10 ||
          bytes[pos] == 13) {
        pos++;
      } else {
        break;
      }
    }
    final start = pos;
    while (pos < bytes.length &&
        bytes[pos] != 32 &&
        bytes[pos] != 9 &&
        bytes[pos] != 10 &&
        bytes[pos] != 13) {
      pos++;
    }
    return String.fromCharCodes(bytes.sublist(start, pos));
  }

  final magic = readToken();
  final width = int.parse(readToken());
  final height = int.parse(readToken());
  final maxVal = int.parse(readToken());

  // 跳过紧随 maxVal 后的一个空白字符（P5 规定）
  if (pos < bytes.length) pos++;

  final pixels = Uint8List(width * height);

  if (magic == 'P5') {
    // 二进制格式
    for (int i = 0; i < pixels.length && pos < bytes.length; i++) {
      pixels[i] = bytes[pos++];
    }
  } else if (magic == 'P2') {
    // ASCII 格式
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = int.parse(readToken());
    }
  }

  return PgmImage(width: width, height: height, maxVal: maxVal, pixels: pixels);
}
