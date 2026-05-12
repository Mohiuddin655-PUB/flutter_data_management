import 'dart:async' show Completer;
import 'dart:collection' show Queue;

import '../encryptor/encryptor.dart' show DataEncryptor;
import '../utils/checker.dart' show Checker;
import '../utils/fetch_options.dart' show DataFetchOptions;
import '../utils/field_value_reader.dart'
    show
        DataFieldValueReaderType,
        DataFieldValueQueryOptions,
        DataFieldValueReader;
import '../utils/field_value_writer.dart'
    show DataFieldValueWriter, DataFieldValueWriterType;
import '../utils/query.dart' show DataQuery;
import '../utils/selection.dart' show DataSelection;
import '../utils/set_options.dart' show DataSetOptions;
import '../utils/sorting.dart' show DataSorting;
import 'batch.dart' show DataWriteBatch;
import 'delegate.dart' show DataDelegate;
import 'error_delegate.dart' show ErrorDelegate;
import 'exception.dart' show DataOperationError;
import 'snapshots.dart'
    show DataAggregateSnapshot, DataGetsSnapshot, DataGetSnapshot;
import 'typedefs.dart' show Ignore;
import 'writers.dart'
    show DataUpdateWriter, DataSetWriter, DataBatchWriter, DataDeleteWriter;

part '_cascade_delete_collector.dart';
part '_create_mixin.dart';
part '_delete_mixin.dart';
part '_error_handling_mixin.dart';
part '_hydrate_mixin.dart';
part '_listen_mixin.dart';
part '_query_mixin.dart';
part '_read_mixin.dart';
part '_read_resolve_mixin.dart';
part '_semaphore.dart';
part '_update_mixin.dart';
part '_write_batch_mixin.dart';
part '_write_encrypt_mixin.dart';
part '_write_transform_mixin.dart';

class DataOperation
    with
        _ErrorHandlingMixin,
        _WriteTransformMixin,
        _ReadMixin,
        _ReadResolveMixin,
        _HydrateMixin,
        _CreateMixin,
        _UpdateMixin,
        _DeleteMixin,
        _QueryMixin,
        _ListenMixin,
        _WriteEncryptMixin,
        _WriteBatchMixin {
  @override
  final DataDelegate delegate;

  @override
  final ErrorDelegate errorDelegate;

  @override
  final DataOperationSemaphore refSemaphore;

  DataOperation(
    this.delegate, {
    ErrorDelegate? errorDelegate,
    int refConcurrency = 16,
  })  : errorDelegate = errorDelegate ?? ErrorDelegate.printing,
        refSemaphore = DataOperationSemaphore(refConcurrency);

  @override
  Future<int?> count(String path) => _guardAsync<int?>(
        () => delegate.onCount(path),
        operation: 'count',
        path: path,
      );

  Future<void> create(
    String path,
    Map<String, dynamic> data, {
    bool merge = true,
    bool createRefs = false,
  }) =>
      _doCreate(path, data, merge: merge, createRefs: createRefs);

  Future<void> update(
    String path,
    Map<String, dynamic> data, {
    bool updateRefs = false,
  }) =>
      _doUpdate(path, data, updateRefs: updateRefs);

  Future<void> delete(
    String path, {
    bool counter = false,
    bool deleteRefs = false,
    Ignore? ignore,
    int batchLimit = 500,
    int? batchMaxLimit,
  }) =>
      _doDelete(
        path,
        counter: counter,
        deleteRefs: deleteRefs,
        ignore: ignore,
        batchLimit: batchLimit,
        batchMaxLimit: batchMaxLimit,
      );

  Future<DataGetsSnapshot> get(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) =>
      _doGet(
        path,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      );

  @override
  Future<DataGetSnapshot> getById(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    Ignore? ignore,
  }) =>
      _doGetById(
        path,
        countable: countable,
        resolveRefs: resolveRefs,
        ignore: ignore,
      );

  @override
  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) =>
      _doGetByQuery(
        path,
        queries: queries,
        selections: selections,
        sorts: sorts,
        options: options,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      );

  Future<DataGetsSnapshot> search(
    String path,
    Checker checker, {
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) =>
      _doSearch(
        path,
        checker,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      );

  Stream<DataGetsSnapshot> listen(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) =>
      _doListen(
        path,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      );

  Stream<DataGetSnapshot> listenById(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    Ignore? ignore,
  }) =>
      _doListenById(
        path,
        countable: countable,
        resolveRefs: resolveRefs,
        ignore: ignore,
      );

  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) =>
      _doListenByQuery(
        path,
        queries: queries,
        selections: selections,
        sorts: sorts,
        options: options,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      );

  Stream<DataAggregateSnapshot> listenCount(String path) {
    return _doListenCount(path);
  }

  Future<void> write(List<DataBatchWriter> writers, DataEncryptor? encryptor) {
    return _doWrite(writers, encryptor);
  }
}
