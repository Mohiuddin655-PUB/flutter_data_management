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
    Map<String, dynamic> data, [
    bool merge = true,
  ]) {
    final result = <String, dynamic>{};

    void createBatch(String ref, Object? value) {
      if (value is! Map || value.isEmpty) return;
      final x = value.map((k, v) => MapEntry(k.toString(), v));
      batch.set(ref, x, merge);
    }

    void updateBatch(String ref, Object? value) {
      if (value is! Map || value.isEmpty) return;
      final x = value.map((k, v) => MapEntry(k.toString(), v));
      batch.update(ref, x);
    }

    void deleteBatch(Object? value) {
      if (value is! String || value.isEmpty) return;
      batch.delete(value);
    }

    void ops(String ref, Object? creates, Object? updates, Object? deletes) {
      if (creates is Map) {
        createBatch(ref, creates);
      } else if (creates is List) {
        for (final c in creates) {
          createBatch(ref, c);
        }
      }
      if (updates is Map) {
        updateBatch(ref, updates);
      } else if (updates is List) {
        for (final u in updates) {
          updateBatch(ref, u);
        }
      }
      if (deletes is String) {
        deleteBatch(deletes);
      } else if (deletes is List) {
        for (final d in deletes) {
          deleteBatch(d);
        }
      }
    }

    data.forEach((k, v) {
      if (k.startsWith('@')) {
        dynamic handleSingle(dynamic value) {
          if (value is Map && value["path"] != null) {
            final ref = value["path"];
            final create = value["create"] ?? value['creates'];
            final update = value["update"] ?? value['updates'];
            final deletes = value["delete"] ?? value['deletes'];
            ops(ref, create, update, deletes);
            return ref;
          } else if (value is DataFieldValue &&
              value.value is DataFieldWriteRef) {
            final dataRef = value.value as DataFieldWriteRef;
            ops(dataRef.path, dataRef.create, dataRef.update, dataRef.delete);
            return dataRef.path;
          } else if (value is DataFieldWriteRef && value.isNotEmpty) {
            ops(value.path, value.create, value.update, value.delete);
            return value.path;
          }
          return value;
        }

        if (v is List) {
          result[k] = v.map(handleSingle).toList();
        } else if (v is Map &&
            v.values.every((e) =>
                e is Map || e is DataFieldWriteRef || e is DataFieldValue)) {
          final mapResult = <String, dynamic>{};
          v.forEach((mk, mv) {
            mapResult[mk] = handleSingle(mv);
          });
          result[k] = mapResult;
        } else {
          result[k] = handleSingle(v);
        }
      } else {
        result[k] = v;
      }
    });

    return result;
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
