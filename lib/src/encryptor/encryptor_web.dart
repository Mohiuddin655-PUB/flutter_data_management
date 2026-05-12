import 'dart:convert' show utf8, base64Encode, base64Decode;
import 'dart:js_interop'
    show
        JSObject,
        ByteBufferToJSArrayBuffer,
        JSArrayBuffer,
        NullableObjectUtilExtension,
        StringToJSString,
        ListToJSArray,
        JSPromiseToFuture,
        JSArrayBufferToByteBuffer;
import 'dart:typed_data' show Uint8List;

import 'package:web/web.dart' as web;

import 'encryptor_stub.dart' show AesBackend;

export 'encryptor_stub.dart' show AesBackend;

class _WebAesBackend implements AesBackend {
  const _WebAesBackend();

  Future<web.CryptoKey> _importKey(Uint8List key) async {
    return await web.window.crypto.subtle
        .importKey(
          'raw',
          key.buffer.toJS,
          {'name': 'AES-CBC'}.jsify() as JSObject,
          false,
          ['encrypt', 'decrypt'].map((e) => e.toJS).toList().toJS,
        )
        .toDart;
  }

  JSObject _aesCbc(Uint8List iv) =>
      {'name': 'AES-CBC', 'iv': iv.buffer.toJS}.jsify() as JSObject;

  @override
  Future<String> encrypt(String plainText, Uint8List key, Uint8List iv) async {
    final cryptoKey = await _importKey(key);
    final dataBytes = Uint8List.fromList(utf8.encode(plainText));
    final encrypted = await web.window.crypto.subtle
        .encrypt(_aesCbc(iv), cryptoKey, dataBytes.buffer.toJS)
        .toDart;
    return base64Encode((encrypted as JSArrayBuffer).toDart.asUint8List());
  }

  @override
  Future<String> decrypt(
    String cipherBase64,
    Uint8List key,
    Uint8List iv,
  ) async {
    final cryptoKey = await _importKey(key);
    final cipherBytes = base64Decode(cipherBase64);
    final decrypted = await web.window.crypto.subtle
        .decrypt(_aesCbc(iv), cryptoKey, cipherBytes.buffer.toJS)
        .toDart;
    return utf8.decode((decrypted as JSArrayBuffer).toDart.asUint8List());
  }
}

AesBackend createBackend() => const _WebAesBackend();
