part of 'base.dart';

mixin _QueryMixin on _ErrorHandlingMixin, _HydrateMixin {
  DataDelegate get delegate;

  Future<DataGetsSnapshot> _doGet(
    String path, {
    required bool countable,
    required bool resolveRefs,
    required bool resolveDocChangesRefs,
    required Ignore? ignore,
  }) async {
    final data = await _guardAsync<DataGetsSnapshot>(
      () => delegate.onGet(path),
      operation: 'get',
      path: path,
    );
    return _hydrateMany(
      data,
      countable: countable,
      resolveRefs: resolveRefs,
      resolveDocChangesRefs: resolveDocChangesRefs,
      ignore: ignore,
    );
  }

  Future<DataGetSnapshot> _doGetById(
    String path, {
    required bool countable,
    required bool resolveRefs,
    required Ignore? ignore,
  }) async {
    final data = await _guardAsync<DataGetSnapshot>(
      () => delegate.onGetById(path),
      operation: 'getById',
      path: path,
    );
    return _hydrateOne(
      data,
      countable: countable,
      resolveRefs: resolveRefs,
      ignore: ignore,
    );
  }

  Future<DataGetsSnapshot> _doGetByQuery(
    String path, {
    required Iterable<DataQuery> queries,
    required Iterable<DataSelection> selections,
    required Iterable<DataSorting> sorts,
    required DataFetchOptions options,
    required bool countable,
    required bool resolveRefs,
    required bool resolveDocChangesRefs,
    required Ignore? ignore,
  }) async {
    final data = await _guardAsync<DataGetsSnapshot>(
      () => delegate.onGetByQuery(
        path,
        queries: queries,
        selections: selections,
        sorts: sorts,
        options: options,
      ),
      operation: 'getByQuery',
      path: path,
    );
    return _hydrateMany(
      data,
      countable: countable,
      resolveRefs: resolveRefs,
      resolveDocChangesRefs: resolveDocChangesRefs,
      ignore: ignore,
    );
  }

  Future<DataGetsSnapshot> _doSearch(
    String path,
    Checker checker, {
    required bool countable,
    required bool resolveRefs,
    required bool resolveDocChangesRefs,
    required Ignore? ignore,
  }) async {
    final data = await _guardAsync<DataGetsSnapshot>(
      () => delegate.onSearch(path, checker),
      operation: 'search',
      path: path,
    );
    return _hydrateMany(
      data,
      countable: countable,
      resolveRefs: resolveRefs,
      resolveDocChangesRefs: resolveDocChangesRefs,
      ignore: ignore,
    );
  }
}
