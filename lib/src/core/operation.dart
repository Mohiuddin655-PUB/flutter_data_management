import 'dart:async';

import '../core/checker.dart';
import '../core/configs.dart';
import 'encryptor.dart';

typedef Ignore = bool Function(String key, Object? value);

class DataGetSnapshot {
  final Map<String, dynamic> doc;
  final Object? snapshot;

  bool get exists => doc.isNotEmpty;

  const DataGetSnapshot({Map<String, dynamic>? doc, this.snapshot})
      : doc = doc ?? const {};

  DataGetSnapshot copyWith({Map<String, dynamic>? doc, Object? snapshot}) {
    return DataGetSnapshot(
      doc: doc ?? this.doc,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

class DataGetsSnapshot {
  final Iterable<Map<String, dynamic>> docs;
  final Iterable<Map<String, dynamic>> docChanges;
  final Object? snapshot;

  bool get exists => docs.isNotEmpty;

  const DataGetsSnapshot({
    this.docs = const [],
    this.docChanges = const [],
    this.snapshot,
  });

  DataGetsSnapshot copyWith({
    Iterable<Map<String, dynamic>>? docs,
    Iterable<Map<String, dynamic>>? docChanges,
    Object? snapshot,
  }) {
    return DataGetsSnapshot(
      docs: docs ?? this.docs,
      docChanges: docChanges ?? this.docChanges,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

abstract class DataWriteBatch {
  DataWriteBatch() {
    init();
  }

  void init();

  void delete(String path);

  void set(String path, Object data, [bool merge = true]);

  void update(String path, Map<String, dynamic> data);

  Future<void> commit();
}

abstract class DataBatchWriter {
  final String path;

  const DataBatchWriter(this.path);

  @override
  int get hashCode => path.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is DataBatchWriter && other.path == path;
  }

  @override
  String toString() => '$DataBatchWriter#$hashCode{path: $path}';
}

class DataSetWriter extends DataBatchWriter {
  final Object data;
  final DataSetOptions options;

  const DataSetWriter(
    super.path,
    this.data, [
    this.options = const DataSetOptions(),
  ]);

  @override
  int get hashCode => Object.hash(path, data, options);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! DataSetWriter) return false;
    if (other.path != path) return false;
    if (other.data != data) return false;
    if (other.options != options) return false;
    return true;
  }

  @override
  String toString() {
    return '$DataSetWriter#$hashCode{path: $path, data: $data, options: $options}';
  }
}

class DataUpdateWriter extends DataBatchWriter {
  final Map<String, dynamic> data;

  const DataUpdateWriter(super.path, this.data);

  @override
  int get hashCode => Object.hash(path, data);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! DataUpdateWriter) return false;
    if (other.path != path) return false;
    if (other.data != data) return false;
    return true;
  }

  @override
  String toString() {
    return '$DataUpdateWriter#$hashCode{path: $path, data: $data}';
  }
}

class DataDeleteWriter extends DataBatchWriter {
  const DataDeleteWriter(super.path);

  @override
  String toString() {
    return '$DataDeleteWriter#$hashCode{path: $path}';
  }
}

abstract class DataDelegate {
  const DataDelegate();

  DataWriteBatch batch();

  Object? updatingFieldValue(Object? value);

  Future<int?> count(String path);

  Future<void> create(
    String path,
    Map<String, dynamic> data, [
    bool merge = true,
  ]);

  Future<void> delete(String path);

  Future<DataGetsSnapshot> get(String path);

  Future<DataGetSnapshot> getById(String path);

  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  });

  Stream<DataGetsSnapshot> listen(String path);

  Stream<DataGetSnapshot> listenById(String path);

  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  });

  Future<DataGetsSnapshot> search(String path, Checker checker);

  Future<void> update(String path, Map<String, dynamic> data);
}

class DataOperation {
  final DataDelegate delegate;

  DataOperation(this.delegate);

  Map<String, dynamic> _w(DataWriteBatch batch, Map data, bool merge) {
    dynamic handle(dynamic value) {
      if (value is DataFieldValueWriter) {
        switch (value.type) {
          case DataFieldValueWriterType.set:
            final doc = value.value ?? {};
            if (doc.isEmpty) break;
            final options = value.options as DataSetOptions;
            batch.set(value.path, _w(batch, doc, merge), options.merge);
            return value.path;
          case DataFieldValueWriterType.update:
            final doc = value.value ?? {};
            if (doc.isEmpty) break;
            batch.update(value.path, _w(batch, doc, merge));
            return value.path;
          case DataFieldValueWriterType.delete:
            batch.delete(value.path);
            return null;
        }
      } else if (value is Map) {
        final path = value["path"];

        if (path is! String || path.isEmpty) {
          return _w(batch, value, merge);
        }

        final create = value["create"];
        if (create is Map && create.isNotEmpty) {
          batch.set(path, _w(batch, create, merge), merge);
          return path;
        }

        final update = value["update"];
        if (update is Map && update.isNotEmpty) {
          batch.update(path, _w(batch, update, merge));
          return path;
        }

        final delete = value["delete"];
        if (delete is bool && delete) {
          batch.delete(path);
          return null;
        }

        return _w(batch, value, merge);
      } else if (value is List && value.isNotEmpty) {
        return value.map(handle).where((e) => e != null).toList();
      }

      return value;
    }

    final entries = data.entries.map((e) {
      final k = e.key;
      if (k is! String || k.isEmpty) return null;
      final v = e.value is DataFieldValueWriter ||
              k.startsWith("@") ||
              k.startsWith("#")
          ? handle(e.value)
          : e.value;
      if (v == null) return null;
      return MapEntry(k, v);
    }).whereType<MapEntry<String, dynamic>>();

    return Map.fromEntries(entries);
  }

  Future<Map<String, dynamic>> _r(
    Map<String, dynamic> data,
    Ignore? ignore,
    bool countable,
  ) async {
    final result = Map<String, dynamic>.from(data);

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is DataFieldValueReader) {
        String fieldKey = key;
        if (fieldKey.startsWith("@") || fieldKey.startsWith("#")) {
          fieldKey = key.substring(1);
        }
        switch (value.type) {
          case DataFieldValueReaderType.count:
            final raw = await count(value.path);
            final snap = raw ?? 0;
            if (snap > 0) {
              result[fieldKey] = snap;
            }
            break;
          case DataFieldValueReaderType.get:
            final raw = await getById(
              value.path,
              countable: countable,
              resolveRefs: true,
              ignore: ignore,
            );
            final snap = raw.doc;
            if (snap.isNotEmpty) {
              result[fieldKey] = snap;
            }
            break;
          case DataFieldValueReaderType.filter:
            final options = value.options as DataFieldValueQueryOptions;
            final raw = await getByQuery(
              value.path,
              queries: options.queries,
              selections: options.selections,
              sorts: options.sorts,
              options: options.options,
              countable: countable,
              resolveRefs: true,
              ignore: ignore,
            );
            final snap = raw.docs;
            if (snap.isNotEmpty) {
              result[fieldKey] = snap.toList();
            }
            break;
        }
      } else if (key.startsWith('@') &&
          (ignore == null || !ignore(key, value)) &&
          value != null) {
        final fieldKey = key.substring(1);

        if (value is String && value.isNotEmpty) {
          final raw = await getById(
            value,
            countable: countable,
            resolveRefs: true,
            ignore: ignore,
          );
          final snap = raw.doc;
          if (snap.isNotEmpty) {
            result[fieldKey] = snap;
          }
        } else if (value is List) {
          final resolvedList = <Map<String, dynamic>>[];
          for (final v in value) {
            if (v is String && v.isNotEmpty) {
              final raw = await getById(
                v,
                countable: countable,
                resolveRefs: true,
                ignore: ignore,
              );
              final snap = raw.doc;
              if (snap.isNotEmpty) {
                resolvedList.add(snap);
              }
            }
          }
          result[fieldKey] = resolvedList;
        } else if (value is Map) {
          final resolvedMap = <String, Map<String, dynamic>>{};
          for (final entry in value.entries) {
            final k = entry.key;
            final v = entry.value;
            if (v is String && v.isNotEmpty) {
              final raw = await getById(
                v,
                countable: countable,
                resolveRefs: true,
                ignore: ignore,
              );
              final snap = raw.doc;
              if (snap.isNotEmpty) {
                resolvedMap[k] = snap;
              }
            }
          }
          result[fieldKey] = resolvedMap;
        }
      } else if (key.startsWith('#') &&
          (ignore == null || !ignore(key, value)) &&
          value != null) {
        final fieldKey = key.substring(1);

        if (value is String && value.isNotEmpty) {
          final raw = await count(value);
          if (raw != null && raw > 0) {
            result[fieldKey] = raw;
          }
        } else if (value is List) {
          final resolvedList = <int>[];
          for (final v in value) {
            if (v is String && v.isNotEmpty) {
              final raw = await count(v);
              if (raw != null && raw >= 0) {
                resolvedList.add(raw);
              }
            }
          }
          result[fieldKey] = resolvedList;
        } else if (value is Map) {
          final resolvedMap = <String, int>{};
          for (final entry in value.entries) {
            final k = entry.key;
            final v = entry.value;
            if (v is String && v.isNotEmpty) {
              final raw = await count(v);
              if (raw != null && raw >= 0) {
                resolvedMap[k] = raw;
              }
            }
          }
          result[fieldKey] = resolvedMap;
        }
      }
    }

    return result;
  }

  Future<int?> count(String path) => delegate.count(path);

  Future<void> create(
    String path,
    Map<String, dynamic> data, {
    bool merge = true,
    bool createRefs = false,
  }) async {
    if (!createRefs) return delegate.create(path, data, merge);

    final b = delegate.batch();
    final w = _w(b, data, merge);
    b.set(path, w, merge);
    await b.commit();
  }

  Future<void> delete(
    String path, {
    bool counter = false,
    bool deleteRefs = false,
    Ignore? ignore,
    int batchLimit = 500,
    int? batchMaxLimit,
  }) async {
    if (!deleteRefs) return delegate.delete(path);

    final List<String> toDelete = [];

    Future<void> deepCollect(String docPath) async {
      if (batchMaxLimit != null && batchMaxLimit <= toDelete.length) return;

      final snap = await getById(
        docPath,
        countable: false,
        resolveRefs: true,
        ignore: ignore,
      );

      if (!snap.exists) return;

      Future<void> handleRef(dynamic value) async {
        if (value == null) return;

        if (value is String && value.isNotEmpty) {
          await deepCollect(value);
        } else if (value is List) {
          for (final v in value) {
            await handleRef(v);
          }
        } else if (value is Map) {
          for (final v in value.values) {
            await handleRef(v);
          }
        }
      }

      Future<void> handleCountable(dynamic value) async {
        if (batchMaxLimit != null && batchMaxLimit <= toDelete.length) return;
        if (value == null) return;
        if (value is String && value.isNotEmpty) {
          final children = await getByQuery(
            value,
            countable: false,
            resolveRefs: true,
            ignore: ignore,
          );
          if (!children.exists || children.docs.isEmpty) return;
          for (final child in children.docs) {
            for (final entry in child.entries) {
              final key = entry.key;
              final value = entry.value;
              if (key.startsWith('@')) {
                await handleRef(value);
              } else if (counter && key.startsWith('#')) {
                await handleCountable(value);
              }
            }
            final id = child['id'];
            if (id is String && id.isNotEmpty) {
              final childPath = "$value/$id";
              toDelete.add(childPath);
            }
          }
        } else if (value is List) {
          for (final v in value) {
            await handleCountable(v);
          }
        } else if (value is Map) {
          for (final v in value.values) {
            await handleCountable(v);
          }
        }
      }

      for (final entry in snap.doc.entries) {
        final key = entry.key;
        final value = entry.value;
        if (key.startsWith('@')) {
          await handleRef(value);
        } else if (counter && key.startsWith('#')) {
          await handleCountable(value);
        }
      }

      toDelete.add(docPath);
    }

    await deepCollect(path);

    final cappedList = batchMaxLimit != null
        ? toDelete.take(batchMaxLimit).toList()
        : toDelete;

    for (int i = 0; i < cappedList.length; i += batchLimit) {
      final batch = delegate.batch();
      final end = (i + batchLimit > cappedList.length)
          ? cappedList.length
          : i + batchLimit;

      for (final docPath in cappedList.sublist(i, end)) {
        batch.delete(docPath);
      }

      await batch.commit();
    }
  }

  Future<DataGetsSnapshot> get(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) async {
    final data = await delegate.get(path);
    if (!data.exists) return DataGetsSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(
      docs: await Future.wait(data.docs.map((e) => _r(e, ignore, countable))),
      docChanges: resolveDocChangesRefs
          ? await Future.wait(
              data.docChanges.map((e) => _r(e, ignore, countable)))
          : data.docChanges,
    );
  }

  Future<DataGetSnapshot> getById(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    Ignore? ignore,
  }) async {
    final data = await delegate.getById(path);
    if (!data.exists) return DataGetSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(
      doc: await _r(data.doc, ignore, countable),
    );
  }

  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) async {
    final data = await delegate.getByQuery(
      path,
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    );
    if (!data.exists) return DataGetsSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(
      docs: await Future.wait(data.docs.map((e) => _r(e, ignore, countable))),
      docChanges: resolveDocChangesRefs
          ? await Future.wait(
              data.docChanges.map((e) => _r(e, ignore, countable)))
          : data.docChanges,
    );
  }

  Stream<DataGetsSnapshot> listen(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) {
    return delegate.listen(path).asyncMap((data) async {
      if (!data.exists) return DataGetsSnapshot();
      if (!resolveRefs) return data;

      return data.copyWith(
        docs: await Future.wait(data.docs.map((e) => _r(e, ignore, countable))),
        docChanges: resolveDocChangesRefs
            ? await Future.wait(
                data.docChanges.map((e) => _r(e, ignore, countable)))
            : data.docChanges,
      );
    });
  }

  Stream<DataGetSnapshot> listenById(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    Ignore? ignore,
  }) {
    return delegate.listenById(path).asyncMap((data) async {
      if (!data.exists) return DataGetSnapshot();
      if (!resolveRefs) return data;

      return data.copyWith(
        doc: await _r(data.doc, ignore, countable),
      );
    });
  }

  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) {
    return delegate
        .listenByQuery(
      path,
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    )
        .asyncMap((data) async {
      if (!data.exists) return DataGetsSnapshot();
      if (!resolveRefs) return data;

      return data.copyWith(
        docs: await Future.wait(data.docs.map((e) => _r(e, ignore, countable))),
        docChanges: resolveDocChangesRefs
            ? await Future.wait(
                data.docChanges.map((e) => _r(e, ignore, countable)))
            : data.docChanges,
      );
    });
  }

  Future<DataGetsSnapshot> search(
    String path,
    Checker checker, {
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) async {
    final data = await delegate.search(path, checker);
    if (!data.exists) return DataGetsSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(
      docs: await Future.wait(data.docs.map((e) => _r(e, ignore, countable))),
      docChanges: resolveDocChangesRefs
          ? await Future.wait(
              data.docChanges.map((e) => _r(e, ignore, countable)))
          : data.docChanges,
    );
  }

  Future<void> update(
    String path,
    Map<String, dynamic> data, {
    bool updateRefs = false,
  }) async {
    if (!updateRefs) return delegate.update(path, data);

    final batch = delegate.batch();
    final processedData = _w(batch, data, true);
    batch.update(path, processedData);
    await batch.commit();
  }

  Future<void> write(
    List<DataBatchWriter> writers,
    DataEncryptor? encryptor,
  ) async {
    final batch = delegate.batch();
    for (var w in writers) {
      if (w is DataSetWriter) {
        final raw = encryptor != null ? await encryptor.input(w.data) : null;
        batch.set(w.path, raw ?? w.data, w.options.merge);
      } else if (w is DataUpdateWriter) {
        final raw = encryptor != null ? await encryptor.input(w.data) : null;
        batch.update(w.path, raw ?? w.data);
      } else if (w is DataDeleteWriter) {
        batch.delete(w.path);
      }
    }
    return batch.commit();
  }
}
