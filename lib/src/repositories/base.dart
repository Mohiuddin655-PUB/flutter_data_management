import 'package:flutter_entity/entity.dart';

import '../core/configs.dart';
import '../models/checker.dart';
import '../models/updating_info.dart';
import '../sources/base.dart';
import '../sources/local.dart';
import '../sources/remote.dart';
import '../utils/errors.dart';

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

abstract class DataRepository<T extends Entity> {
  final String? id;
  final bool lazy;

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

  /// Constructor for creating a [RemoteDataRepository] implement.
  ///
  /// Parameters:
  /// - [source]: The primary data source. Ex: [LocalDataSourceImpl], [ApiDataSource], [FirestoreDataSource], and [RealtimeDataSource].
  /// - [backup]: An optional data source. Ex: [LocalDataSourceImpl], [ApiDataSource], [FirestoreDataSource], and [RealtimeDataSource].
  ///
  const DataRepository.custom({
    this.id,
    this.lazy = true,
    required DataSource<T> source,
    DataSource<T>? backup,
    FutureConnectivityCallback? connectivity,
  })  : primary = source,
        optional = backup,
        _connectivity = connectivity;

  /// Constructor for creating a [RemoteDataRepository] implement.
  ///
  /// Parameters:
  /// - [source]: The primary local data source. Ex: [LocalDataSourceImpl].
  /// - [backup]: An optional remote data source. Ex: [ApiDataSource], [FirestoreDataSource], and [RealtimeDataSource].
  ///
  const DataRepository.local({
    this.id,
    this.lazy = true,
    required LocalDataSource<T> source,
    RemoteDataSource<T>? backup,
    FutureConnectivityCallback? connectivity,
  })  : primary = source,
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
    this.lazy = true,
    required RemoteDataSource<T> source,
    LocalDataSource<T>? backup,
    FutureConnectivityCallback? connectivity,
  })  : primary = source,
        optional = backup,
        _connectivity = connectivity;

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
    Object? args,
  }) {
    throw const DataRepositoryException('checkById method is not implemented');
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
    Object? args,
  }) {
    throw const DataRepositoryException('clear method is not implemented');
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
    Object? args,
  }) {
    throw const DataRepositoryException('count method is not implemented');
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
    Object? args,
  }) {
    throw const DataRepositoryException('create method is not implemented');
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
    List<T> data, {
    DataFieldParams? params,
    Object? args,
  }) {
    throw const DataRepositoryException('creates method is not implemented');
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
    Object? args,
  }) {
    throw const DataRepositoryException('deleteById method is not implemented');
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
    List<String> ids, {
    DataFieldParams? params,
    Object? args,
  }) {
    throw const DataRepositoryException(
      'deleteByIds method is not implemented',
    );
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
    Object? args,
  }) {
    throw const DataRepositoryException('get method is not implemented');
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
    Object? args,
  }) {
    throw const DataRepositoryException('getById method is not implemented');
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
    List<String> ids, {
    DataFieldParams? params,
    Object? args,
  }) {
    throw const DataRepositoryException('getByIds method is not implemented');
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
    List<DataQuery> queries = const [],
    List<DataSelection> selections = const [],
    List<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
    Object? args,
  }) {
    throw const DataRepositoryException('getByQuery method is not implemented');
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
    Object? args,
  }) {
    throw const DataRepositoryException('listen method is not implemented');
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
    Object? args,
  }) {
    throw const DataSourceException('listenCount method is not implemented');
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
    Object? args,
  }) {
    throw const DataRepositoryException('listenById method is not implemented');
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
    List<String> ids, {
    DataFieldParams? params,
    Object? args,
  }) {
    throw const DataRepositoryException(
      'listenByIds method is not implemented',
    );
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
    List<DataQuery> queries = const [],
    List<DataSelection> selections = const [],
    List<DataSorting> sorts = const [],
    DataPagingOptions options = const DataPagingOptions(),
    Object? args,
  }) {
    throw const DataRepositoryException(
      'listenByQuery method is not implemented',
    );
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
    Object? args,
  }) {
    throw const DataRepositoryException('search method is not implemented');
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
    Object? args,
  }) {
    throw const DataRepositoryException('updateById method is not implemented');
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
    List<UpdatingInfo> updates, {
    DataFieldParams? params,
    Object? args,
  }) {
    throw const DataRepositoryException(
      'updateByIds method is not implemented',
    );
  }
}
