part of 'base.dart';

mixin _ReadResolveMixin on _ReadMixin {
  static const _refPrefix = '@';
  static const _countPrefix = '#';
  static const _maxDepth = 8;

  DataOperationSemaphore get refSemaphore;

  Future<Map<String, dynamic>> _resolveRefs(
    Map<String, dynamic> data,
    Ignore? ignore,
    bool countable, {
    Set<String>? visited,
    int depth = 0,
  }) async {
    if (depth >= _maxDepth) return data;
    final guard = visited ?? <String>{};
    final result = Map<String, dynamic>.from(data);

    final tasks = <Future<void>>[];
    for (final entry in data.entries) {
      tasks.add(
        _resolveEntry(
          result,
          entry.key,
          entry.value,
          ignore,
          countable,
          guard,
          depth,
        ),
      );
    }
    await Future.wait(tasks, eagerError: false);
    return result;
  }

  Future<void> _resolveEntry(
    Map<String, dynamic> result,
    String key,
    dynamic value,
    Ignore? ignore,
    bool countable,
    Set<String> visited,
    int depth,
  ) async {
    if (value is DataFieldValueReader) {
      final fieldKey =
          (key.startsWith(_refPrefix) || key.startsWith(_countPrefix))
              ? key.substring(1)
              : key;
      await _resolveReader(
        result,
        key,
        fieldKey,
        value,
        ignore,
        countable,
        visited,
        depth,
      );
      return;
    }

    final ignored = ignore != null && ignore(key, value);
    if (ignored || value == null) return;

    if (key.startsWith(_refPrefix)) {
      final fieldKey = key.substring(1);
      if (fieldKey.isEmpty) return;
      await _resolveRefField(
        result,
        key,
        fieldKey,
        value,
        ignore,
        countable,
        visited,
        depth,
      );
      return;
    }

    if (key.startsWith(_countPrefix)) {
      final fieldKey = key.substring(1);
      if (fieldKey.isEmpty) return;
      await _resolveCountField(result, key, fieldKey, value);
    }
  }

  Future<void> _resolveReader(
    Map<String, dynamic> result,
    String originalKey,
    String fieldKey,
    DataFieldValueReader value,
    Ignore? ignore,
    bool countable,
    Set<String> visited,
    int depth,
  ) async {
    final path = value.path;
    switch (value.type) {
      case DataFieldValueReaderType.count:
        final raw = await _guardAsync<int?>(
          () => refSemaphore.run(() => count(path)),
          operation: 'resolve.count',
          path: path,
        );
        final c = raw ?? 0;
        if (c > 0) {
          result[fieldKey] = c;
          if (originalKey != fieldKey) result.remove(originalKey);
        }
        return;

      case DataFieldValueReaderType.get:
        if (!visited.add(path)) return;
        final raw = await _guardAsync<DataGetSnapshot>(
          () => refSemaphore.run(
            () => getById(
              path,
              countable: countable,
              resolveRefs: false,
              ignore: ignore,
            ),
          ),
          operation: 'resolve.get',
          path: path,
        );
        if (raw == null || !raw.exists) return;
        final doc = raw.doc;
        if (doc.isEmpty) return;
        final resolved = await _resolveRefs(
          doc,
          ignore,
          countable,
          visited: visited,
          depth: depth + 1,
        );
        result[fieldKey] = resolved;
        if (originalKey != fieldKey) result.remove(originalKey);
        return;

      case DataFieldValueReaderType.filter:
        if (!visited.add(path)) return;
        final options = value.options as DataFieldValueQueryOptions;
        final raw = await _guardAsync<DataGetsSnapshot>(
          () => refSemaphore.run(
            () => getByQuery(
              path,
              queries: options.queries,
              selections: options.selections,
              sorts: options.sorts,
              options: options.options,
              countable: countable,
              resolveRefs: false,
              ignore: ignore,
            ),
          ),
          operation: 'resolve.filter',
          path: path,
        );
        if (raw == null || !raw.exists) return;
        final docs = raw.docs;
        if (docs.isEmpty) return;
        final resolvedDocs = await Future.wait(
          docs.map(
            (d) => _resolveRefs(
              d,
              ignore,
              countable,
              visited: visited,
              depth: depth + 1,
            ),
          ),
          eagerError: false,
        );
        result[fieldKey] = resolvedDocs;
        if (originalKey != fieldKey) result.remove(originalKey);
        return;
    }
  }

  Future<void> _resolveRefField(
    Map<String, dynamic> result,
    String originalKey,
    String fieldKey,
    dynamic value,
    Ignore? ignore,
    bool countable,
    Set<String> visited,
    int depth,
  ) async {
    Future<Map<String, dynamic>?> fetchOne(String p) async {
      if (!visited.add(p)) return null;
      final raw = await _guardAsync<DataGetSnapshot>(
        () => refSemaphore.run(
          () => getById(
            p,
            countable: countable,
            resolveRefs: false,
            ignore: ignore,
          ),
        ),
        operation: 'resolve.@',
        path: p,
      );
      if (raw == null || !raw.exists) return null;
      final doc = raw.doc;
      if (doc.isEmpty) return null;
      return _resolveRefs(
        doc,
        ignore,
        countable,
        visited: visited,
        depth: depth + 1,
      );
    }

    if (value is String) {
      if (value.isEmpty) {
        result.remove(originalKey);
        return;
      }
      final snap = await fetchOne(value);
      result.remove(originalKey);
      if (snap != null) result[fieldKey] = snap;
    } else if (value is List) {
      final futures = <Future<Map<String, dynamic>?>>[];
      for (final v in value) {
        if (v is String && v.isNotEmpty) futures.add(fetchOne(v));
      }
      final snaps = await Future.wait(futures, eagerError: false);
      final out = <Map<String, dynamic>>[];
      for (final s in snaps) {
        if (s != null) out.add(s);
      }
      result[fieldKey] = out;
      result.remove(originalKey);
    } else if (value is Map) {
      final keys = <String>[];
      final futures = <Future<Map<String, dynamic>?>>[];
      for (final entry in value.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is String && v.isNotEmpty) {
          keys.add(k);
          futures.add(fetchOne(v));
        }
      }
      final snaps = await Future.wait(futures, eagerError: false);
      final out = <String, Map<String, dynamic>>{};
      for (var i = 0; i < keys.length; i++) {
        final s = snaps[i];
        if (s != null) out[keys[i]] = s;
      }
      result[fieldKey] = out;
      result.remove(originalKey);
    } else {
      result.remove(originalKey);
    }
  }

  Future<void> _resolveCountField(
    Map<String, dynamic> result,
    String originalKey,
    String fieldKey,
    dynamic value,
  ) async {
    Future<int?> fetchOne(String p) {
      return _guardAsync<int?>(
        () => refSemaphore.run(() => count(p)),
        operation: 'resolve.#',
        path: p,
      );
    }

    if (value is String) {
      if (value.isEmpty) {
        result.remove(originalKey);
        return;
      }
      final raw = await fetchOne(value);
      result.remove(originalKey);
      if (raw != null && raw > 0) result[fieldKey] = raw;
    } else if (value is List) {
      final futures = <Future<int?>>[];
      for (final v in value) {
        if (v is String && v.isNotEmpty) futures.add(fetchOne(v));
      }
      final results = await Future.wait(futures, eagerError: false);
      final out = <int>[];
      for (final r in results) {
        if (r != null && r >= 0) out.add(r);
      }
      result[fieldKey] = out;
      result.remove(originalKey);
    } else if (value is Map) {
      final keys = <String>[];
      final futures = <Future<int?>>[];
      for (final entry in value.entries) {
        final k = entry.key;
        final v = entry.value;
        if (k is String && v is String && v.isNotEmpty) {
          keys.add(k);
          futures.add(fetchOne(v));
        }
      }
      final results = await Future.wait(futures, eagerError: false);
      final out = <String, int>{};
      for (var i = 0; i < keys.length; i++) {
        final r = results[i];
        if (r != null && r >= 0) out[keys[i]] = r;
      }
      result[fieldKey] = out;
      result.remove(originalKey);
    } else {
      result.remove(originalKey);
    }
  }
}
