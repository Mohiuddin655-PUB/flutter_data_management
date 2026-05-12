import 'dart:typed_data' show Uint8List;

abstract class AesBackend {
  /// Encrypts [plainText] using AES-256-CBC with PKCS7 padding.
  /// [key] must be 32 bytes. [iv] must be 16 bytes.
  /// Returns base64-encoded ciphertext.
  Future<String> encrypt(String plainText, Uint8List key, Uint8List iv);

  /// Decrypts [cipherBase64] using AES-256-CBC with PKCS7 padding.
  /// [key] must be 32 bytes. [iv] must be 16 bytes.
  Future<String> decrypt(String cipherBase64, Uint8List key, Uint8List iv);
}

AesBackend createBackend() {
  throw UnsupportedError('No AesBackend implementation found');
}
