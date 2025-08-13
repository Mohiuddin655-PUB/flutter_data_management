import 'dart:convert';

import 'package:encrypt/encrypt.dart' as crypto;
import 'package:flutter/foundation.dart';

import 'configs.dart';

/// Signature for a function that builds an encryptor request.
typedef EncryptorRequestBuilder = Map<String, dynamic> Function(
  String request,
  String passcode,
);

/// Signature for a function that builds an encryptor response.
typedef EncryptorResponseBuilder = dynamic Function(Map<String, dynamic> data);

/// Utility class for encryption and decryption operations.
class DataEncryptor {
  /// Encryption key.
  final String key;

  /// Initialization vector (IV) for encryption.
  final String iv;

  /// Passcode for encryption and decryption.
  final String passcode;

  /// Builder for encryptor requests.
  final EncryptorRequestBuilder? _request;

  /// Builder for encryptor responses.
  final EncryptorResponseBuilder? _response;

  /// Gets the response builder or defaults to extracting "data" from the response.
  EncryptorResponseBuilder get response => _response ?? (a) => a["data"];

  /// Gets the request builder or defaults to wrapping the data in a "data" key.
  EncryptorRequestBuilder get request => _request ?? (a, b) => {"data": a};

  /// Creates an instance of Encryptor with optional request and response builders.
  ///
  /// Example:
  ///
  /// ```dart
  /// Encryptor encryptor = Encryptor(request: myRequestBuilder, response: myResponseBuilder);
  /// ```
  const DataEncryptor({
    this.key = "A79842D8A13A10A6DD27759BD700E292",
    this.iv = "9777298A5D7A8AFA",
    this.passcode = "passcode",
    EncryptorRequestBuilder? request,
    EncryptorResponseBuilder? response,
  })  : _request = request,
        _response = response;

  /// Gets the encryption key as a cryptographic key.
  crypto.Key get _key => crypto.Key.fromUtf8(key);

  /// Gets the initialization vector (IV) as a cryptographic IV.
  crypto.IV get _iv => crypto.IV.fromUtf8(iv);

  /// Gets the encrypter instance using AES encryption with CBC mode.
  crypto.Encrypter get _en {
    return crypto.Encrypter(
      crypto.AES(_key, mode: crypto.AESMode.cbc),
    );
  }

  /// Encrypts the input data and returns the encrypted result as a Map.
  Future<Map<String, dynamic>> input(dynamic data) => compute(_encoder, data);

  /// Decrypts the input data and returns the decrypted result as a Map.
  Future<Map<String, dynamic>> output(dynamic data) => compute(_decoder, data);

  /// Encoder function for encrypting data.
  Future<Map<String, dynamic>> _encoder(dynamic data) async {
    try {
      if (data is Map<String, dynamic>) {
        final encrypted = _en.encrypt(jsonEncode(data), iv: _iv);
        return request.call(encrypted.base64, passcode);
      } else {
        return {};
      }
    } catch (_) {
      return {};
    }
  }

  /// Decoder function for decrypting data.
  Future<Map<String, dynamic>> _decoder(dynamic source) async {
    try {
      if (source is Map<String, dynamic>) {
        final value = await response.call(source);
        if (value != null) {
          final encrypted = crypto.Encrypted.fromBase64(value);
          final data = _en.decrypt(encrypted, iv: _iv);
          return jsonDecode(data);
        } else {
          return {};
        }
      } else {
        return {};
      }
    } catch (_) {
      return {};
    }
  }

  /// Generates a random encryption key based on the specified byte type.
  ///
  /// Example:
  ///
  /// ```dart
  /// String generatedKey = Encryptor.generateKey(ByteType.x16);
  /// ```
  static String generateKey([DataByteType type = DataByteType.x16]) {
    return DataIdGenerator.generate(type).secretKey;
  }

  /// Generates a random initialization vector (IV) based on the specified byte type.
  ///
  /// Example:
  ///
  /// ```dart
  /// String generatedIV = Encryptor.generateIV(ByteType.x8);
  /// ```
  static String generateIV([DataByteType type = DataByteType.x8]) {
    return DataIdGenerator.generate(type).secretIV;
  }
}

extension DataEncryptorHelper on DataEncryptor? {
  bool get isValid => this != null;

  DataEncryptor get use => this ?? const DataEncryptor();

  Future<Map<String, dynamic>> input(dynamic data) async {
    return isValid ? await use.input(data) : {};
  }

  Future<Map<String, dynamic>> output(dynamic data) async {
    return isValid ? await use.output(data) : {};
  }
}
