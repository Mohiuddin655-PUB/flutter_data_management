import '../utils/checker.dart' show Checker;
import '../utils/fetch_options.dart' show DataFetchOptions;
import '../utils/query.dart' show DataQuery;
import '../utils/selection.dart' show DataSelection;
import '../utils/sorting.dart' show DataSorting;
import 'batch.dart' show DataWriteBatch;
import 'snapshots.dart'
    show DataGetsSnapshot, DataGetSnapshot, DataAggregateSnapshot;

abstract class DataDelegate {
  const DataDelegate();

  DataWriteBatch batch();

  DataWriteBatch onBatch() => batch();

  Object resolveFieldPath(Object field, String documentId) => field;

  Object onResolveFieldPath(Object field, String documentId) {
    return resolveFieldPath(field, documentId);
  }

  Object? resolveFieldValue(Object? value) => value;

  Object? onResolveFieldValue(Object? value) => resolveFieldValue(value);

  Future<int?> count(String path);

  Future<int?> onCount(String path) => count(path);

  Future<void> create(
    String path,
    Map<String, dynamic> data, [
    bool merge = true,
  ]);

  Future<void> onCreate(
    String path,
    Map<String, dynamic> data, [
    bool merge = true,
  ]) =>
      create(path, data, merge);

  Future<void> delete(String path);

  Future<void> onDelete(String path) => delete(path);

  Future<DataGetsSnapshot> get(String path);

  Future<DataGetsSnapshot> onGet(String path) => get(path);

  Future<DataGetSnapshot> getById(String path);

  Future<DataGetSnapshot> onGetById(String path) => getById(path);

  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  });

  Future<DataGetsSnapshot> onGetByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  }) {
    return getByQuery(
      path,
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    );
  }

  Stream<DataGetsSnapshot> listen(String path);

  Stream<DataGetsSnapshot> onListen(String path) => listen(path);

  Stream<DataAggregateSnapshot> listenCount(String path);

  Stream<DataAggregateSnapshot> onListenCount(String path) => listenCount(path);

  Stream<DataGetSnapshot> listenById(String path);

  Stream<DataGetSnapshot> onListenById(String path) => listenById(path);

  Stream<DataGetsSnapshot> listenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  });

  Stream<DataGetsSnapshot> onListenByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
  }) {
    return listenByQuery(
      path,
      queries: queries,
      selections: selections,
      sorts: sorts,
      options: options,
    );
  }

  Future<DataGetsSnapshot> search(String path, Checker checker);

  Future<DataGetsSnapshot> onSearch(String path, Checker checker) {
    return search(path, checker);
  }

  Future<void> update(String path, Map<String, dynamic> data);

  Future<void> onUpdate(String path, Map<String, dynamic> data) {
    return update(path, data);
  }
}
