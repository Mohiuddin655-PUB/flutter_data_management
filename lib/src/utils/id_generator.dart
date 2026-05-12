import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

class DataIdGenerator {
  final DataByteType type;

  DataIdGenerator._(this.type);

  static DataIdGenerator get i => DataIdGenerator._(DataByteType.x16);

  factory DataIdGenerator.generate(DataByteType type) =>
      DataIdGenerator._(type);

  int get length => type.value;

  late final Uint8List bytes = _generateBytes();

  Uint8List _generateBytes() {
    final secure = Random.secure();
    final result = Uint8List(length);
    for (var i = 0; i < length; i++) {
      result[i] = secure.nextInt(256);
    }
    return result;
  }

  String get key => DateTime.now().millisecondsSinceEpoch.toString();

  String get secretKey => bytesToHex(bytes);

  String get secretIV => bytesToHex(bytes);

  static String bytesToHex(Uint8List bytes) {
    final buffer = StringBuffer();
    const hexChars = "0123456789ABCDEF";
    for (final byte in bytes) {
      buffer.write(hexChars[(byte & 0xF0) >> 4]);
      buffer.write(hexChars[byte & 0x0F]);
    }
    return buffer.toString();
  }
}

enum DataByteType {
  x2(2),
  x4(4),
  x8(8),
  x16(16),
  x32(32),
  x64(64),
  x128(128);

  final int value;

  const DataByteType(this.value);
}
