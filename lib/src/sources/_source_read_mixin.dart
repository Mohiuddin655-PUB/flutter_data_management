part of 'base.dart';

mixin _SourceReadMixin<T extends Entity> on _SourceReadBaseMixin<T> {
  Future<Response<T>> checkById(
    String id, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    Ignore? ignore,
  }) {
    return _execute(() async {
      final p = _ref(params, DataModifiers.checkById, id);
      final data = await operation.getById(
        p,
        countable: countable ?? false,
        resolveRefs: resolveRefs,
        ignore: ignore,
      );
      if (!data.exists) return Response(status: Status.notFound);
      final v = await _decryptDoc(data.doc);
      return Response(
        status: Status.ok,
        data: build(v),
        snapshot: data.snapshot,
      );
    });
  }

  Future<Response<int>> count({DataFieldParams? params}) {
    return _execute(() async {
      final p = _ref(params, DataModifiers.count);
      final value = await operation.count(p);
      return Response(status: Status.ok, data: value);
    });
  }

  Future<Response<T>> get({
    DataFieldParams? params,
    bool onlyUpdates = false,
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) {
    return _execute(() async {
      final p = _ref(params, DataModifiers.get);
      final event = await operation.get(
        p,
        countable: countable ?? true,
        resolveRefs: resolveRefs && !onlyUpdates,
        resolveDocChangesRefs:
            resolveDocChangesRefs || (onlyUpdates && resolveRefs),
        ignore: ignore,
      );
      final docs = onlyUpdates ? event.docChanges : event.docs;
      if (docs.isEmpty) {
        return Response(status: Status.notFound, snapshot: event.snapshot);
      }
      final result = await _buildAll(docs);
      if (result.isEmpty) {
        return Response(status: Status.notFound, snapshot: event.snapshot);
      }
      return Response(
        result: result,
        snapshot: event.snapshot,
        status: Status.ok,
      );
    });
  }

  Future<Response<T>> getById(
    String id, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    Ignore? ignore,
  }) {
    if (id.isEmpty) return Future.value(Response(status: Status.invalidId));
    return _execute(() async {
      final p = _ref(params, DataModifiers.getById, id);
      final event = await operation.getById(
        p,
        countable: countable ?? true,
        resolveRefs: resolveRefs,
        ignore: ignore,
      );
      if (!event.exists) {
        return Response(status: Status.notFound, snapshot: event.snapshot);
      }
      final v = await _decryptDoc(event.doc);
      return Response(
        status: Status.ok,
        data: build(v),
        snapshot: event.snapshot,
      );
    });
  }

  Future<Response<T>> getByIds(
    Iterable<String> ids, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) {
    if (ids.isEmpty) return Future.value(Response(status: Status.invalid));
    return _execute(() async {
      if (limitations.whereIn > 0 && ids.length > limitations.whereIn) {
        final results = await Future.wait(
          ids.map(
            (e) => getById(
              e,
              countable: countable,
              params: params,
              resolveRefs: resolveRefs,
              ignore: ignore,
            ),
          ),
        );
        final ok = results.where((e) => e.isSuccessful);
        return Response(
          status: ok.length == ids.length ? Status.ok : Status.canceled,
          result: results.map((e) => e.data).whereType<T>().toList(),
        );
      }
      final p = _ref(params, DataModifiers.getByIds);
      final queries = [DataQuery(DataFieldPath.documentId, whereIn: ids)].map(
        (e) => e.adjust(
          documentId,
          delegate.onResolveFieldPath,
          delegate.onResolveFieldValue,
        ),
      );
      final event = await operation.getByQuery(
        p,
        countable: countable ?? true,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
        queries: queries,
      );
      if (event.docs.isEmpty) return Response(status: Status.notFound);
      final result = await _buildAll(event.docs);
      if (result.isEmpty) return Response(status: Status.notFound);
      return Response(status: Status.ok, result: result, snapshot: event);
    });
  }

  Future<Response<T>> getByQuery({
    DataFieldParams? params,
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
    bool? countable,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) {
    return _execute(() async {
      final p = _ref(params, DataModifiers.getByQuery);
      final adjustedQueries = queries.map(
        (e) => e.adjust(
          documentId,
          delegate.onResolveFieldPath,
          delegate.onResolveFieldValue,
        ),
      );
      final event = await operation.getByQuery(
        p,
        countable: countable ?? true,
        queries: adjustedQueries,
        selections: selections,
        sorts: sorts,
        options: options,
        resolveRefs: resolveRefs && !onlyUpdates,
        resolveDocChangesRefs:
            resolveDocChangesRefs || (onlyUpdates && resolveRefs),
        ignore: ignore,
      );
      final docs = onlyUpdates ? event.docChanges : event.docs;
      if (docs.isEmpty) {
        return Response(status: Status.notFound, snapshot: event.snapshot);
      }
      final result = await _buildAll(docs);
      if (result.isEmpty) {
        return Response(status: Status.notFound, snapshot: event.snapshot);
      }
      return Response(
        result: result,
        snapshot: event.snapshot,
        status: Status.ok,
      );
    });
  }

  Future<Response<T>> search(
    Checker checker, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) {
    if (checker.field.isEmpty) {
      return Future.value(Response(status: Status.invalid));
    }
    return _execute(() async {
      final p = _ref(params, DataModifiers.search);
      final event = await operation.search(
        p,
        checker,
        countable: countable ?? false,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      );
      if (event.docs.isEmpty) return Response(status: Status.notFound);
      final result = await _buildAll(event.docs);
      if (result.isEmpty) return Response(status: Status.notFound);
      return Response(status: Status.ok, result: result, snapshot: event);
    });
  }
}
