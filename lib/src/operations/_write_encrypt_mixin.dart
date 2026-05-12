part of 'base.dart';

mixin _WriteEncryptMixin on _ErrorHandlingMixin {
  Future<List<Map<String, dynamic>?>> _encryptAll(
    List<DataBatchWriter> writers,
    DataEncryptor? encryptor, {
    required bool parallel,
  }) async {
    if (encryptor == null) {
      return List<Map<String, dynamic>?>.filled(writers.length, null);
    }

    Future<Map<String, dynamic>?> encryptOne(DataBatchWriter w) {
      if (w is DataSetWriter) return encryptor.input(w.data);
      if (w is DataUpdateWriter) return encryptor.input(w.data);
      return Future<Map<String, dynamic>?>.value(null);
    }

    if (parallel) {
      return Future.wait<Map<String, dynamic>?>(
        writers.map(encryptOne),
        eagerError: false,
      );
    }

    final out = <Map<String, dynamic>?>[];
    for (final w in writers) {
      out.add(await encryptOne(w));
    }
    return out;
  }
}
