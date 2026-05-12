part of 'base.dart';

mixin _SourceReadBaseMixin<T extends Entity>
    on _SourceExecuteMixin<T>, _SourceEncryptionMixin<T>, _SourcePathMixin<T> {
  DataDelegate get delegate;

  DataOperation get operation;

  DataLimitations get limitations;

  T build(dynamic source);

  Future<List<T>> _buildAll(Iterable<Map<String, dynamic>> docs) async {
    final out = <T>[];
    for (final i in docs) {
      if (i.isEmpty) continue;
      final v = await _decryptDoc(i);
      out.add(build(v));
    }
    return out;
  }
}
