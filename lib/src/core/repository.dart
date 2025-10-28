import 'package:flutter_entity/entity.dart';

import 'cache_manager.dart';
import 'checker.dart';
import 'configs.dart';
import 'database_type.dart';
import 'modifiers.dart';
import 'source.dart';
import 'updating_info.dart';

typedef FutureConnectivityCallback = Future<bool> Function();

/// ## Abstract class representing a generic data repository with methods for CRUD operations.
///
/// This abstract class defines the structure of a generic data repository.
/// It is not intended to be used directly. Instead, use its implementations:
/// * <b>[RemoteDataRepository]</b> : Use for all remote database related data.
/// * <b>[LocalDataRepository]</b> : Use for all local database related data.
///
/// Example:
/// ```dart
/// final DataRepository userRepository = RemoteDataRepository();
/// final DataRepository<Post> postRepository = LocalDataRepository<Post>();
/// ```

class DataRepository<T extends Entity> {
  final String? id;
  final DatabaseType _type;
  final bool backupMode;
  final bool lazyMode;
  final bool restoreMode;
  final bool singletonMode;

  /// The primary remote data source responsible for fetching data.
  final DataSource<T> primary;

  /// An optional local data source used as a backup or cache when in cache mode.
  final DataSource<T>? optional;

  /// Connectivity provider for checking internet connectivity.
  final FutureConnectivityCallback? _connectivity;

  /// Getter for checking if the device is connected to the internet.
  Future<bool> get isConnected async {
    if (_connectivity != null) return _connectivity!();
    return false;
  }

  /// Getter for checking if the device is disconnected from the internet.
  Future<bool> get isDisconnected async => !(await isConnected);

  bool get isLocalDB => _type == DatabaseType.local;

  bool isBackupMode([bool? backupMode]) {
    return optional != null && (backupMode ?? this.backupMode);
  }

  bool isLazyMode([bool? lazyMode]) => lazyMode ?? this.lazyMode;

  bool isSingletonMode([bool? singletonMode]) {
    return singletonMode ?? this.singletonMode;
  }

  /// Constructor for creating a [RemoteDataRepository] implement.
  ///
  /// Parameters:
  /// - [source]: The primary local data source. Ex: [LocalDataSourceImpl].
  /// - [backup]: An optional remote data source. Ex: [ApiDataSource], [FirestoreDataSource], and [RealtimeDataSource].
  ///
  const DataRepository.local({
    this.id,
    this.backupMode = true,
    this.lazyMode = true,
    this.restoreMode = true,
    this.singletonMode = false,
    required LocalDataSource<T> source,
    RemoteDataSource<T>? backup,
    FutureConnectivityCallback? connectivity,
  })  : _type = DatabaseType.local,
        primary = source,
        optional = backup,
        _connectivity = connectivity;

  /// Constructor for creating a [RemoteDataRepository] implement.
  ///
  /// Parameters:
  /// - [source]: The primary remote data source. Ex: [ApiDataSource], [FirestoreDataSource], and [RealtimeDataSource].
  /// - [backup]: An optional cache data source. Ex: [LocalDataSourceImpl].
  ///
  const DataRepository.remote({
    this.id,
    this.backupMode = true,
    this.lazyMode = true,
    this.restoreMode = true,
    this.singletonMode = true,
    required RemoteDataSource<T> source,
    LocalDataSource<T>? backup,
    FutureConnectivityCallback? connectivity,
  })  : _type = DatabaseType.remote,
        primary = source,
        optional = backup,
        _connectivity = connectivity;

  Future<Response<S>> _backup<S extends Object>(
    Future<Response<S>> Function(DataSource<T> source) callback,
  ) async {
    try {
      if (optional == null) return Response(status: Status.undefined);
      if (isLocalDB) {
        final connected = await isConnected;
        if (!connected) return Response(status: Status.networkError);
      }
      return callback(optional!);
    } catch (error) {
      return Response(status: Status.failure, error: error.toString());
    }
  }

  Future<Response<S>> _execute<S extends Object>(
    Future<Response<S>> Function(DataSource<T> source) callback,
  ) async {
    try {
      if (!isLocalDB) {
        final connected = await isConnected;
        if (!connected) return Response(status: Status.networkError);
      }
      return callback(primary);
    } catch (error) {
      return Response(status: Status.failure, error: error.toString());
    }
  }

  Future<Response<T>> _modifier(
    DataModifiers modifierId,
    Future<Response<T>> Function() callback,
  ) async {
    try {
      return callback().then((value) => modifier(value, modifierId));
    } catch (error) {
      return Response(status: Status.failure, error: error.toString());
    }
  }

  Stream<Response<S>> _stream<S extends Object>(
    Stream<Response<S>> Function(DataSource<T> source) callback,
  ) async* {
    try {
      yield* callback(primary);
    } catch (error) {
      yield Response(status: Status.failure, error: error.toString());
    }
  }

  Stream<Response<T>> _streamModifier(
    DataModifiers modifierId,
    Stream<Response<T>> Function() callback,
  ) {
    return callback().asyncMap((value) {
      return modifier(value, modifierId);
    });
  }

  Future<Response<T>> modifier(
    Response<T> value,
    DataModifiers modifier,
  ) async {
    return value;
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
    bool merge = true,
    bool? createRefs,
    bool? countable,
    bool resolveRefs = false,
    List<String> ignorableResolverFields = const [],
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.checkById, () async {
      final feedback = await _execute((source) {
        return source.checkById(
          id,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
      if (feedback.isValid || !isBackupMode(backupMode)) return feedback;
      final backup = await _backup((source) {
        return source.checkById(
          id,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
      if (backup.isValid) {
        if (isLazyMode(lazyMode)) {
          _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        } else {
          await _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        }
      }
      return backup;
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
    List<String> ignorableResolverFields = const [],
    bool deleteRefs = false,
    bool counter = false,
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.clear, () async {
      if (isBackupMode(backupMode)) {
        if (isLazyMode(lazyMode)) {
          _backup((source) {
            return source.clear(
              params: params,
              counter: counter,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              deleteRefs: deleteRefs,
            );
          });
        } else {
          await _backup((source) {
            return source.clear(
              params: params,
              counter: counter,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              deleteRefs: deleteRefs,
            );
          });
        }
      }
      return _execute((source) {
        return source.clear(
          params: params,
          counter: counter,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
          deleteRefs: deleteRefs,
        );
      });
    });
  }

  /// Method to count data with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// repository.count(
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<int>> count({
    DataFieldParams? params,
    bool? backupMode,
  }) async {
    final feedback = await _execute((source) {
      return source.count(params: params);
    });
    if (feedback.isValid || !isBackupMode(backupMode)) return feedback;
    final backup = await _backup((source) {
      return source.count(params: params);
    });
    return feedback.copyWith(data: backup.data);
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
    T data, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
    bool? lazyMode,
    bool? backupMode,
  }) {
    return createById(
      data.id,
      data.filtered,
      params: params,
      merge: merge,
      createRefs: createRefs,
      lazyMode: lazyMode,
      backupMode: backupMode,
    );
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
  Future<Response<T>> createById(
    String id,
    Map<String, dynamic> data, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.create, () async {
      if (isBackupMode(backupMode)) {
        if (isLazyMode(lazyMode)) {
          _backup((source) {
            return source.create(
              id,
              data,
              params: params,
              createRefs: createRefs,
              merge: merge,
            );
          });
        } else {
          await _backup((source) {
            return source.create(
              id,
              data,
              params: params,
              createRefs: createRefs,
              merge: merge,
            );
          });
        }
      }
      return _execute((source) {
        return source.create(
          id,
          data,
          params: params,
          createRefs: createRefs,
          merge: merge,
        );
      });
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
    Iterable<T> data, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
    bool? lazyMode,
    bool? backupMode,
  }) {
    return createByWriters(
      data.map((e) => DataWriter(id: e.id, data: e.filtered)),
      params: params,
      merge: merge,
      createRefs: createRefs,
      lazyMode: lazyMode,
      backupMode: backupMode,
    );
  }

  /// Method to create multiple data entries with optional data source builder.
  ///
  /// Example:
  /// ```dart
  /// List<T> newDataList = //...;
  /// repository.createByWriters(
  ///   newDataList,
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<Response<T>> createByWriters(
    Iterable<DataWriter> writers, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.creates, () async {
      if (isBackupMode(backupMode)) {
        if (isLazyMode(lazyMode)) {
          _backup((source) {
            return source.creates(
              writers,
              params: params,
              merge: merge,
              createRefs: createRefs,
            );
          });
        } else {
          await _backup((source) {
            return source.creates(
              writers,
              params: params,
              merge: merge,
              createRefs: createRefs,
            );
          });
        }
      }
      return _execute((source) {
        return source.creates(
          writers,
          params: params,
          merge: merge,
          createRefs: createRefs,
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
    bool counter = false,
    bool deleteRefs = false,
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.deleteById, () async {
      if (isBackupMode(backupMode)) {
        if (isLazyMode(lazyMode)) {
          _backup((source) {
            return source.deleteById(
              id,
              params: params,
              counter: counter,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              deleteRefs: deleteRefs,
            );
          });
        } else {
          await _backup((source) {
            return source.deleteById(
              id,
              params: params,
              counter: counter,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              deleteRefs: deleteRefs,
            );
          });
        }
      }
      return _execute((source) {
        return source.deleteById(
          id,
          params: params,
          counter: counter,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
          deleteRefs: deleteRefs,
        );
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
    bool counter = false,
    bool deleteRefs = false,
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.deleteByIds, () async {
      if (isBackupMode(backupMode)) {
        if (isLazyMode(lazyMode)) {
          _backup((source) {
            return source.deleteByIds(
              ids,
              params: params,
              counter: counter,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              deleteRefs: deleteRefs,
            );
          });
        } else {
          await _backup((source) {
            return source.deleteByIds(
              ids,
              params: params,
              counter: counter,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              deleteRefs: deleteRefs,
            );
          });
        }
      }
      return _execute((source) {
        return source.deleteByIds(
          ids,
          params: params,
          counter: counter,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
          deleteRefs: deleteRefs,
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
    bool? countable,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
    bool? singletonMode,
  }) {
    return _modifier(DataModifiers.get, () async {
      final feedback = await DataCacheManager.i.cache(
        "GET",
        enabled: isSingletonMode(singletonMode),
        keyProps: [
          params,
          countable,
          onlyUpdates,
          resolveRefs,
          resolveDocChangesRefs,
          ...ignorableResolverFields,
        ],
        callback: () => _execute((source) {
          return source.get(
            params: params,
            countable: countable,
            resolveRefs: resolveRefs,
            resolveDocChangesRefs: resolveDocChangesRefs,
            ignorableResolverFields: ignorableResolverFields,
            onlyUpdates: onlyUpdates,
          );
        }),
      );
      if (feedback.isValid || !isBackupMode(backupMode)) return feedback;
      final backup = await _backup((source) {
        return source.get(
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          ignorableResolverFields: ignorableResolverFields,
          onlyUpdates: onlyUpdates,
        );
      });
      if (backup.isValid) {
        if (isLazyMode(lazyMode)) {
          _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        } else {
          await _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        }
      }
      return backup;
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
    bool? countable,
    bool resolveRefs = false,
    List<String> ignorableResolverFields = const [],
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? singletonMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.getById, () async {
      final feedback = await DataCacheManager.i.cache(
        "GET_BY_ID",
        enabled: isSingletonMode(singletonMode),
        keyProps: [
          id,
          params,
          countable,
          resolveRefs,
          ...ignorableResolverFields
        ],
        callback: () => _execute((source) {
          return source.getById(
            id,
            params: params,
            countable: countable,
            resolveRefs: resolveRefs,
            ignorableResolverFields: ignorableResolverFields,
          );
        }),
      );
      if (feedback.isValid || !isBackupMode(backupMode)) return feedback;
      final backup = await _backup((source) {
        return source.getById(
          id,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
      if (backup.isValid) {
        if (isLazyMode(lazyMode)) {
          _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        } else {
          await _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        }
      }
      return backup;
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
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
    bool? singletonMode,
  }) {
    return _modifier(DataModifiers.getByIds, () async {
      final feedback = await DataCacheManager.i.cache(
        "GET_BY_IDS",
        enabled: isSingletonMode(singletonMode),
        keyProps: [
          ...ids,
          params,
          resolveRefs,
          resolveDocChangesRefs,
          ...ignorableResolverFields,
        ],
        callback: () => _execute((source) {
          return source.getByIds(
            ids,
            params: params,
            countable: countable,
            resolveRefs: resolveRefs,
            resolveDocChangesRefs: resolveDocChangesRefs,
            ignorableResolverFields: ignorableResolverFields,
          );
        }),
      );
      if (feedback.isValid || !isBackupMode(backupMode)) return feedback;
      final backup = await _backup((source) {
        return source.getByIds(
          ids,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
      if (backup.isValid) {
        if (isLazyMode(lazyMode)) {
          _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        } else {
          await _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        }
      }
      return backup;
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
    bool? countable,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
    bool? singletonMode,
  }) {
    return _modifier(DataModifiers.getByQuery, () async {
      final feedback = await DataCacheManager.i.cache(
        "GET_BY_QUERY",
        enabled: isSingletonMode(singletonMode),
        keyProps: [
          params,
          ...queries,
          ...selections,
          ...sorts,
          options,
          countable,
          onlyUpdates,
          resolveRefs,
          resolveDocChangesRefs,
          ...ignorableResolverFields,
        ],
        callback: () => _execute((source) {
          return source.getByQuery(
            params: params,
            queries: queries,
            selections: selections,
            sorts: sorts,
            options: options,
            countable: countable,
            onlyUpdates: onlyUpdates,
            resolveRefs: resolveRefs,
            resolveDocChangesRefs: resolveDocChangesRefs,
            ignorableResolverFields: ignorableResolverFields,
          );
        }),
      );
      if (feedback.isValid || !isBackupMode(backupMode)) return feedback;
      final backup = await _backup((source) {
        return source.getByQuery(
          params: params,
          queries: queries,
          selections: selections,
          sorts: sorts,
          options: options,
          countable: countable,
          onlyUpdates: onlyUpdates,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
      if (backup.isValid) {
        if (isLazyMode(lazyMode)) {
          _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        } else {
          await _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        }
      }
      return backup;
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
    bool? countable,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) {
    return _streamModifier(DataModifiers.listen, () {
      return _stream((source) {
        return source.listen(
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          onlyUpdates: onlyUpdates,
          ignorableResolverFields: ignorableResolverFields,
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
    return _stream((source) {
      return source.listenCount(params: params, interval: interval);
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
    bool? countable,
    bool resolveRefs = false,
    List<String> ignorableResolverFields = const [],
  }) {
    return _streamModifier(DataModifiers.listenById, () {
      return _stream((source) {
        return source.listenById(
          id,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
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
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) {
    return _streamModifier(DataModifiers.listenByIds, () {
      return _stream((source) {
        return source.listenByIds(
          ids,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
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
    bool? countable,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
  }) {
    return _streamModifier(DataModifiers.listenByQuery, () {
      return _stream((source) {
        return source.listenByQuery(
          params: params,
          queries: queries,
          selections: selections,
          sorts: sorts,
          options: options,
          countable: countable,
          onlyUpdates: onlyUpdates,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
    });
  }

  /// Method to push offline data as online data and pull online data as offline data
  ///
  /// Example:
  /// ```dart
  /// repository.restore(
  ///   params: Params({"field1": "value1", "field2": "value2"}),
  /// );
  /// ```
  Future<void> restore({
    DataFieldParams? params,
    bool onlyUpdates = false,
    bool? countable,
    bool? resolveRefs,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
    bool createRefs = false,
    bool merge = true,
    bool? lazyMode,
  }) async {
    if (!restoreMode || !isBackupMode(backupMode)) return;
    final backup = await _backup((source) {
      return source.get(
        params: params,
        countable: countable,
        resolveRefs: resolveRefs ?? createRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        onlyUpdates: onlyUpdates,
        ignorableResolverFields: ignorableResolverFields,
      );
    });
    if (!backup.isValid) return;
    if (isLazyMode(lazyMode)) {
      _execute((source) {
        return source.creates(
          backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
          params: params,
          createRefs: createRefs,
          merge: merge,
        );
      });
    } else {
      await _execute((source) {
        return source.creates(
          backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
          params: params,
          createRefs: createRefs,
          merge: merge,
        );
      });
    }
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
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    List<String> ignorableResolverFields = const [],
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.search, () async {
      final feedback = await _execute((source) {
        return source.search(
          checker,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
      if (feedback.isValid || !isBackupMode(backupMode)) return feedback;
      final backup = await _backup((source) {
        return source.search(
          checker,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          ignorableResolverFields: ignorableResolverFields,
        );
      });
      if (backup.isValid) {
        if (isLazyMode(lazyMode)) {
          _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        } else {
          await _execute((source) {
            return source.creates(
              backup.result.map((e) => DataWriter(id: e.id, data: e.filtered)),
              params: params,
              createRefs: createRefs ?? resolveRefs,
              merge: merge,
            );
          });
        }
      }
      return backup;
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
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.updateById, () async {
      if (isBackupMode(backupMode)) {
        if (isLazyMode(lazyMode)) {
          _backup((source) {
            return source.updateById(
              id,
              data,
              params: params,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              updateRefs: updateRefs,
            );
          });
        } else {
          await _backup((source) {
            return source.updateById(
              id,
              data,
              params: params,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              updateRefs: updateRefs,
            );
          });
        }
      }
      return _execute((source) {
        return source.updateById(
          id,
          data,
          params: params,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
          updateRefs: updateRefs,
        );
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
    bool? lazyMode,
    bool? backupMode,
  }) {
    return _modifier(DataModifiers.updateByIds, () async {
      if (isBackupMode(backupMode)) {
        if (isLazyMode(lazyMode)) {
          _backup((source) {
            return source.updateByIds(
              updates,
              params: params,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              updateRefs: updateRefs,
            );
          });
        } else {
          await _backup((source) {
            return source.updateByIds(
              updates,
              params: params,
              resolveRefs: resolveRefs,
              ignorableResolverFields: ignorableResolverFields,
              updateRefs: updateRefs,
            );
          });
        }
      }
      return _execute((source) {
        return source.updateByIds(
          updates,
          params: params,
          resolveRefs: resolveRefs,
          ignorableResolverFields: ignorableResolverFields,
          updateRefs: updateRefs,
        );
      });
    });
  }
}

///
/// You can use [Data] without [Entity]
///
class LocalDataRepository<T extends Entity> extends DataRepository<T> {
  /// Constructor for creating a [RemoteDataRepository] implement.
  ///
  /// Parameters:
  /// - [source]: The primary remote data source. Ex: [LocalDataSourceImpl].
  /// - [backup]: An optional local backup or cache data source. Ex: [ApiDataSource], [FirestoreDataSource], and [RealtimeDataSource].
  ///
  const LocalDataRepository({
    super.id,
    required super.source,
    super.backup,
    super.connectivity,
    super.lazyMode,
    super.backupMode,
    super.restoreMode,
    super.singletonMode,
  }) : super.local();
}

///
/// You can use [Data] without [Entity]
///
class RemoteDataRepository<T extends Entity> extends DataRepository<T> {
  /// Constructor for creating a [RemoteDataRepository] implement.
  ///
  /// Parameters:
  /// - [source]: The primary remote data source. Ex: [ApiDataSource], [FirestoreDataSource], and [RealtimeDataSource].
  /// - [backup]: An optional local backup or cache data source. Ex: [LocalDataSourceImpl].
  ///
  const RemoteDataRepository({
    super.id,
    required super.source,
    super.backup,
    super.connectivity,
    super.backupMode,
    super.lazyMode,
    super.restoreMode,
    super.singletonMode,
  }) : super.remote();
}
