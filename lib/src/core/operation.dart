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

  Future<int?> count(String path) => delegate.count(path);

  Future<void> create(
    String path,
    Map<String, dynamic> data, {
    bool merge = true,
    bool createRefs = false,
  }) async {
    if (!createRefs) return delegate.create(path, data, merge);

    final batch = delegate.batch();
    final processedData = _process(batch, data, merge);
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
      if (key.startsWith('@') && value is String && value.isNotEmpty) {
        batch.delete(value);
      }
    }
    batch.delete(path);
    await batch.commit();
  }

  Future<DataGetsSnapshot> get(
    String path, {
    bool resolveRefs = false,
  }) async {
    final data = await delegate.get(path);
    if (!data.exists) return DataGetsSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(
      docs: await Future.wait(data.docs.map(_resolveRefs)),
      docChanges: await Future.wait(data.docChanges.map(_resolveRefs)),
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
      docChanges: await Future.wait(data.docChanges.map(_resolveRefs)),
    );
  }

  Stream<DataGetsSnapshot> listen(String path, {bool resolveRefs = false}) {
    return delegate.listen(path).asyncMap((data) async {
      if (!data.exists) return DataGetsSnapshot();
      if (!resolveRefs) return data;

      return data.copyWith(
        docs: await Future.wait(data.docs.map(_resolveRefs)),
        docChanges: await Future.wait(data.docChanges.map(_resolveRefs)),
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
  }) {
    return delegate.listenByQuery(path).asyncMap((data) async {
      if (!data.exists) return DataGetsSnapshot();
      if (!resolveRefs) return data;

      return data.copyWith(
        docs: await Future.wait(data.docs.map(_resolveRefs)),
        docChanges: await Future.wait(data.docChanges.map(_resolveRefs)),
      );
    });
  }

  Future<DataGetsSnapshot> search(
    String path,
    Checker checker, {
    bool resolveRefs = false,
  }) async {
    final data = await delegate.search(path, checker);
    if (!data.exists) return DataGetsSnapshot();
    if (!resolveRefs) return data;

    return data.copyWith(
      docs: await Future.wait(data.docs.map(_resolveRefs)),
      docChanges: await Future.wait(data.docChanges.map(_resolveRefs)),
    );
  }

  Future<void> update(
    String path,
    Map<String, dynamic> data, {
    bool updateRefs = false,
  }) async {
    if (!updateRefs) return delegate.update(path, data);

    final batch = delegate.batch();
    final processedData = _process(batch, data, true);
    batch.update(path, processedData);
    await batch.commit();
  }

  Map<String, dynamic> _process(
    DataWriteBatch batch,
    Map<String, dynamic> data, [
    bool merge = true,
  ]) {
    final result = <String, dynamic>{};
    void ops(String ref, Map<String, dynamic> c, Map<String, dynamic> u) {
      if (c.isNotEmpty) {
        batch.set(ref, Map<String, dynamic>.from(c), merge);
      } else if (u.isNotEmpty) {
        batch.update(ref, Map<String, dynamic>.from(u));
      }
    }

    data.forEach((k, v) {
      if (k.startsWith('@')) {
        if (v is Map && v["path"] != null) {
          final ref = v["path"];
          final create = v["create"];
          final update = v["update"];
          ops(ref, create, update);
          result[k] = ref;
        } else if (v is DataFieldValue && v.value is DataFieldWriteRef) {
          final data = v.value as DataFieldWriteRef;
          final ref = data.path;
          ops(ref, data.create, data.update);
          result[k] = ref;
        } else if (v is DataFieldWriteRef && v.isNotEmpty) {
          final ref = v.path;
          ops(ref, v.create, v.update);
          result[k] = ref;
        } else {
          result[k] = v;
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
      if (key.startsWith('@') && value is String && value.isNotEmpty) {
        final raw = await delegate.getById(value);
        final snap = raw.doc;
        if (snap.isNotEmpty) {
          result[key.toString().substring(1)] = snap;
        }
      }
    }
    return result;
  }
}
