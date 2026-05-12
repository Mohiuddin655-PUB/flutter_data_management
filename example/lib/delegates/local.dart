import 'package:data_management/data_management.dart'
    show
        DataWriteBatch,
        DataDelegate,
        DataGetsSnapshot,
        DataGetSnapshot,
        DataQuery,
        DataSelection,
        DataSorting,
        DataFetchOptions,
        DataAggregateSnapshot,
        Checker,
        DataFieldPath,
        DataFieldValue,
        DataFieldPaths,
        DataFieldValues;
import 'package:in_app_database/in_app_database.dart'
    show
        InAppWriteBatch,
        InAppDatabase,
        InAppQueryReference,
        InAppDocumentSnapshot,
        InAppSetOptions,
        InAppFieldValue;

class LocalWriteBatch extends DataWriteBatch {
  late final InAppWriteBatch _batch;
  final InAppDatabase db;

  LocalWriteBatch(this.db) {
    _batch = db.batch();
  }

  @override
  void set(String path, Object data, {bool merge = true}) {
    if (data is! Map<String, dynamic>) return;
    _batch.set(db.doc(path), data, InAppSetOptions(merge: merge));
  }

  @override
  void update(String path, Map<String, dynamic> data) {
    _batch.update(db.doc(path), data);
  }

  @override
  void delete(String path) {
    _batch.delete(db.doc(path));
  }

  @override
  Future<void> commit() async {
    await _batch.commit();
  }
}

class LocalDataDelegate extends DataDelegate {
  final InAppDatabase _db;

  const LocalDataDelegate._(this._db);

  static LocalDataDelegate? _i;

  static LocalDataDelegate get i => instance;

  static LocalDataDelegate get instance {
    return _i ??= LocalDataDelegate._(InAppDatabase.instance);
  }

  @override
  DataWriteBatch batch() => LocalWriteBatch(_db);

  @override
  Future<int?> count(String path) async {
    final snapshot = await _db.collection(path).count().get();
    return snapshot.count;
  }

  @override
  Future<void> create(
    String path,
    Map<String, dynamic> data, [
    bool merge = true,
  ]) {
    return _db.doc(path).set(data, InAppSetOptions(merge: merge));
  }

  @override
  Future<void> delete(String path) {
    return _db.doc(path).delete();
  }

  @override
  Future<DataGetsSnapshot> get(String path) async {
    final snapshot = await _db.collection(path).get();
    return DataGetsSnapshot(
      snapshot: snapshot,
      docs: snapshot.docs
          .map((e) => e.data())
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      docChanges: snapshot.docChanges
          .map((e) => e.doc.data())
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
    );
  }

  @override
  Future<DataGetSnapshot> getById(String path) async {
    final snapshot = await _db.doc(path).get();
    return DataGetSnapshot(snapshot: snapshot, doc: snapshot.data());
  }

  @override
  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  }) async {
    final snapshot = await LocalQueryHelper.query(
      _db.collection(path),
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    ).get();
    return DataGetsSnapshot(
      snapshot: snapshot,
      docs: snapshot.docs
          .map((e) => e.data())
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      docChanges: snapshot.docChanges
          .map((e) => e.doc.data())
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
    );
  }

  @override
  Stream<DataGetsSnapshot> listen(String path) {
    return _db.collection(path).snapshots().map((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs
            .map((e) => e.data())
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
        docChanges: snapshot.docChanges
            .map((e) => e.doc.data())
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );
    });
  }

  @override
  Stream<DataAggregateSnapshot> listenCount(String path) {
    return _db.collection(path).count().snapshots().map((snapshot) {
      return DataAggregateSnapshot(snapshot: snapshot, count: snapshot.count);
    });
  }

  @override
  Stream<DataGetSnapshot> listenById(String path) {
    return _db.doc(path).snapshots().map((snapshot) {
      return DataGetSnapshot(snapshot: snapshot, doc: snapshot.data());
    });
  }

  @override
  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  }) {
    return LocalQueryHelper.query(
      _db.collection(path),
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    ).snapshots().map((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs
            .map((e) => e.data())
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
        docChanges: snapshot.docChanges
            .map((e) => e.doc.data())
            .whereType<Map<String, dynamic>>()
            .toList(growable: false),
      );
    });
  }

  @override
  Future<DataGetsSnapshot> search(String path, Checker checker) async {
    final snapshot =
        await LocalQueryHelper.search(_db.collection(path), checker).get();
    return DataGetsSnapshot(
      snapshot: snapshot,
      docs: snapshot.docs
          .map((e) => e.data())
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
      docChanges: snapshot.docChanges
          .map((e) => e.doc.data())
          .whereType<Map<String, dynamic>>()
          .toList(growable: false),
    );
  }

  @override
  Future<void> update(String path, Map<String, dynamic> data) {
    return _db.doc(path).update(data);
  }

  @override
  Object resolveFieldPath(Object field, String documentId) {
    if (field is! DataFieldPath) return field;
    return switch (field.type) {
      DataFieldPaths.documentId => documentId,
      DataFieldPaths.none => field,
    };
  }

  @override
  Object? resolveFieldValue(Object? value) {
    if (value is! DataFieldValue) return value;
    switch (value.type) {
      case DataFieldValues.arrayUnion:
        final list = value.value;
        return list is List ? InAppFieldValue.arrayUnion(list) : value;
      case DataFieldValues.arrayRemove:
        final list = value.value;
        return list is List ? InAppFieldValue.arrayRemove(list) : value;
      case DataFieldValues.delete:
        return InAppFieldValue.delete();
      case DataFieldValues.serverTimestamp:
        return InAppFieldValue.serverTimestamp();
      case DataFieldValues.increment:
        final n = value.value;
        return n is num ? InAppFieldValue.increment(n) : value;
      case DataFieldValues.none:
        return value;
    }
  }
}

class LocalQueryHelper {
  const LocalQueryHelper._();

  static InAppQueryReference search(InAppQueryReference ref, Checker checker) {
    final field = checker.field;
    final value = checker.value;
    final type = checker.type;

    if (value is String && value.isNotEmpty) {
      if (type.isContains) {
        ref = ref.orderBy(field).startAt([value]).endAt(['$value\uf8ff']);
      } else {
        ref = ref.where(field, isEqualTo: value);
      }
    }

    return ref;
  }

  static InAppQueryReference query(
    InAppQueryReference ref, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  }) {
    var isFetchingMode = true;
    final fetchingSizeInit = options.initialSize ?? 0;
    final fetchingSize = options.fetchingSize ?? fetchingSizeInit;
    final isValidLimit = fetchingSize > 0;

    for (final i in queries) {
      ref = ref.where(
        i.field,
        arrayContains: i.arrayContains,
        arrayNotContains: i.arrayNotContains,
        arrayContainsAny: i.arrayContainsAny?.toList(),
        arrayNotContainsAny: i.arrayNotContainsAny,
        isEqualTo: i.isEqualTo,
        isNotEqualTo: i.isNotEqualTo,
        isGreaterThan: i.isGreaterThan,
        isGreaterThanOrEqualTo: i.isGreaterThanOrEqualTo,
        isLessThan: i.isLessThan,
        isLessThanOrEqualTo: i.isLessThanOrEqualTo,
        isNull: i.isNull,
        whereIn: i.whereIn?.toList(),
        whereNotIn: i.whereNotIn?.toList(),
      );
    }

    for (final i in sorts) {
      ref = ref.orderBy(i.field, descending: i.descending);
    }

    for (final i in selections) {
      final type = i.type;
      final value = i.value;
      final values = i.values;
      final isValidValues = values != null && values.isNotEmpty;
      final isValidSnapshot = value is InAppDocumentSnapshot;
      isFetchingMode = (isValidValues || isValidSnapshot) && !type.isNone;
      if (isValidValues) {
        final list = values.toList();
        if (type.isEndAt) {
          ref = ref.endAt(list);
        } else if (type.isEndBefore) {
          ref = ref.endBefore(list);
        } else if (type.isStartAfter) {
          ref = ref.startAfter(list);
        } else if (type.isStartAt) {
          ref = ref.startAt(list);
        }
      } else if (isValidSnapshot) {
        if (type.isEndAtDocument) {
          ref = ref.endAtDocument(value);
        } else if (type.isEndBeforeDocument) {
          ref = ref.endBeforeDocument(value);
        } else if (type.isStartAfterDocument) {
          ref = ref.startAfterDocument(value);
        } else if (type.isStartAtDocument) {
          ref = ref.startAtDocument(value);
        }
      }
    }

    if (isValidLimit) {
      final size = isFetchingMode ? fetchingSize : fetchingSizeInit;
      if (size > 0) {
        ref = options.fetchFromLast ? ref.limitToLast(size) : ref.limit(size);
      }
    }
    return ref;
  }
}
