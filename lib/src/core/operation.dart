import 'dart:async';

import '../core/checker.dart';
import '../core/configs.dart';

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
    DataPagingOptions options = const DataPagingOptions(),
  });

  Stream<DataGetsSnapshot> listen(String path);

  Stream<DataGetSnapshot> listenById(String path);

  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
  });

  Future<DataGetsSnapshot> search(String path, Checker checker);

  Future<void> update(String path, Map<String, dynamic> data);
}

class DataOperation {
  final DataDelegate delegate;

  DataOperation(this.delegate);

  Map<String, dynamic> _setOrUpdate(
    DataWriteBatch batch,
    Map data, [
    bool merge = true,
  ]) {
    void createBatch(String ref, Map value) {
      final x = value.map((k, v) => MapEntry(k.toString(), v));
      batch.set(ref, x, merge);
    }

    void updateBatch(String ref, Map value) {
      final x = value.map((k, v) => MapEntry(k.toString(), v));
      batch.update(ref, x);
    }

    void deleteBatch(String ref) {
      batch.delete(ref);
    }

    void ops(String ref, Object? c, Object? u, Object? d) {
      if (c is Map && c.isNotEmpty) {
        createBatch(ref, c);
      }
      if (u is Map && u.isNotEmpty) {
        updateBatch(ref, u);
      }
      if (d == true) {
        deleteBatch(ref);
      }
    }

    dynamic handle(dynamic value) {
      // If it's a DataFieldWriteRef or wrapped value
      if (value is DataFieldWriteRef && value.isNotEmpty) {
        ops(value.path, value.create, value.update, value.delete);
        return value.path;
      }
      if (value is DataFieldValue && value.value is DataFieldWriteRef) {
        final ref = value.value as DataFieldWriteRef;
        ops(ref.path, ref.create, ref.update, ref.delete);
        return ref.path;
      }

      // If it's a JSON-like ref object
      if (value is Map<String, dynamic>) {
        final path = value["path"];
        final create = value["create"];
        final update = value["update"];
        final delete = value["delete"];

        if (path != null &&
            (create != null || update != null || delete != null)) {
          // If this object itself is a batch target
          final c = create is Map
              ? _setOrUpdate(batch, create, merge)
              : (create ?? const {});
          final u = update is Map
              ? _setOrUpdate(batch, update, merge)
              : (update ?? const {});
          final d = delete is Map
              ? _setOrUpdate(batch, delete, merge)
              : (delete ?? false);
          ops(path, c, u, d);
          return path;
        }

        // Otherwise, go deeper recursively
        final nested = {};
        value.forEach((k, v) {
          nested[k] = handle(v);
        });
        return nested;
      }

      // Handle lists of refs or objects
      if (value is List) {
        return value.map(handle).toList();
      }

      // Primitive or unhandled types remain as-is
      return value;
    }

    return data.map((k, v) => MapEntry(k, k.startsWith("@") ? handle(v) : v));
  }

  Future<Map<String, dynamic>> _resolveRefs(Map<String, dynamic> data) async {
    final result = Map<String, dynamic>.from(data);

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key.startsWith('@') && value != null) {
        final fieldKey = key.substring(1);

        if (value is String && value.isNotEmpty) {
          final raw = await getById(value, resolveRefs: true);
          final snap = raw.doc;
          if (snap.isNotEmpty) {
            result[fieldKey] = snap;
          }
        } else if (value is List) {
          final resolvedList = <Map<String, dynamic>>[];
          for (final v in value) {
            if (v is String && v.isNotEmpty) {
              final raw = await getById(v, resolveRefs: true);
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
              final raw = await getById(v, resolveRefs: true);
              final snap = raw.doc;
              if (snap.isNotEmpty) {
                resolvedMap[k] = snap;
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

    final batch = delegate.batch();
    final processedData = _setOrUpdate(batch, data, merge);
    batch.set(path, processedData, merge);
    await batch.commit();
  }

  Future<void> delete(String path, {bool deleteRefs = false}) async {
    if (!deleteRefs) return delegate.delete(path);

    final data = await delegate.getById(path);
    if (!data.exists) return;

    final batch = delegate.batch();

    for (final entry in data.doc.entries) {
      final key = entry.key;
      final value = entry.value;

      if (key.startsWith('@') && value != null) {
        if (value is String && value.isNotEmpty) {
          batch.delete(value);
        } else if (value is List) {
          for (final v in value) {
            if (v is String && v.isNotEmpty) {
              batch.delete(v);
            }
          }
        } else if (value is Map) {
          for (final v in value.values) {
            if (v is String && v.isNotEmpty) {
              batch.delete(v);
            }
          }
        }
      }
    }

    batch.delete(path);
    await batch.commit();
  }

  Future<DataGetsSnapshot> get(
    String path, {
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
  }) async {
    final data = await delegate.get(path);
    if (!data.exists) return DataGetsSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(
      docs: await Future.wait(data.docs.map(_resolveRefs)),
      docChanges: resolveDocChangesRefs
          ? await Future.wait(data.docChanges.map(_resolveRefs))
          : data.docChanges,
    );
  }

  Future<DataGetSnapshot> getById(
    String path, {
    bool resolveRefs = false,
  }) async {
    final data = await delegate.getById(path);
    if (!data.exists) return DataGetSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(doc: await _resolveRefs(data.doc));
  }

  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
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
      docs: await Future.wait(data.docs.map(_resolveRefs)),
      docChanges: resolveDocChangesRefs
          ? await Future.wait(data.docChanges.map(_resolveRefs))
          : data.docChanges,
    );
  }

  Stream<DataGetsSnapshot> listen(
    String path, {
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
  }) {
    return delegate.listen(path).asyncMap((data) async {
      if (!data.exists) return DataGetsSnapshot();
      if (!resolveRefs) return data;

      return data.copyWith(
        docs: await Future.wait(data.docs.map(_resolveRefs)),
        docChanges: resolveDocChangesRefs
            ? await Future.wait(data.docChanges.map(_resolveRefs))
            : data.docChanges,
      );
    });
  }

  Stream<DataGetSnapshot> listenById(String path, {bool resolveRefs = false}) {
    return delegate.listenById(path).asyncMap((data) async {
      if (!data.exists) return DataGetSnapshot();
      if (!resolveRefs) return data;

      return data.copyWith(doc: await _resolveRefs(data.doc));
    });
  }

  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
  }) {
    return delegate.listenByQuery(path).asyncMap((data) async {
      if (!data.exists) return DataGetsSnapshot();
      if (!resolveRefs) return data;

      return data.copyWith(
        docs: await Future.wait(data.docs.map(_resolveRefs)),
        docChanges: resolveDocChangesRefs
            ? await Future.wait(data.docChanges.map(_resolveRefs))
            : data.docChanges,
      );
    });
  }

  Future<DataGetsSnapshot> search(
    String path,
    Checker checker, {
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
  }) async {
    final data = await delegate.search(path, checker);
    if (!data.exists) return DataGetsSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(
      docs: await Future.wait(data.docs.map(_resolveRefs)),
      docChanges: resolveDocChangesRefs
          ? await Future.wait(data.docChanges.map(_resolveRefs))
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
    final processedData = _setOrUpdate(batch, data, true);
    batch.update(path, processedData);
    await batch.commit();
  }
}
