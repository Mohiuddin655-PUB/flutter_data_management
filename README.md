# data_management
Collection of service with advanced style and controlling system.

## INTEGRATION

### LOCAL (CACHED)
```dart
import 'dart:convert';

import 'package:data_management/core.dart';
import 'package:in_app_database/in_app_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDatabaseDelegate extends InAppDatabaseDelegate {
  SharedPreferences? _db;

  SharedPreferences get db => _db!;

  @override
  Future<bool> delete(String dbName, String path) {
    return db.remove(path);
  }

  @override
  Future<bool> drop(String dbName) {
    return db.clear();
  }

  @override
  Future<bool> init(String dbName) async {
    if (_db == null) {
      _db = await SharedPreferences.getInstance();
    }
    return true;
  }

  @override
  Future<InAppWriteLimitation?> limitation(
    String dbName,
    PathDetails details,
  ) async {
    return null;
  }

  @override
  Future<Iterable<String>> paths(String dbName) async {
    return db.getKeys();
  }

  @override
  Future<Object?> read(String dbName, String path) async {
    return db.get(path);
  }

  @override
  Future<bool> write(String dbName, String path, Object? data) async {
    if (data is! Map || data.isEmpty) return false;
    if (data is! List || data.isEmpty) return false;
    return db.setString(path, jsonEncode(data));
  }
}

class LocalWriteBatch extends DataWriteBatch {
  late InAppWriteBatch batch;
  final InAppDatabase db;

  LocalWriteBatch(this.db);

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
    batch.set(db.doc(path), data, InAppSetOptions(merge: merge));
  }

  @override
  void update(String path, Map<String, dynamic> data) {
    batch.update(db.doc(path), data);
  }
}

class LocalDataDelegate extends DataDelegate {
  InAppDatabase db = InAppDatabase.instance;

  @override
  DataWriteBatch batch() => LocalWriteBatch(db);

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
    return db.doc(path).set(data, InAppSetOptions(merge: merge));
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
        docs: snapshot.docs.map((e) => e.data).whereType(),
        docChanges: snapshot.docChanges.map((e) => e.doc.data).whereType(),
      );
    });
  }

  @override
  Future<DataGetSnapshot> getById(String path) {
    return db.doc(path).get().then((snapshot) {
      return DataGetSnapshot(
        snapshot: snapshot,
        doc: snapshot.data,
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
    return LocalQueryHelper.query(
      db.collection(path),
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    ).get().then((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data).whereType(),
        docChanges: snapshot.docChanges.map((e) => e.doc.data).whereType(),
      );
    });
  }

  @override
  Stream<DataGetsSnapshot> listen(String path) {
    return db.collection(path).snapshots().map((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data).whereType(),
        docChanges: snapshot.docChanges.map((e) => e.doc.data).whereType(),
      );
    });
  }

  @override
  Stream<DataGetSnapshot> listenById(String path) {
    return db.doc(path).snapshots().map((snapshot) {
      return DataGetSnapshot(
        snapshot: snapshot,
        doc: snapshot.data,
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
    return LocalQueryHelper.query(
      db.collection(path),
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    ).snapshots().map((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data).whereType(),
        docChanges: snapshot.docChanges.map((e) => e.doc.data).whereType(),
      );
    });
  }

  @override
  Future<DataGetsSnapshot> search(String path, Checker checker) {
    return LocalQueryHelper.search(
      db.collection(path),
      checker,
    ).get().then((snapshot) {
      return DataGetsSnapshot(
        snapshot: snapshot,
        docs: snapshot.docs.map((e) => e.data).whereType(),
        docChanges: snapshot.docChanges.map((e) => e.doc.data).whereType(),
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
        return InAppFieldValue.arrayUnion(value.value as List);
      case DataFieldValues.arrayRemove:
        return InAppFieldValue.arrayRemove(value.value as List);
      case DataFieldValues.delete:
        return InAppFieldValue.delete();
      case DataFieldValues.serverTimestamp:
        return InAppFieldValue.timestamp();
      case DataFieldValues.increment:
        return InAppFieldValue.increment(value.value as num);
      case DataFieldValues.none:
        return value;
    }
  }
}

class LocalQueryHelper {
  const LocalQueryHelper._();

  static InAppQueryReference search(
    InAppQueryReference ref,
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

  static InAppQueryReference query(
    InAppQueryReference ref, {
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
        ref = ref.where(
          i.field,
          arrayContains: i.arrayContains,
          arrayNotContains: i.arrayNotContains,
          arrayContainsAny: i.arrayContainsAny,
          arrayNotContainsAny: i.arrayNotContainsAny,
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
        final isValidSnapshot = value is InAppDocumentSnapshot;
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
```

### REMOTE (SERVER SIDE)
```dart
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
```

## USE CASE

### INITIALIZATION EACH MODEL
```dart
import 'package:data_management/core.dart';
import 'package:flutter_entity/entity.dart';

import 'local.dart';
import 'remote.dart';

class Photo extends Entity {
  final String? path;
  final String? url;

  const Photo({super.id, super.timeMills, this.path, this.url});

  factory Photo.from(Object? source) {
    if (source is! Map) return Photo();
    return Photo(
      id: source["id"],
      timeMills: source["timeMills"],
      path: source["path"],
      url: source["url"],
    );
  }

  @override
  bool isInsertable(String key, value) => value != null;

  @override
  Map<String, dynamic> get source {
    return super.source..addAll({"path": path, "url": url});
  }
}

class User extends Entity {
  final String? path;
  final String? name;

  const User({super.id, super.timeMills, this.path, this.name});

  factory User.from(Object? source) {
    if (source is! Map) return User();
    return User(
      id: source["id"],
      timeMills: source["timeMills"],
      path: source["path"],
      name: source["name"],
    );
  }

  @override
  bool isInsertable(String key, value) => value != null;

  @override
  Map<String, dynamic> get source {
    return super.source..addAll({"path": path, "url": name});
  }
}

class Feed extends Entity {
  final String? title;
  final User? publisher;
  final Photo? photo;

  const Feed({
    super.id,
    super.timeMills,
    this.title,
    this.publisher,
    this.photo,
  });

  factory Feed.from(Object? source) {
    if (source is! Map) return Feed();
    return Feed(
      id: source["id"],
      timeMills: source["timeMills"],
      title: source["title"],
      publisher: User.from(source["publisher"]),
      photo: Photo.from(source["photo"]),
    );
  }

  @override
  bool isInsertable(String key, value) => value != null;

  @override
  Map<String, dynamic> get source {
    return super.source
      ..addAll(
        {
          "title": title,
          "@publisher": publisher?.path,
          "@photo": photo?.path,
        },
      );
  }
}

class RemoteFeedDataSource extends RemoteDataSource<Feed> {
  RemoteFeedDataSource()
      : super(
          path: "users",
          delegate: FirestoreDataDelegate(),
          limitations: DataLimitations(whereIn: 10),
        );

  @override
  Feed build(source) => Feed.from(source);
}

class LocalFeedDataSource extends LocalDataSource<Feed> {
  LocalFeedDataSource()
      : super(
          path: "users",
          delegate: LocalDataDelegate(),
          limitations: DataLimitations(whereIn: 10),
        );

  @override
  Feed build(source) => Feed.from(source);
}

class FeedRepository extends RemoteDataRepository<Feed> {
  static FeedRepository? _i;

  static FeedRepository get i => _i ??= FeedRepository._();

  FeedRepository._()
      : super(source: RemoteFeedDataSource(), backup: LocalFeedDataSource());
}
```

### FINAL
```dart
import 'package:flutter/material.dart';
import 'package:flutter_entity/flutter_entity.dart';
import 'package:in_app_database/in_app_database.dart';

import 'local.dart';
import 'model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await InAppDatabase.init(delegate: LocalDatabaseDelegate());
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final crud = FeedRepository.i;

  String feedPath = "test_feeds";
  String userPath = "test_users";
  String feedId = "feed_123";
  String userId = "user_123";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Custom Ref CRUD Demo")),
      bottomNavigationBar: Row(
        children: [
          ElevatedButton(onPressed: _createFeed, child: const Text("Create")),
          const SizedBox(width: 12),
          ElevatedButton(onPressed: _updateFeed, child: const Text("Update")),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _deleteFeed,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
      body: FutureBuilder<Response<Feed>>(
        future: crud.getById(feedId, resolveRefs: true),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("No feed found"));
          }

          final feed = snapshot.data!.data ?? Feed();
          final publisher = feed.publisher ?? User();
          final photo = feed.photo ?? Photo();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feed.title ?? "No title",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage:
                          photo.url != null ? NetworkImage(photo.url!) : null,
                      radius: 24,
                      child:
                          photo.url == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 12),
                    Text(publisher.name ?? "Unknown publisher"),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Example Create
  Future<void> _createFeed() async {
    await crud.createById(feedId, createRefs: true, {
      "title": "My First Feed",
      "@publisher": {
        "path": "$userPath/$userId",
        "create": {
          "name": "John Doe",
          "joinedAt": DateTime.now().millisecondsSinceEpoch,
        },
      },
      "@photo": {
        "path": "$userPath/$userId/avatars/avatar_456",
        "create": {"url": "https://picsum.photos/200"},
      },
    });
  }

  /// Example Update
  Future<void> _updateFeed() async {
    await crud.updateById(feedId, updateRefs: true, {
      "title":
          "Feed Updated at ${DateTime.now().hour}:${DateTime.now().minute}",
      "@photo": {
        "path": "$userPath/$userId/avatars/avatar_456",
        "update": {
          "url": "https://picsum.photos/500",
          "title": "Updated title",
        },
      },
      "@publisher": {
        "path": "$userPath/$userId",
        "update": {
          "name": "Update Omie",
          "updatedAt": DateTime.now().millisecondsSinceEpoch,
        },
      },
    });
  }

  Future<void> _deleteFeed() async {
    await crud.deleteById(
      feedId,
      deleteRefs: true,
    );
  }
}
```