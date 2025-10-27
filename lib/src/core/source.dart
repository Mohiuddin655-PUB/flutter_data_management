import 'package:async/async.dart';
import 'package:flutter_entity/entity.dart';

import 'checker.dart';
import 'configs.dart';
import 'encryptor.dart';
import 'extensions.dart';
import 'limitations.dart';
import 'modifiers.dart';
import 'operation.dart';
import 'updating_info.dart';

/// # Won't Use Directly
/// You can use:
/// * <b>[ApiDataSource]</b> : Use for Api related data.
/// * <b>[FireStoreDataSource]</b> : Use for Firebase Cloud firestore related data.
/// * <b>[RealtimeDataSource]</b> : Use for Firebase realtime database related data.
/// * <b>[LocalDataSourceImpl]</b> : Use for local or save instance related data.
///
/// ## Abstract class representing a data source for handling operations related to entities of type [T].
///
/// ### A data source for handling cached data operations.
///
/// Example:
/// ```dart
/// class LocalUserDataSource extends LocalDataSourceImpl {
///   // Implement local data source operations for User entities.
/// }
/// ```
///
/// ### A data source for handling api based data operations.
///
/// Example:
/// ```dart
/// class ApiUserDataSource extends ApiDataSource {
///   // Implement api based data source operations for User entities.
/// }
/// ```
///
/// ### A data source for handling Firestore database operations.
///
/// Example:
/// ```dart
/// class FirestoreUserDataSource extends FirestoreDataSource {
///   // Implement Firestore data source operations for User entities.
/// }
/// ```
///
/// ### A data source for handling Realtime database operations.
///
/// Example:
/// ```dart
/// class RealtimeUserDataSource extends RealtimeDataSource {
///   // Implement real-time data source operations for User entities.
/// }
/// ```
///
/// ## Abstract class representing a generic data repository with methods for CRUD operations.
///
/// This abstract class defines the structure of a generic data repository.
/// It is not intended to be used directly. Instead, use its implementations:
/// * <b>[RemoteDataSource]</b> : Use for all remote database related data.
/// * <b>[LocalDataSource]</b> : Use for all local database related data.
///
/// Example:
/// ```dart
/// final RemoteDataSource remoteUserDataSource = RemoteUserDataSource();
/// final LocalDataSource localUserDataSource = LocalUserDataSource();
/// ```
///
abstract class DataSource<T extends Entity> {
  final String path;
  final DataDelegate delegate;
  final DataLimitations limitations;

  final DataEncryptor? encryptor;

  bool get isEncryptor => encryptor.isValid;

  DataOperation get operation => DataOperation(delegate);

  const DataSource({
    required this.path,
    required this.delegate,
    this.encryptor,
    this.limitations = const DataLimitations(),
  });

  Future<Response<S>> execute<S extends Object>(
    Future<Response<S>> Function() callback,
  ) async {
    try {
      return callback();
    } catch (error) {
      return Response<S>(status: Status.failure, error: error.toString());
    }
  }

  Stream<Response<S>> executeStream<S extends Object>(
    Stream<Response<S>> Function() callback,
  ) {
    try {
      return callback();
    } catch (error) {
      return Stream.value(
        Response<S>(status: Status.failure, error: error.toString()),
      );
    }
  }

  String ref(DataFieldParams? params, DataModifiers modifier, [String? id]) {
    final a = params.generate(path);
    if (id == null || id.isEmpty) return a;
    return "$a/$id";
  }

  /// Method to check data by ID with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.checkById(
  ///   'userId123',
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> checkById(
    String id, {
    DataFieldParams? params,
    bool resolveRefs = false,
    List<String> ignorableResolverFields = const [],
  }) async {
    return execute(() {
      final path = ref(params, DataModifiers.checkById, id);
      return operation
          .getById(
        path,
        resolveRefs: resolveRefs,
        ignorableResolverFields: ignorableResolverFields,
      )
          .then((data) async {
        if (!data.exists) {
          return Response(status: Status.notFound);
        }
        final v = isEncryptor ? await encryptor.output(data.doc) : data.doc;
        return Response(
          status: Status.ok,
          data: build(v),
          snapshot: data.snapshot,
        );
      });
    });
  }

  /// Method to clear data with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.clear(
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> clear({
    DataFieldParams? params,
    bool? resolveRefs,
    bool deleteRefs = false,
    List<String> ignorableResolverFields = const [],
  }) async {
    return execute(() {
      final path = ref(params, DataModifiers.clear);
      return operation
          .get(
        path,
        resolveRefs: resolveRefs ?? deleteRefs,
        ignorableResolverFields: ignorableResolverFields,
      )
          .then((value) {
        if (!value.exists) return Response(status: Status.notFound);
        final ids = value.docs.map((e) => e.id).whereType<String>().toList();
        if (ids.isEmpty) return Response(status: Status.notFound);
        return execute(() {
          return deleteByIds(
            ids,
            params: params,
            deleteRefs: deleteRefs,
            ignorableResolverFields: ignorableResolverFields,
          ).then((deleted) {
            return deleted.copyWith(
              backups: value.docs.map((e) => build(e)).toList(),
              snapshot: value.snapshot,
              status: Status.ok,
            );
          });
        });
      });
    });
  }

  Future<Response<int>> count({DataFieldParams? params}) async {
    return execute(() {
      final path = ref(params, DataModifiers.count);
      return operation.count(path).then((value) {
        return Response(status: Status.ok, data: value);
      });
    });
  }

  /// Method to create data with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// T newData = //...;
  /// repository.create(
  ///   newData,
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> create(
    String id,
    Map<String, dynamic> data, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
  }) async {
    if (id.isEmpty) return Response(status: Status.invalidId);
    if (data.isEmpty) return Response(status: Status.invalid);
    return execute(() {
      final path = ref(params, DataModifiers.create, id);
      if (isEncryptor) {
        return encryptor.input(data).then((raw) {
          if (raw.isEmpty) {
            return Response(status: Status.error, error: "Encryption error!");
          }
          return operation
              .create(path, raw, merge: merge, createRefs: createRefs)
              .then((value) {
            return Response(status: Status.ok, data: build(data));
          });
        });
      } else {
        return operation
            .create(path, data, merge: merge, createRefs: createRefs)
            .then((v) {
          return Response(status: Status.ok, data: build(data));
        });
      }
    });
  }

  /// Method to create multiple data entries with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// List<T> newDataList = //...;
  /// repository.creates(
  ///   newDataList,
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> creates(
    Iterable<DataWriter> writers, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
  }) async {
    if (writers.isEmpty) return Response(status: Status.invalid);
    return execute(() {
      final callbacks = writers.map((e) {
        return create(
          e.id,
          e.data,
          params: params,
          createRefs: createRefs,
          merge: merge,
        );
      });
      return Future.wait(callbacks).then((value) {
        final x = value.where((e) => e.isSuccessful);
        return Response(
          status: x.length == writers.length ? Status.ok : Status.canceled,
          snapshot: value,
        );
      });
    });
  }

  /// Method to delete data by ID with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.deleteById(
  ///   'userId123',
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> deleteById(
    String id, {
    DataFieldParams? params,
    bool? resolveRefs,
    List<String> ignorableResolverFields = const [],
    bool deleteRefs = false,
  }) async {
    if (id.isEmpty) return Response(status: Status.invalidId);
    return execute(() {
      return getById(
        id,
        params: params,
        resolveRefs: resolveRefs ?? deleteRefs,
        ignorableResolverFields: ignorableResolverFields,
      ).then((old) {
        if (!old.isValid) return old;
        final path = ref(params, DataModifiers.deleteById, id);
        return operation.delete(path, deleteRefs: deleteRefs).then((value) {
          return Response(status: Status.ok, backups: [old.data!]);
        });
      });
    });
  }

  /// Method to delete data by multiple IDs with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// List<String> idsToDelete = ['userId1', 'userId2'];
  /// repository.deleteByIds(
  ///   idsToDelete,
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> deleteByIds(
    Iterable<String> ids, {
    DataFieldParams? params,
    bool? resolveRefs,
    List<String> ignorableResolverFields = const [],
    bool deleteRefs = false,
  }) async {
    if (ids.isEmpty) return Response(status: Status.invalid);
    return execute(() {
      final callbacks = ids.map((e) {
        return deleteById(
          e,
          params: params,
          resolveRefs: resolveRefs ?? deleteRefs,
          ignorableResolverFields: ignorableResolverFields,
          deleteRefs: deleteRefs,
        );
      });
      return Future.wait(callbacks).then((value) {
        final x = value.where((e) => e.isSuccessful);
        return Response(
          status: x.length == ids.length ? Status.ok : Status.canceled,
          snapshot: value,
          backups: value.map((e) => e.data).whereType<T>().toList(),
        );
      });
    });
  }

  /// Method to get data with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.get(
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> get({
    DataFieldParams? params,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) async {
    return execute(() {
      List<T> result = [];
      final path = ref(params, DataModifiers.get);
      return operation
          .get(
        path,
        resolveRefs: resolveRefs && !onlyUpdates,
        resolveDocChangesRefs:
            resolveDocChangesRefs || (onlyUpdates && resolveRefs),
        ignorableResolverFields: ignorableResolverFields,
      )
          .then((event) async {
        if (event.docs.isEmpty && event.docChanges.isEmpty) {
          return Response(status: Status.notFound, snapshot: event.snapshot);
        }
        result.clear();
        for (var i in onlyUpdates ? event.docChanges : event.docs) {
          if (i.isEmpty) continue;
          final v = isEncryptor ? await encryptor.output(i) : i;
          result.add(build(v));
        }
        if (result.isEmpty) {
          return Response(
            status: Status.notFound,
            snapshot: event.snapshot,
          );
        }
        return Response(
          result: result,
          snapshot: event.snapshot,
          status: Status.ok,
        );
      });
    });
  }

  /// Method to get data by ID with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.getById(
  ///   'userId123',
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> getById(
    String id, {
    DataFieldParams? params,
    bool resolveRefs = false,
    List<String> ignorableResolverFields = const [],
  }) async {
    if (id.isEmpty) return Response(status: Status.invalidId);
    return execute(() {
      final path = ref(params, DataModifiers.getById, id);
      return operation
          .getById(
        path,
        resolveRefs: resolveRefs,
        ignorableResolverFields: ignorableResolverFields,
      )
          .then((event) async {
        if (!event.exists) {
          return Response(
            status: Status.notFound,
            snapshot: event.snapshot,
          );
        }
        final data = event.doc;
        final v = isEncryptor ? await encryptor.output(data) : data;
        return Response(
          status: Status.ok,
          data: build(v),
          snapshot: event.snapshot,
        );
      });
    });
  }

  /// Method to get data by multiple IDs with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// List<String> idsToRetrieve = ['userId1', 'userId2'];
  /// repository.getByIds(
  ///   idsToRetrieve,
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> getByIds(
    Iterable<String> ids, {
    DataFieldParams? params,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) async {
    if (ids.isEmpty) return Response(status: Status.invalid);
    return execute(() {
      if (limitations.whereIn > 0 && ids.length > limitations.whereIn) {
        final callbacks = ids.map((e) {
          return getById(
            e,
            params: params,
            resolveRefs: resolveRefs,
            ignorableResolverFields: ignorableResolverFields,
          );
        });
        return Future.wait(callbacks).then((value) {
          final x = value.where((e) => e.isSuccessful);
          return Response(
            status: x.length == ids.length ? Status.ok : Status.canceled,
            result: value.map((e) => e.data).whereType<T>().toList(),
          );
        });
      } else {
        List<T> result = [];
        final path = ref(params, DataModifiers.getByIds);
        return operation.getByQuery(path,
            resolveRefs: resolveRefs,
            resolveDocChangesRefs: resolveDocChangesRefs,
            ignorableResolverFields: ignorableResolverFields,
            queries: [
              DataQuery(DataFieldPath.documentId, whereIn: ids)
            ]).then((event) async {
          if (event.docs.isEmpty) return Response(status: Status.notFound);
          result.clear();
          for (var i in event.docs) {
            if (i.isNotEmpty) {
              var v = isEncryptor ? await encryptor.output(i) : i;
              result.add(build(v));
            }
          }
          if (result.isEmpty) return Response(status: Status.notFound);
          return Response(status: Status.ok, result: result, snapshot: event);
        });
      }
    });
  }

  /// Method to get data by query with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// List<Query> queries = [Query.field('name', 'John')];
  /// repository.getByQuery(
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  ///   queries: queries,
  /// );
  /// ```
  Future<Response<T>> getByQuery({
    DataFieldParams? params,
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) async {
    return execute(() {
      List<T> result = [];
      final path = ref(params, DataModifiers.getByQuery);
      return operation
          .getByQuery(
        path,
        queries: queries,
        selections: selections,
        sorts: sorts,
        options: options,
        resolveRefs: resolveRefs && !onlyUpdates,
        resolveDocChangesRefs:
            resolveDocChangesRefs || (onlyUpdates && resolveRefs),
        ignorableResolverFields: ignorableResolverFields,
      )
          .then((event) async {
        if (event.docs.isEmpty && event.docChanges.isEmpty) {
          return Response(status: Status.notFound, snapshot: event.snapshot);
        }
        result.clear();
        for (var i in onlyUpdates ? event.docChanges : event.docs) {
          if (i.isEmpty) continue;
          final v = isEncryptor ? await encryptor.output(i) : i;
          result.add(build(v));
        }
        if (result.isEmpty) {
          return Response(
            status: Status.notFound,
            snapshot: event.snapshot,
          );
        }
        return Response(
          result: result,
          snapshot: event.snapshot,
          status: Status.ok,
        );
      });
    });
  }

  /// Stream method to listen for data changes with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.listen(
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Stream<Response<T>> listen({
    DataFieldParams? params,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) {
    return executeStream(() {
      List<T> result = [];
      final path = ref(params, DataModifiers.listen);
      return operation
          .listen(
        path,
        resolveRefs: resolveRefs && !onlyUpdates,
        resolveDocChangesRefs:
            resolveDocChangesRefs || (onlyUpdates && resolveRefs),
        ignorableResolverFields: ignorableResolverFields,
      )
          .asyncMap((event) async {
        if (event.docs.isEmpty && event.docChanges.isEmpty) {
          return Response(status: Status.notFound, snapshot: event.snapshot);
        }
        result.clear();
        for (var i in onlyUpdates ? event.docChanges : event.docs) {
          if (i.isEmpty) continue;
          final v = isEncryptor ? await encryptor.output(i) : i;
          result.add(build(v));
        }
        if (result.isEmpty) return Response(status: Status.notFound);
        return Response(
          result: result,
          snapshot: event.snapshot,
          status: Status.ok,
        );
      });
    });
  }

  /// Method to listenCount data with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.listenCount(
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Stream<Response<int>> listenCount({
    DataFieldParams? params,
    Duration? interval,
  }) {
    return executeStream(() {
      final path = ref(params, DataModifiers.listenCount);
      return Stream.periodic(interval ?? Duration(seconds: 10)).asyncMap((_) {
        return operation.count(path).then((e) {
          return Response(data: e, status: Status.ok);
        });
      });
    });
  }

  /// Stream method to listen for data changes by ID with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.listenById(
  ///   'userId123',
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Stream<Response<T>> listenById(
    String id, {
    DataFieldParams? params,
    bool resolveRefs = false,
    List<String> ignorableResolverFields = const [],
  }) {
    if (id.isEmpty) return Stream.value(Response(status: Status.invalidId));
    return executeStream(() {
      final path = ref(params, DataModifiers.listenById, id);
      return operation
          .listenById(
        path,
        resolveRefs: resolveRefs,
        ignorableResolverFields: ignorableResolverFields,
      )
          .asyncMap((event) async {
        if (!event.exists) return Response(status: Status.notFound);
        var data = event.doc;
        final v = isEncryptor ? await encryptor.output(data) : data;
        return Response(status: Status.ok, data: build(v), snapshot: event);
      });
    });
  }

  /// Stream method to listen for data changes by multiple IDs with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// List<String> idsToListen = ['userId1', 'userId2'];
  /// repository.listenByIds(
  ///   idsToListen,
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Stream<Response<T>> listenByIds(
    Iterable<String> ids, {
    DataFieldParams? params,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) {
    if (ids.isEmpty) return Stream.value(Response(status: Status.invalid));
    return executeStream(() {
      if (limitations.whereIn > 0 && ids.length > limitations.whereIn) {
        Map<String, T> map = {};
        return StreamGroup.merge(
          ids.map((e) {
            return listenById(
              e,
              params: params,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
            );
          }),
        ).map((event) {
          final data = event.data;
          if (data != null) map[data.id] = data;
          if (map.isEmpty) return Response(status: Status.notFound);
          return Response(
            result: map.values.toList(),
            snapshot: event.snapshot,
            status: Status.ok,
          );
        });
      } else {
        List<T> result = [];
        final path = ref(params, DataModifiers.listenByIds);
        return operation.listenByQuery(path,
            resolveRefs: resolveRefs,
            resolveDocChangesRefs: resolveDocChangesRefs,
            ignorableResolverFields: ignorableResolverFields,
            queries: [
              DataQuery(DataFieldPath.documentId, whereIn: ids)
            ]).asyncMap((event) async {
          result.clear();
          if (event.docs.isNotEmpty) {
            for (final i in event.docs) {
              if (i.isNotEmpty) {
                final v = isEncryptor ? await encryptor.output(i) : i;
                result.add(build(v));
              }
            }
            if (result.isEmpty) {
              return Response(
                status: Status.notFound,
                snapshot: event.snapshot,
              );
            }
            return Response(
              status: Status.ok,
              result: result,
              snapshot: event.snapshot,
            );
          }
          return Response(status: Status.notFound, snapshot: event.snapshot);
        });
      }
    });
  }

  /// Stream method to listen for data changes by query with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// List<Query> queries = [Query.field('name', 'John')];
  /// repository.listenByQuery(
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  ///   queries: queries,
  /// );
  /// ```
  Stream<Response<T>> listenByQuery({
    DataFieldParams? params,
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) {
    return executeStream(() {
      List<T> result = [];
      final path = ref(params, DataModifiers.listenByQuery);
      return operation
          .listenByQuery(
        path,
        resolveRefs: resolveRefs && !onlyUpdates,
        resolveDocChangesRefs:
            resolveDocChangesRefs || (onlyUpdates && resolveRefs),
        ignorableResolverFields: ignorableResolverFields,
      )
          .asyncMap((event) async {
        if (event.docs.isEmpty && event.docChanges.isEmpty) {
          return Response(status: Status.notFound);
        }
        result.clear();
        for (var i in onlyUpdates ? event.docChanges : event.docs) {
          if (i.isEmpty) continue;
          final v = isEncryptor ? await encryptor.output(i) : i;
          result.add(build(v));
        }
        if (result.isEmpty) {
          return Response(
            status: Status.notFound,
            snapshot: event.snapshot,
          );
        }
        return Response(
          result: result,
          snapshot: event.snapshot,
          status: Status.ok,
        );
      });
    });
  }

  /// Method to check data by query with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// Checker checker = Checker(field: 'status', value: 'active');
  /// repository.search(
  ///   checker,
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> search(
    Checker checker, {
    DataFieldParams? params,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) async {
    if (checker.field.isEmpty) return Response(status: Status.invalid);
    return execute(() {
      List<T> result = [];
      final path = ref(params, DataModifiers.search);
      return operation
          .search(
        path,
        checker,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignorableResolverFields: ignorableResolverFields,
      )
          .then((event) async {
        if (event.docs.isEmpty) return Response(status: Status.notFound);
        result.clear();
        for (final i in event.docs) {
          if (i.isNotEmpty) {
            final v = isEncryptor ? await encryptor.output(i) : i;
            result.add(build(v));
          }
        }
        if (result.isEmpty) return Response(status: Status.notFound);
        return Response(status: Status.ok, result: result, snapshot: event);
      });
    });
  }

  /// Method to update data by ID with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.updateById(
  ///   'userId123',
  ///   {'status': 'inactive'},
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> updateById(
    String id,
    Map<String, dynamic> data, {
    DataFieldParams? params,
    bool? resolveRefs,
    List<String> ignorableResolverFields = const [],
    bool updateRefs = false,
  }) async {
    if (id.isEmpty || data.isEmpty) return Response(status: Status.invalid);
    return execute(() {
      final path = ref(params, DataModifiers.updateById, id);
      data = data.map((k, v) => MapEntry(k, delegate.updatingFieldValue(v)));
      if (!isEncryptor) {
        return operation
            .update(path, data, updateRefs: updateRefs)
            .then((value) => Response(status: Status.ok));
      }
      return getById(
        id,
        params: params,
        resolveRefs: resolveRefs ?? updateRefs,
        ignorableResolverFields: ignorableResolverFields,
      ).then((value) {
        final x = value.data?.filtered ?? {};
        x.addAll(data);
        return encryptor.input(x).then((v) {
          if (v.isEmpty) return Response(status: Status.nullable);
          return operation
              .update(path, v, updateRefs: updateRefs)
              .then((value) => Response(status: Status.ok));
        });
      });
    });
  }

  /// Method to update data by multiple IDs with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// List<UpdatingInfo> updates = [
  ///   UpdatingInfo('userId1', {'status': 'inactive'}),
  ///   UpdatingInfo('userId2', {'status': 'active'}),
  /// ];
  /// repository.updateByIds(
  ///   updates,
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> updateByIds(
    Iterable<DataWriter> updates, {
    DataFieldParams? params,
    bool? resolveRefs,
    List<String> ignorableResolverFields = const [],
    bool updateRefs = false,
  }) async {
    if (updates.isEmpty) return Response(status: Status.invalid);
    return execute(() {
      final callbacks = updates.map((e) {
        return updateById(
          e.id,
          e.data,
          params: params,
          resolveRefs: resolveRefs ?? updateRefs,
          ignorableResolverFields: ignorableResolverFields,
          updateRefs: updateRefs,
        );
      });
      return Future.wait(callbacks).then((value) {
        final x = value.where((e) => e.isSuccessful);
        return Response(
          status: x.length == updates.length ? Status.ok : Status.canceled,
          snapshot: value,
          backups: value.map((e) => e.data).whereType<T>().toList(),
        );
      });
    });
  }

  T build(dynamic source);
}

abstract class LocalDataSource<T extends Entity> extends DataSource<T> {
  const LocalDataSource({
    required super.path,
    required super.delegate,
    super.encryptor,
    super.limitations,
  });
}

abstract class RemoteDataSource<T extends Entity> extends DataSource<T> {
  const RemoteDataSource({
    required super.path,
    required super.delegate,
    super.encryptor,
    super.limitations,
  });
}
