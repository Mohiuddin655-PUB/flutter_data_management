import 'dart:convert' show jsonEncode, jsonDecode, base64Encode, base64Decode;
import 'dart:math' show Random;
import 'dart:typed_data' show Uint8List;

import '../utils/id_generator.dart' show DataByteType, DataIdGenerator;
import 'encryptor_stub.dart'
    if (dart.library.io) 'encryptor_io.dart'
    if (dart.library.js_interop) 'encryptor_web.dart';

typedef EncryptorRequestBuilder = Map<String, dynamic> Function(
  String ciphertext,
  String iv,
  String passcode,
);

typedef EncryptorResponseBuilder = ({String ciphertext, String iv}) Function(
    Map<String, dynamic> data);

class DataEncryptionError implements Exception {
  final String operation;
  final Object cause;
  final StackTrace stack;

  DataEncryptionError(this.operation, this.cause, this.stack);

  @override
  String toString() => 'DataEncryptionError($operation): $cause';
}

class DataEncryptor {
  static const _keyBytes = 32; // AES-256
  static const _ivBytes = 16; // AES-CBC block size

  final Uint8List _key;
  final String passcode;
  final AesBackend _backend;
  final EncryptorRequestBuilder _request;
  final EncryptorResponseBuilder _response;
  final Random _random;

  DataEncryptor._({
    required Uint8List key,
    required this.passcode,
    required EncryptorRequestBuilder request,
    required EncryptorResponseBuilder response,
    Random? random,
  })  : _key = key,
        _request = request,
        _response = response,
        _random = random ?? Random.secure(),
        _backend = createBackend();

  /// Creates an encryptor from a hex-encoded 32-byte (AES-256) key.
  /// IV is generated freshly per encryption — no IV parameter needed.
  factory DataEncryptor({
    required String key,
    required String passcode,
    EncryptorRequestBuilder? request,
    EncryptorResponseBuilder? response,
    Random? random,
  }) {
    final keyBytes = _decodeHex(key);
    if (keyBytes.length != _keyBytes) {
      throw ArgumentError(
        'key must be $_keyBytes bytes (${_keyBytes * 2} hex chars), '
        'got ${keyBytes.length} bytes',
      );
    }
    return DataEncryptor._(
      key: keyBytes,
      passcode: passcode,
      request: request ?? _defaultRequest,
      response: response ?? _defaultResponse,
      random: random,
    );
  }

  EncryptorRequestBuilder get request => _request;

  EncryptorResponseBuilder get response => _response;

  static Map<String, dynamic> _defaultRequest(
    String ciphertext,
    String iv,
    String passcode,
  ) =>
      {'data': ciphertext, 'iv': iv};

  static ({String ciphertext, String iv}) _defaultResponse(
    Map<String, dynamic> data,
  ) {
    final c = data['data'];
    final iv = data['iv'];
    if (c is! String || iv is! String) {
      throw const FormatException('response missing "data" or "iv" string');
    }
    return (ciphertext: c, iv: iv);
  }

  /// Encrypts [data] with a fresh IV per call.
  /// Throws [DataEncryptionError] on any failure.
  Future<Map<String, dynamic>> input(Map<String, dynamic> data) async {
    try {
      final iv = _freshIV();
      final ciphertext = await _backend.encrypt(jsonEncode(data), _key, iv);
      return _request(ciphertext, base64Encode(iv), passcode);
    } on DataEncryptionError {
      rethrow;
    } catch (e, s) {
      throw DataEncryptionError('encrypt', e, s);
    }
  }

  /// Decrypts an envelope previously produced by [input].
  /// Throws [DataEncryptionError] on any failure (including malformed input).
  Future<Map<String, dynamic>> output(Map<String, dynamic> data) async {
    try {
      final parsed = _response(data);
      final iv = base64Decode(parsed.iv);
      if (iv.length != _ivBytes) {
        throw FormatException('iv must be $_ivBytes bytes, got ${iv.length}');
      }
      final decrypted = await _backend.decrypt(parsed.ciphertext, _key, iv);
      final decoded = jsonDecode(decrypted);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('decrypted payload is not a JSON object');
      }
      return decoded;
    } on DataEncryptionError {
      rethrow;
    } catch (e, s) {
      throw DataEncryptionError('decrypt', e, s);
    }
  }

  Uint8List _freshIV() {
    final iv = Uint8List(_ivBytes);
    for (var i = 0; i < _ivBytes; i++) {
      iv[i] = _random.nextInt(256);
    }
    return iv;
  }

  static Uint8List _decodeHex(String hex) {
    if (hex.length.isOdd) {
      throw ArgumentError('hex string must have even length');
    }
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      final byte = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) {
        throw ArgumentError('invalid hex at offset ${i * 2}');
      }
      out[i] = byte;
    }
    return out;
  }

  /// Generates a hex-encoded 32-byte key suitable for AES-256.
  static String generateKey() =>
      DataIdGenerator.generate(DataByteType.x32).secretKey;
}

extension DataEncryptorHelper on DataEncryptor? {
  bool get isValid => this != null;

  Future<Map<String, dynamic>?> input(Map<String, dynamic> data) async {
    final self = this;
    return self?.input(data);
  }

  Future<Map<String, dynamic>?> output(Map<String, dynamic> data) async {
    final self = this;
    return self?.output(data);
  }
}
