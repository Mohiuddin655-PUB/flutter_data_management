import 'dart:typed_data' show Uint8List;

import 'package:encrypt/encrypt.dart' as crypto
    show Encrypter, AESMode, Key, AES, IV, Encrypted;

import 'encryptor_stub.dart' show AesBackend;

export 'encryptor_stub.dart' show AesBackend;

class _IoAesBackend implements AesBackend {
  const _IoAesBackend();

  crypto.Encrypter _encrypter(Uint8List key) {
    return crypto.Encrypter(
      crypto.AES(crypto.Key(key), mode: crypto.AESMode.cbc),
    );
  }

  @override
  Future<String> encrypt(String plainText, Uint8List key, Uint8List iv) async {
    final encrypted = _encrypter(key).encrypt(plainText, iv: crypto.IV(iv));
    return encrypted.base64;
  }

  @override
  Future<String> decrypt(
    String cipherBase64,
    Uint8List key,
    Uint8List iv,
  ) async {
    return _encrypter(
      key,
    ).decrypt(crypto.Encrypted.fromBase64(cipherBase64), iv: crypto.IV(iv));
  }
}

AesBackend createBackend() => const _IoAesBackend();
