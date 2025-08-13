import 'package:flutter_entity/flutter_entity.dart';

import '../core/configs.dart';
import '../core/checker.dart';
import '../core/updating_info.dart';
import '../core/encryptor.dart';
import '../core/errors.dart';

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
  final DataEncryptor? encryptor;

  bool get isEncryptor => encryptor.isValid;

  const DataSource({
    this.encryptor,
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
    throw const DataSourceException('checkById method is not implemented');
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
    throw const DataSourceException('clear method is not implemented');
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
    throw const DataSourceException('count method is not implemented');
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
    throw const DataSourceException('create method is not implemented');
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
    throw const DataSourceException('creates method is not implemented');
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
    throw const DataSourceException('deleteById method is not implemented');
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
    throw const DataSourceException('deleteByIds method is not implemented');
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
    throw const DataSourceException('get method is not implemented');
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
    throw const DataSourceException('getById method is not implemented');
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
    throw const DataSourceException('getByIds method is not implemented');
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
    throw const DataSourceException('getByQuery method is not implemented');
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
    throw const DataSourceException('listen method is not implemented');
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
    throw const DataSourceException('listenById method is not implemented');
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
    throw const DataSourceException('listenByIds method is not implemented');
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
    throw const DataSourceException('listenByQuery method is not implemented');
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
    throw const DataSourceException('checkByQuery method is not implemented');
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
    throw const DataSourceException('updateById method is not implemented');
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
    throw const DataSourceException('updateByIds method is not implemented');
  }

  T build(dynamic source);
}
