part of 'base.dart';

mixin _RepoReadMixin<T extends Entity>
    on
        _RepoExecutorMixin<T>,
        _RepoModifierMixin<T>,
        _RepoReadWithFallbackMixin<T> {
  // ---------------------------------------------------------------------------
  // checkById
  // ---------------------------------------------------------------------------

  /// Checks whether a document exists at `<sourcePath>/<id>` and returns it
  /// if found.
  ///
  /// Unlike [getById], [checkById] is designed for existence checks combined
  /// with optional auto-creation: if the document is missing and [createRefs]
  /// is `true`, the backing [_readWithFallback] will attempt to sync the
  /// result to the backup source after a successful read.
  ///
  /// Returns [Status.invalidId] immediately when [id] is empty.
  /// Returns [Status.notFound] when no document exists at the path.
  /// Returns [Status.ok] with the hydrated entity on success.
  ///
  /// ```dart
  /// // 1. Basic existence check
  /// final result = await repo.checkById('u1');
  /// if (result.isSuccessful) {
  ///   print(result.data); // User entity
  /// }
  ///
  /// // 2. Check and resolve @-reference fields inline
  /// final result = await repo.checkById('u1', resolveRefs: true);
  /// // '@profile' field is hydrated into 'profile' map automatically
  ///
  /// // 3. Check with countable #-fields resolved to integers
  /// final result = await repo.checkById('u1', countable: true);
  /// // '#posts' field becomes 'posts': 5
  ///
  /// // 4. Check using a dynamic path
  /// final result = await repo.checkById(
  ///   'u1',
  ///   params: KeyParams({'orgId': 'org42'}),
  ///   // source path 'orgs/{orgId}/users' → 'orgs/org42/users/u1'
  /// );
  ///
  /// // 5. Force backup source when primary returns nothing
  /// final result = await repo.checkById('u1', backupMode: true);
  ///
  /// // 6. Mirror result to backup lazily after a successful primary read
  /// final result = await repo.checkById(
  ///   'u1',
  ///   backupMode: true,
  ///   lazyMode: true,
  /// );
  /// ```
  Future<Response<T>> checkById(
    String id, {
    DataFieldParams? params,
    bool merge = true,
    bool? createRefs,
    bool? countable,
    bool resolveRefs = false,
    Ignore? ignore,
    bool? lazyMode,
    bool? backupMode,
  }) {
    if (id.isEmpty) {
      return Future.value(Response(status: Status.invalidId));
    }
    return _readWithFallback(
      modifierId: DataModifiers.checkById,
      params: params,
      createRefs: createRefs,
      resolveRefs: resolveRefs,
      merge: merge,
      lazyMode: lazyMode,
      backupMode: backupMode,
      read: (source) => source.checkById(
        id,
        params: params,
        countable: countable,
        resolveRefs: resolveRefs,
        ignore: ignore,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // count
  // ---------------------------------------------------------------------------

  /// Returns the total number of documents in the source collection,
  /// optionally scoped by [params].
  ///
  /// Falls back to the backup source when the primary returns an invalid
  /// response and [backupMode] resolves to `true`.
  ///
  /// Returns [Status.ok] with [Response.data] set to the count integer.
  ///
  /// ```dart
  /// // 1. Count all documents in the collection
  /// final result = await repo.count();
  /// print(result.data); // e.g. 42
  ///
  /// // 2. Count within a dynamic sub-collection
  /// final result = await repo.count(
  ///   params: KeyParams({'userId': 'u1'}),
  ///   // source path 'users/{userId}/posts' → counts posts of u1
  /// );
  ///
  /// // 3. Use backup count when primary is unavailable
  /// final result = await repo.count(backupMode: true);
  /// ```
  Future<Response<int>> count({DataFieldParams? params, bool? backupMode}) {
    return _applyModifier<int>(DataModifiers.count, () async {
      final feedback = await _runOnPrimary(
        (source) => source.count(params: params),
      );
      if (feedback.isValid || !_shouldUseBackup(backupMode)) return feedback;
      return _runOnBackup((source) => source.count(params: params));
    });
  }

  // ---------------------------------------------------------------------------
  // get
  // ---------------------------------------------------------------------------

  /// Fetches all documents in the source collection, optionally scoped by
  /// [params].
  ///
  /// When [resolveRefs] is `true` every `@`-prefixed field in each document
  /// is replaced with the full document it references.
  /// When [countable] is `true` every `#`-prefixed field is replaced with
  /// the live integer count of the referenced collection.
  /// When [onlyUpdates] is `true` the response contains only documents that
  /// changed since the last fetch (uses `docChanges` instead of `docs`).
  ///
  /// Results are optionally cached in memory when [cacheMode] is `true` (or
  /// the repository default). The cache key is built from [cacheKey] +
  /// [params] + relevant option flags.
  ///
  /// ```dart
  /// // 1. Fetch all documents
  /// final result = await repo.get();
  /// for (final user in result.result) { print(user.name); }
  ///
  /// // 2. Fetch and hydrate @-reference fields
  /// final result = await repo.get(resolveRefs: true);
  /// // Each entity's '@profile' becomes a nested 'profile' map
  ///
  /// // 3. Fetch and resolve #-count fields
  /// final result = await repo.get(countable: true);
  /// // Each entity's '#posts' becomes 'posts': <int>
  ///
  /// // 4. Fetch only changed documents (delta)
  /// final result = await repo.get(onlyUpdates: true);
  ///
  /// // 5. Scoped fetch via dynamic path
  /// final result = await repo.get(
  ///   params: KeyParams({'orgId': 'org42'}),
  ///   // source path 'orgs/{orgId}/users' → fetches all users in org42
  /// );
  ///
  /// // 6. Cache the result in memory for subsequent calls
  /// final result = await repo.get(cacheMode: true);
  ///
  /// // 7. Fall back to backup when primary returns nothing
  /// final result = await repo.get(backupMode: true);
  ///
  /// // 8. Sync result to backup lazily after a successful primary read
  /// final result = await repo.get(backupMode: true, lazyMode: true);
  /// ```
  Future<Response<T>> get({
    DataFieldParams? params,
    bool? countable,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
    bool? cacheMode,
  }) {
    return _readWithFallback(
      modifierId: DataModifiers.get,
      params: params,
      createRefs: createRefs,
      resolveRefs: resolveRefs,
      merge: merge,
      lazyMode: lazyMode,
      backupMode: backupMode,
      cacheMode: cacheMode,
      cacheKey: 'GET',
      cacheKeyProps: [
        params,
        countable,
        onlyUpdates,
        resolveRefs,
        resolveDocChangesRefs,
      ],
      read: (source) => source.get(
        params: params,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
        onlyUpdates: onlyUpdates,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // getById
  // ---------------------------------------------------------------------------

  /// Fetches a single document at `<sourcePath>/<id>`.
  ///
  /// Returns [Status.invalidId] immediately when [id] is empty.
  /// Returns [Status.notFound] when no document exists.
  /// Returns [Status.ok] with the hydrated entity on success.
  ///
  /// When [resolveRefs] is `true`, `@`-prefixed fields are replaced with the
  /// full documents they point to (up to 8 levels deep, concurrency-limited
  /// by [DataOperation.refSemaphore]).
  ///
  /// When [countable] is `true`, `#`-prefixed fields are replaced with the
  /// live document count of the referenced collection.
  ///
  /// Results are cached per `(T, 'GET_BY_ID', id, params, countable,
  /// resolveRefs)` key when [cacheMode] resolves to `true`.
  ///
  /// ```dart
  /// // 1. Simple fetch
  /// final result = await repo.getById('u1');
  /// print(result.data?.name);
  ///
  /// // 2. Hydrate @-reference fields
  /// final result = await repo.getById('u1', resolveRefs: true);
  /// // user.filtered == {'name': 'Alice', 'profile': {'bio': '...'}}
  ///
  /// // 3. Hydrate #-count fields
  /// final result = await repo.getById('u1', countable: true);
  /// // user.filtered == {'name': 'Alice', 'posts': 7}
  ///
  /// // 4. Combined hydration
  /// final result = await repo.getById(
  ///   'u1',
  ///   resolveRefs: true,
  ///   countable: true,
  /// );
  ///
  /// // 5. Ignore a specific field during ref resolution
  /// final result = await repo.getById(
  ///   'u1',
  ///   resolveRefs: true,
  ///   ignore: (key, _) => key == '@avatar',
  /// );
  ///
  /// // 6. Dynamic path resolution
  /// final result = await repo.getById(
  ///   'u1',
  ///   params: KeyParams({'orgId': 'org42'}),
  /// );
  ///
  /// // 7. Cache the result
  /// final result = await repo.getById('u1', cacheMode: true);
  ///
  /// // 8. Fallback to backup
  /// final result = await repo.getById('u1', backupMode: true);
  ///
  /// // 9. Sync result to backup after successful primary read
  /// final result = await repo.getById(
  ///   'u1',
  ///   backupMode: true,
  ///   lazyMode: true,
  /// );
  /// ```
  Future<Response<T>> getById(
    String id, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    Ignore? ignore,
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? cacheMode,
    bool? backupMode,
  }) {
    if (id.isEmpty) {
      return Future.value(Response(status: Status.invalidId));
    }
    return _readWithFallback(
      modifierId: DataModifiers.getById,
      params: params,
      createRefs: createRefs,
      resolveRefs: resolveRefs,
      merge: merge,
      lazyMode: lazyMode,
      backupMode: backupMode,
      cacheMode: cacheMode,
      cacheKey: 'GET_BY_ID',
      cacheKeyProps: [id, params, countable, resolveRefs],
      read: (source) => source.getById(
        id,
        params: params,
        countable: countable,
        resolveRefs: resolveRefs,
        ignore: ignore,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // getByIds
  // ---------------------------------------------------------------------------

  /// Fetches multiple documents by their IDs in a single operation.
  ///
  /// When the number of IDs exceeds [DataLimitations.whereIn] the call is
  /// automatically split into individual [getById] calls executed in parallel.
  /// Otherwise a single `whereIn` query is issued against the source.
  ///
  /// IDs are sorted before building the cache key so that
  /// `getByIds(['b','a'])` and `getByIds(['a','b'])` share the same cache
  /// entry.
  ///
  /// Returns [Status.invalid] immediately for an empty [ids] list.
  /// Returns [Status.ok] when every ID is found, [Status.canceled] for
  /// partial success.
  ///
  /// ```dart
  /// // 1. Fetch three users at once
  /// final result = await repo.getByIds(['u1', 'u2', 'u3']);
  /// for (final user in result.result) { print(user.name); }
  ///
  /// // 2. Fetch with @-reference hydration
  /// final result = await repo.getByIds(
  ///   ['u1', 'u2'],
  ///   resolveRefs: true,
  /// );
  ///
  /// // 3. Fetch with #-count hydration
  /// final result = await repo.getByIds(
  ///   ['u1', 'u2'],
  ///   countable: true,
  /// );
  ///
  /// // 4. Fetch using a dynamic sub-collection path
  /// final result = await repo.getByIds(
  ///   ['p1', 'p2'],
  ///   params: KeyParams({'userId': 'u1'}),
  ///   // source path 'users/{userId}/posts' → fetches p1 and p2
  /// );
  ///
  /// // 5. Cache the result
  /// final result = await repo.getByIds(
  ///   ['u1', 'u2', 'u3'],
  ///   cacheMode: true,
  /// );
  ///
  /// // 6. Fallback to backup when primary is unavailable
  /// final result = await repo.getByIds(
  ///   ['u1', 'u2'],
  ///   backupMode: true,
  ///   lazyMode: true,
  /// );
  /// ```
  Future<Response<T>> getByIds(
    Iterable<String> ids, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
    bool? cacheMode,
  }) {
    if (ids.isEmpty) {
      return Future.value(Response(status: Status.invalid));
    }
    final stableIds = ids.toList()..sort();
    return _readWithFallback(
      modifierId: DataModifiers.getByIds,
      params: params,
      createRefs: createRefs,
      resolveRefs: resolveRefs,
      merge: merge,
      lazyMode: lazyMode,
      backupMode: backupMode,
      cacheMode: cacheMode,
      cacheKey: 'GET_BY_IDS',
      cacheKeyProps: [...stableIds, params, resolveRefs, resolveDocChangesRefs],
      read: (source) => source.getByIds(
        ids,
        params: params,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // getByQuery
  // ---------------------------------------------------------------------------

  /// Fetches documents matching a set of [DataQuery] filters, [DataSelection]
  /// cursors, and [DataSorting] orderings.
  ///
  /// [DataQuery] fields are automatically resolved through the delegate's
  /// [DataDelegate.onResolveFieldPath] and [DataDelegate.onResolveFieldValue]
  /// so backend-native field path objects (e.g. Firestore's `FieldPath`) are
  /// produced transparently.
  ///
  /// Use [DataFetchOptions] to control pagination size and direction.
  ///
  /// ```dart
  /// // 1. Simple equality filter
  /// final result = await repo.getByQuery(
  ///   queries: [DataQuery('status', isEqualTo: 'active')],
  /// );
  ///
  /// // 2. Compound filter
  /// final result = await repo.getByQuery(
  ///   queries: [
  ///     DataQuery('published', isEqualTo: true),
  ///     DataQuery('views', isGreaterThan: 100),
  ///   ],
  ///   sorts: [DataSorting('createdAt', descending: true)],
  ///   options: DataFetchOptions.limit(20),
  /// );
  ///
  /// // 3. whereIn filter
  /// final result = await repo.getByQuery(
  ///   queries: [
  ///     DataQuery('category', whereIn: ['tech', 'science']),
  ///   ],
  /// );
  ///
  /// // 4. Filter by document ID using DataFieldPath.documentId
  /// final result = await repo.getByQuery(
  ///   queries: [
  ///     DataQuery(DataFieldPath.documentId, whereIn: ['p1', 'p2']),
  ///   ],
  /// );
  ///
  /// // 5. Array-contains filter
  /// final result = await repo.getByQuery(
  ///   queries: [
  ///     DataQuery('tags', arrayContains: 'flutter'),
  ///   ],
  /// );
  ///
  /// // 6. Cursor-based pagination (start after last doc snapshot)
  /// final result = await repo.getByQuery(
  ///   sorts: [DataSorting('createdAt', descending: true)],
  ///   options: DataFetchOptions.limit(10),
  ///   selections: [DataSelection.startAfterDocument(lastSnapshot)],
  /// );
  ///
  /// // 7. Resolve @-reference fields on results
  /// final result = await repo.getByQuery(
  ///   queries: [DataQuery('role', isEqualTo: 'admin')],
  ///   resolveRefs: true,
  /// );
  ///
  /// // 8. Get only changed documents (delta)
  /// final result = await repo.getByQuery(
  ///   queries: [DataQuery('active', isEqualTo: true)],
  ///   onlyUpdates: true,
  /// );
  ///
  /// // 9. Cache the query result
  /// final result = await repo.getByQuery(
  ///   queries: [DataQuery('status', isEqualTo: 'active')],
  ///   cacheMode: true,
  /// );
  ///
  /// // 10. Scoped to a dynamic collection path
  /// final result = await repo.getByQuery(
  ///   params: KeyParams({'userId': 'u1'}),
  ///   queries: [DataQuery('read', isEqualTo: false)],
  ///   sorts: [DataSorting('sentAt', descending: true)],
  ///   options: DataFetchOptions.limit(50),
  /// );
  ///
  /// // 11. Composite filter using DataFilter.and / DataFilter.or
  /// final result = await repo.getByQuery(
  ///   queries: [
  ///     DataQuery.filter(DataFilter.or([
  ///       DataFilter('status', isEqualTo: 'draft'),
  ///       DataFilter('status', isEqualTo: 'pending'),
  ///     ])),
  ///   ],
  /// );
  /// ```
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
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
    bool? cacheMode,
  }) {
    return _readWithFallback(
      modifierId: DataModifiers.getByQuery,
      params: params,
      createRefs: createRefs,
      resolveRefs: resolveRefs,
      merge: merge,
      lazyMode: lazyMode,
      backupMode: backupMode,
      cacheMode: cacheMode,
      cacheKey: 'GET_BY_QUERY',
      cacheKeyProps: [
        params,
        ...queries,
        ...selections,
        ...sorts,
        options,
        countable,
        onlyUpdates,
        resolveRefs,
        resolveDocChangesRefs,
      ],
      read: (source) => source.getByQuery(
        params: params,
        queries: queries,
        selections: selections,
        sorts: sorts,
        options: options,
        countable: countable,
        onlyUpdates: onlyUpdates,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // search
  // ---------------------------------------------------------------------------

  /// Performs a client-side or backend-assisted text search using a [Checker].
  ///
  /// [Checker.contains] — finds documents where the field value contains the
  /// search string (case handling depends on the delegate implementation).
  ///
  /// [Checker.equal] — finds documents where the field value exactly equals
  /// the search string.
  ///
  /// Returns [Status.invalid] immediately when [checker.field] is empty.
  /// Does **not** support cursor-based pagination — use [getByQuery] for that.
  ///
  /// ```dart
  /// // 1. Contains search on a name field
  /// final result = await repo.search(
  ///   Checker.contains('name', 'ali'),
  /// );
  /// // Returns all documents where 'name' contains 'ali'
  ///
  /// // 2. Exact-match search
  /// final result = await repo.search(
  ///   Checker.equal('email', 'alice@example.com'),
  /// );
  ///
  /// // 3. Search with @-reference hydration on results
  /// final result = await repo.search(
  ///   Checker.contains('title', 'flutter'),
  ///   resolveRefs: true,
  /// );
  ///
  /// // 4. Search within a dynamic sub-collection
  /// final result = await repo.search(
  ///   Checker.contains('body', 'offline'),
  ///   params: KeyParams({'userId': 'u1'}),
  ///   // source path 'users/{userId}/posts' → searches u1's posts
  /// );
  ///
  /// // 5. Search with #-count hydration
  /// final result = await repo.search(
  ///   Checker.contains('tag', 'dart'),
  ///   countable: true,
  /// );
  ///
  /// // 6. Fall back to backup when primary search yields nothing
  /// final result = await repo.search(
  ///   Checker.contains('name', 'bob'),
  ///   backupMode: true,
  /// );
  /// ```
  Future<Response<T>> search(
    Checker checker, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
    bool? createRefs,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
  }) {
    if (checker.field.isEmpty) {
      return Future.value(Response(status: Status.invalid));
    }
    return _readWithFallback(
      modifierId: DataModifiers.search,
      params: params,
      createRefs: createRefs,
      resolveRefs: resolveRefs,
      merge: merge,
      lazyMode: lazyMode,
      backupMode: backupMode,
      read: (source) => source.search(
        checker,
        params: params,
        countable: countable,
        resolveRefs: resolveRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        ignore: ignore,
      ),
    );
  }
}
