import 'package:cloud_firestore/cloud_firestore.dart'
    show
        WriteBatch,
        FirebaseFirestore,
        AggregateQuerySnapshot,
        DocumentSnapshot,
        QuerySnapshot,
        Query,
        SetOptions,
        FieldPath,
        FieldValue;
import 'package:data_management/data_management.dart'
    show
        DataWriteBatch,
        MulticastDataDelegate,
        DataAggregateSnapshot,
        DataGetSnapshot,
        DataGetsSnapshot,
        DataQuery,
        DataSelection,
        DataSorting,
        DataFetchOptions,
        Checker,
        DataFieldPath,
        DataFieldValue,
        DataFieldPaths,
        DataFieldValues;

class FirestoreWriteBatch extends DataWriteBatch {
  late final WriteBatch _batch;
  final FirebaseFirestore db;

  FirestoreWriteBatch(this.db) {
    _batch = db.batch();
  }

  @override
  void set(String path, Object data, {bool merge = true}) {
    _batch.set(db.doc(path), data, SetOptions(merge: merge));
  }

  @override
  void update(String path, Map<String, dynamic> data) {
    _batch.update(db.doc(path), data);
  }

  @override
  void delete(String path) => _batch.delete(db.doc(path));

  @override
  Future<void> commit() => _batch.commit();
}

class FirestoreDataDelegate extends MulticastDataDelegate {
  final FirebaseFirestore _db;
  final Duration operationTimeout;
  final Duration countInterval;

  FirestoreDataDelegate({
    FirebaseFirestore? firestore,
    this.operationTimeout = const Duration(seconds: 15),
    this.countInterval = const Duration(seconds: 30),
    super.multicastListen,
    super.multicastListenById,
    super.multicastListenCount,
    super.multicastListenByQuery,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  static FirestoreDataDelegate? _i;

  static FirestoreDataDelegate get i => instance;

  static FirestoreDataDelegate get instance => _i ??= FirestoreDataDelegate();

  @override
  Future<void> dispose() async {
    await super.dispose();
    if (identical(_i, this)) _i = null;
  }

  Map<String, dynamic> _withId(String id, Object? data) {
    if (data == null || data is! Map) return <String, dynamic>{'id': id};
    return <String, dynamic>{
      ...data.map((k, v) => MapEntry(k.toString(), v)),
      'id': id,
    };
  }

  DataAggregateSnapshot _agg(AggregateQuerySnapshot snapshot) {
    return DataAggregateSnapshot(count: snapshot.count, snapshot: snapshot);
  }

  DataGetSnapshot _doc(DocumentSnapshot snapshot) {
    return DataGetSnapshot(
      doc: _withId(snapshot.id, snapshot.data()),
      snapshot: snapshot,
    );
  }

  DataGetsSnapshot _docs(QuerySnapshot snapshot) {
    final docs = snapshot.docs
        .map((e) => _withId(e.id, e.data()))
        .toList(growable: false);
    final docChanges = snapshot.docChanges
        .map((e) => _withId(e.doc.id, e.doc.data()))
        .toList(growable: false);
    return DataGetsSnapshot(
      docs: docs,
      docChanges: docChanges,
      snapshot: snapshot,
    );
  }

  Future<DataAggregateSnapshot> _safeCount(String path) async {
    try {
      final snap =
          await _db.collection(path).count().get().timeout(operationTimeout);
      return _agg(snap);
    } catch (_) {
      return const DataAggregateSnapshot();
    }
  }

  @override
  DataWriteBatch batch() => FirestoreWriteBatch(_db);

  @override
  Future<int?> count(String path) async {
    final snapshot =
        await _db.collection(path).count().get().timeout(operationTimeout);
    return snapshot.count;
  }

  @override
  Future<void> create(
    String path,
    Map<String, dynamic> data, [
    bool merge = true,
  ]) {
    return _db
        .doc(path)
        .set(data, SetOptions(merge: merge))
        .timeout(operationTimeout);
  }

  @override
  Future<void> delete(String path) {
    return _db.doc(path).delete().timeout(operationTimeout);
  }

  @override
  Future<DataGetsSnapshot> get(String path) async {
    final snapshot = await _db.collection(path).get().timeout(operationTimeout);
    return _docs(snapshot);
  }

  @override
  Future<DataGetSnapshot> getById(String path) async {
    final snapshot = await _db.doc(path).get().timeout(operationTimeout);
    return _doc(snapshot);
  }

  @override
  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  }) async {
    final snapshot = await FirestoreQueryHelper.query(
      _db.collection(path),
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    ).get().timeout(operationTimeout);
    return _docs(snapshot);
  }

  @override
  Future<DataGetsSnapshot> search(String path, Checker checker) async {
    final snapshot = await FirestoreQueryHelper.search(
      _db.collection(path),
      checker,
    ).get().timeout(operationTimeout);
    return _docs(snapshot);
  }

  @override
  Future<void> update(String path, Map<String, dynamic> data) {
    return _db.doc(path).update(data).timeout(operationTimeout);
  }

  @override
  Stream<DataGetsSnapshot> listen(String path) {
    return _db.collection(path).snapshots().map(_docs);
  }

  @override
  Stream<DataGetSnapshot> listenById(String path) {
    return _db.doc(path).snapshots().map(_doc);
  }

  @override
  Stream<DataAggregateSnapshot> listenCount(String path) async* {
    yield await _safeCount(path);
    yield* Stream.periodic(countInterval).asyncMap((_) => _safeCount(path));
  }

  @override
  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  }) {
    return FirestoreQueryHelper.query(
      _db.collection(path),
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    ).snapshots().map(_docs);
  }

  @override
  Object resolveFieldPath(Object field, String documentId) {
    if (field is! DataFieldPath) return field;
    return switch (field.type) {
      DataFieldPaths.documentId => FieldPath.documentId,
      DataFieldPaths.none => field,
    };
  }

  @override
  Object? resolveFieldValue(Object? value) {
    if (value is! DataFieldValue) return value;
    switch (value.type) {
      case DataFieldValues.arrayUnion:
        final list = value.value;
        return list is List ? FieldValue.arrayUnion(list) : value;
      case DataFieldValues.arrayRemove:
        final list = value.value;
        return list is List ? FieldValue.arrayRemove(list) : value;
      case DataFieldValues.delete:
        return FieldValue.delete();
      case DataFieldValues.serverTimestamp:
        return FieldValue.serverTimestamp();
      case DataFieldValues.increment:
        final n = value.value;
        return n is num ? FieldValue.increment(n) : value;
      case DataFieldValues.none:
        return value;
    }
  }
}

class FirestoreQueryHelper {
  const FirestoreQueryHelper._();

  static Query<T> search<T extends Object?>(Query<T> ref, Checker checker) {
    final field = checker.field;
    final value = checker.value;
    final type = checker.type;

    if (field.isEmpty) return ref;

    if (value is String && value.isNotEmpty) {
      if (type.isContains) {
        return ref.orderBy(field).startAt([value]).endAt(['$value\uf8ff']);
      }
      return ref.where(field, isEqualTo: value);
    }

    if (value != null) {
      return ref.where(field, isEqualTo: value);
    }

    return ref;
  }

  static Query<T> query<T extends Object?>(
    Query<T> ref, {
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
        arrayContainsAny: i.arrayContainsAny?.toList(),
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
      final isValidSnapshot = value is DocumentSnapshot;
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
