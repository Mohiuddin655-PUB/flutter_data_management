import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:data_management/core.dart';

class FirestoreWriteBatch extends DataWriteBatch {
  late WriteBatch batch;
  final FirebaseFirestore db;

  FirestoreWriteBatch(this.db);

  @override
  void init() {
    batch = db.batch();
  }

  @override
  Future<void> commit() async {
    await batch.commit();
  }

  @override
  void delete(String path) {
    batch.delete(db.doc(path));
  }

  @override
  void set(String path, Object data, [bool merge = true]) {
    batch.set(db.doc(path), data, SetOptions(merge: merge));
  }

  @override
  void update(String path, Map<String, dynamic> data) {
    batch.update(db.doc(path), data);
  }
}

class FirestoreDataDelegate extends DataDelegate {
  FirebaseFirestore db = FirebaseFirestore.instance;

  @override
  DataWriteBatch batch() => FirestoreWriteBatch(db);

  @override
  Future<int?> count(String path) {
    return db.collection(path).count().get().then((snapshot) {
      return snapshot.count;
    });
  }

  @override
  Future<void> create(
    String path,
    Map<String, dynamic> data, [
    bool merge = true,
  ]) {
    return db.doc(path).set(data, SetOptions(merge: merge));
  }

  @override
  Future<void> delete(String path) {
    return db.doc(path).delete();
  }

  @override
  Future<DataGetsSnapshot> get(String path) {
    return db.collection(path).get().then((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data()),
        docChanges: snapshot.docChanges.map((e) => e.doc.data()).whereType(),
      );
    });
  }

  @override
  Future<DataGetSnapshot> getById(String path) {
    return db.doc(path).get().then((snapshot) {
      return DataGetSnapshot(
        snapshot: snapshot,
        doc: snapshot.data(),
      );
    });
  }

  @override
  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
  }) {
    return FirestoreQueryHelper.query(
      db.collection(path),
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    ).get().then((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data()),
        docChanges: snapshot.docChanges.map((e) => e.doc.data()).whereType(),
      );
    });
  }

  @override
  Stream<DataGetsSnapshot> listen(String path) {
    return db.collection(path).snapshots().map((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data()),
        docChanges: snapshot.docChanges.map((e) => e.doc.data()).whereType(),
      );
    });
  }

  @override
  Stream<DataGetSnapshot> listenById(String path) {
    return db.doc(path).snapshots().map((snapshot) {
      return DataGetSnapshot(
        snapshot: snapshot,
        doc: snapshot.data(),
      );
    });
  }

  @override
  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
  }) {
    return FirestoreQueryHelper.query(
      db.collection(path),
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    ).snapshots().map((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data()),
        docChanges: snapshot.docChanges.map((e) => e.doc.data()).whereType(),
      );
    });
  }

  @override
  Future<DataGetsSnapshot> search(String path, Checker checker) {
    return FirestoreQueryHelper.search(
      db.collection(path),
      checker,
    ).get().then((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data()),
        docChanges: snapshot.docChanges.map((e) => e.doc.data()).whereType(),
      );
    });
  }

  @override
  Future<void> update(String path, Map<String, dynamic> data) {
    return db.doc(path).update(data);
  }

  @override
  Object? updatingFieldValue(Object? value) {
    if (value is! DataFieldValue) return value;
    switch (value.type) {
      case DataFieldValues.arrayUnion:
        return FieldValue.arrayUnion(value.value as List);
      case DataFieldValues.arrayRemove:
        return FieldValue.arrayRemove(value.value as List);
      case DataFieldValues.delete:
        return FieldValue.delete();
      case DataFieldValues.serverTimestamp:
        return FieldValue.serverTimestamp();
      case DataFieldValues.increment:
        return FieldValue.increment(value.value as num);
      case DataFieldValues.none:
        return value;
    }
  }
}

class FirestoreQueryHelper {
  const FirestoreQueryHelper._();

  static Query<T> search<T extends Object?>(
    Query<T> ref,
    Checker checker,
  ) {
    final field = checker.field;
    final value = checker.value;
    final type = checker.type;

    if (value is String) {
      if (type.isContains) {
        ref = ref.orderBy(field).startAt([value]).endAt(['$value\uf8ff']);
      } else {
        ref = ref.where(field, isEqualTo: value);
      }
    }

    return ref;
  }

  static Query<T> query<T extends Object?>(
    Query<T> ref, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
  }) {
    var isFetchingMode = true;
    final fetchingSizeInit = options.initialSize ?? 0;
    final fetchingSize = options.fetchingSize ?? fetchingSizeInit;
    final isValidLimit = fetchingSize > 0;

    if (queries.isNotEmpty) {
      for (final i in queries) {
        final field = i.field;
        ref = ref.where(
          field,
          arrayContains: i.arrayContains,
          arrayContainsAny: i.arrayContainsAny,
          isEqualTo: i.isEqualTo,
          isNotEqualTo: i.isNotEqualTo,
          isGreaterThan: i.isGreaterThan,
          isGreaterThanOrEqualTo: i.isGreaterThanOrEqualTo,
          isLessThan: i.isLessThan,
          isLessThanOrEqualTo: i.isLessThanOrEqualTo,
          isNull: i.isNull,
          whereIn: i.whereIn,
          whereNotIn: i.whereNotIn,
        );
      }
    }

    if (sorts.isNotEmpty) {
      for (final i in sorts) {
        ref = ref.orderBy(i.field, descending: i.descending);
      }
    }

    if (selections.isNotEmpty) {
      for (final i in selections) {
        final type = i.type;
        final value = i.value;
        final values = i.values;
        final isValidValues = values != null && values.isNotEmpty;
        final isValidSnapshot = value is DocumentSnapshot;
        isFetchingMode = (isValidValues || isValidSnapshot) && !type.isNone;
        if (isValidValues) {
          if (type.isEndAt) {
            ref = ref.endAt(values);
          } else if (type.isEndBefore) {
            ref = ref.endBefore(values);
          } else if (type.isStartAfter) {
            ref = ref.startAfter(values);
          } else if (type.isStartAt) {
            ref = ref.startAt(values);
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
    }

    if (isValidLimit) {
      if (options.fetchFromLast) {
        if (isFetchingMode) {
          ref = ref.limitToLast(fetchingSize);
        } else {
          ref = ref.limitToLast(fetchingSizeInit);
        }
      } else {
        if (isFetchingMode) {
          ref = ref.limit(fetchingSize);
        } else {
          ref = ref.limit(fetchingSizeInit);
        }
      }
    }
    return ref;
  }
}
