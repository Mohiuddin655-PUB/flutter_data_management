part of 'base.dart';

mixin _WriteTransformMixin {
  static const _refPrefix = '@';
  static const _countPrefix = '#';

  static bool _isPrefixedKey(String k) =>
      k.isNotEmpty && (k.startsWith(_refPrefix) || k.startsWith(_countPrefix));

  Map<String, dynamic> _transformWrite(
    DataWriteBatch batch,
    Map data,
    bool merge,
  ) {
    final out = <String, dynamic>{};
    for (final entry in data.entries) {
      final k = entry.key;
      if (k is! String || k.isEmpty) continue;
      final v = entry.value;
      final processed = _handle(batch, v, merge);
      if (processed == null && _isPrefixedKey(k) == false && v == null) {
        continue;
      }
      if (processed == null) continue;
      out[k] = processed;
    }
    return out;
  }

  dynamic _handle(DataWriteBatch batch, dynamic value, bool merge) {
    if (value is DataFieldValueWriter) {
      return _handleFieldValueWriter(batch, value, merge);
    }
    if (value is Map) {
      return _handleMap(batch, value, merge);
    }
    if (value is List) {
      if (value.isEmpty) return value;
      final mapped = <dynamic>[];
      for (final e in value) {
        final r = _handle(batch, e, merge);
        if (r != null) mapped.add(r);
      }
      return mapped;
    }
    return value;
  }

  dynamic _handleFieldValueWriter(
    DataWriteBatch batch,
    DataFieldValueWriter value,
    bool merge,
  ) {
    switch (value.type) {
      case DataFieldValueWriterType.set:
        final doc = value.value;
        if (doc == null || doc.isEmpty) return null;
        final options = value.options is DataSetOptions
            ? value.options as DataSetOptions
            : const DataSetOptions();
        batch.onSet(
          value.path,
          _transformWrite(batch, doc, merge),
          merge: options.merge,
        );
        return value.path;
      case DataFieldValueWriterType.update:
        final doc = value.value;
        if (doc == null || doc.isEmpty) return null;
        batch.onUpdate(value.path, _transformWrite(batch, doc, merge));
        return value.path;
      case DataFieldValueWriterType.delete:
        batch.onDelete(value.path);
        return null;
    }
  }

  dynamic _handleMap(DataWriteBatch batch, Map value, bool merge) {
    final path = value['path'];
    if (path is! String || path.isEmpty) {
      return _transformWrite(batch, value, merge);
    }
    final create = value['create'];
    if (create is Map && create.isNotEmpty) {
      batch.onSet(path, _transformWrite(batch, create, merge), merge: merge);
      return path;
    }
    final update = value['update'];
    if (update is Map && update.isNotEmpty) {
      batch.onUpdate(path, _transformWrite(batch, update, merge));
      return path;
    }
    final delete = value['delete'];
    if (delete is bool && delete) {
      batch.onDelete(path);
      return null;
    }
    return _transformWrite(batch, value, merge);
  }
}
