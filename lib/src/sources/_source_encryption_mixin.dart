part of 'base.dart';

mixin _SourceEncryptionMixin<T extends Entity> {
  DataEncryptor? get _encryptor;

  bool get isEncryptor => _encryptor != null;

  Future<Map<String, dynamic>> _decryptDoc(Map<String, dynamic> doc) async {
    if (!isEncryptor) return doc;
    final out = await _encryptor!.output(doc);
    return out;
  }

  Future<Map<String, dynamic>?> _encryptDoc(Map<String, dynamic> data) async {
    if (!isEncryptor) return null;
    return _encryptor!.input(data);
  }
}
