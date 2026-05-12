part of 'base.dart';

mixin _ListenMixin on _ErrorHandlingMixin, _HydrateMixin {
  DataDelegate get delegate;

  Stream<DataGetsSnapshot> _doListen(
    String path, {
    required bool countable,
    required bool resolveRefs,
    required bool resolveDocChangesRefs,
    required Ignore? ignore,
  }) {
    return _guardStream(
      () => delegate.onListen(path),
      operation: 'listen',
      path: path,
      empty: DataGetsSnapshot(),
    ).asyncMap(
      (data) => _hydrateMany(
        data,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      ),
    );
  }

  Stream<DataAggregateSnapshot> _doListenCount(String path) {
    return _guardStream(
      () => delegate.onListenCount(path),
      operation: 'listenCount',
      path: path,
      empty: const DataAggregateSnapshot(),
    );
  }

  Stream<DataGetSnapshot> _doListenById(
    String path, {
    required bool countable,
    required bool resolveRefs,
    required Ignore? ignore,
  }) {
    return _guardStream(
      () => delegate.onListenById(path),
      operation: 'listenById',
      path: path,
      empty: DataGetSnapshot(),
    ).asyncMap(
      (data) => _hydrateOne(
        data,
        countable: countable,
        resolveRefs: resolveRefs,
        ignore: ignore,
      ),
    );
  }

  Stream<DataGetsSnapshot> _doListenByQuery(
    String path, {
    required Iterable<DataQuery> queries,
    required Iterable<DataSelection> selections,
    required Iterable<DataSorting> sorts,
    required DataFetchOptions options,
    required bool countable,
    required bool resolveRefs,
    required bool resolveDocChangesRefs,
    required Ignore? ignore,
  }) {
    return _guardStream(
      () => delegate.onListenByQuery(
        path,
        queries: queries,
        selections: selections,
        sorts: sorts,
        options: options,
      ),
      operation: 'listenByQuery',
      path: path,
      empty: DataGetsSnapshot(),
    ).asyncMap(
      (data) => _hydrateMany(
        data,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      ),
    );
  }
}
