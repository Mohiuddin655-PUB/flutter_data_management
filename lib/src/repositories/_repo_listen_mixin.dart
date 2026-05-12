part of 'base.dart';

mixin _RepoListenMixin<T extends Entity>
    on _RepoExecutorMixin<T>, _RepoModifierMixin<T> {
  Stream<Response<S>> _streamWithFallback<S extends Object>(
    Stream<Response<S>> Function(DataSource<T> source) build,
  ) {
    if (isLocalDB || optional == null) {
      return _streamOnPrimary(build);
    }
    return _FallbackStream<T, S>(
      primary: primary,
      backup: optional!,
      resolveConnected: () => isConnected,
      connectivityChanges: () => DM.i.connectivityChanges,
      build: build,
      report: _report,
    ).stream;
  }

  // ---------------------------------------------------------------------------
  // listen
  // ---------------------------------------------------------------------------

  /// Returns a stream of all documents in the source collection, re-emitting
  /// whenever any document is added, modified, or removed.
  ///
  /// For a [RemoteDataRepository] with a local backup configured, the stream
  /// automatically switches between the remote and local source based on
  /// connectivity (via [_FallbackStream]), with a 300 ms debounce on
  /// transitions. For a [LocalDataRepository] or when no backup is configured,
  /// the stream is served exclusively from the primary source.
  ///
  /// When [resolveRefs] is `true` every `@`-prefixed field in each emitted
  /// document is replaced with the full document it references.
  /// When [countable] is `true` every `#`-prefixed field is replaced with the
  /// live integer count of the referenced collection.
  /// When [onlyUpdates] is `true` only changed documents (`docChanges`) are
  /// emitted per event rather than the full collection snapshot.
  ///
  /// Errors from the underlying source are caught and re-emitted as
  /// [Status.failure] response events rather than terminating the stream.
  ///
  /// ```dart
  /// // 1. Listen to the entire collection
  /// repo.listen().listen((response) {
  ///   if (response.isSuccessful) {
  ///     final users = response.result;
  ///     print('${users.length} users');
  ///   }
  /// });
  ///
  /// // 2. Listen with @-reference hydration on every emission
  /// repo.listen(resolveRefs: true).listen((response) {
  ///   // Each user entity has '@profile' replaced with full profile map
  /// });
  ///
  /// // 3. Listen with #-count hydration
  /// repo.listen(countable: true).listen((response) {
  ///   // Each user entity has '#posts' replaced with integer count
  /// });
  ///
  /// // 4. Listen to delta changes only (docChanges)
  /// repo.listen(onlyUpdates: true).listen((response) {
  ///   // Only documents that changed since last emission
  /// });
  ///
  /// // 5. Listen to a dynamic sub-collection via params
  /// repo.listen(
  ///   params: KeyParams({'orgId': 'org42'}),
  ///   // source path 'orgs/{orgId}/users' → listens to all users in org42
  /// ).listen((response) { ... });
  ///
  /// // 6. Ignore specific fields during ref resolution
  /// repo.listen(
  ///   resolveRefs: true,
  ///   ignore: (key, _) => key == '@avatar',
  /// ).listen((response) { ... });
  ///
  /// // 7. Use in a StreamBuilder widget
  /// StreamBuilder<Response<User>>(
  ///   stream: userRepo.listen(),
  ///   builder: (context, snapshot) {
  ///     final users = snapshot.data?.result ?? [];
  ///     return ListView(
  ///       children: users.map((u) => Text(u.name)).toList(),
  ///     );
  ///   },
  /// );
  ///
  /// // 8. Offline-aware: automatically falls back to local backup
  /// //    when connectivity is lost (RemoteDataRepository only)
  /// remoteRepo.listen().listen((response) {
  ///   // Seamlessly served from local backup when offline
  /// });
  /// ```
  Stream<Response<T>> listen({
    DataFieldParams? params,
    bool? countable,
    bool onlyUpdates = false,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) {
    return _applyStreamModifier<T>(DataModifiers.listen, () {
      return _streamWithFallback(
        (source) => source.listen(
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          onlyUpdates: onlyUpdates,
          ignore: ignore,
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // listenCount
  // ---------------------------------------------------------------------------

  /// Returns a stream of the live document count for the source collection,
  /// re-emitting whenever the count changes.
  ///
  /// Emits [Response.data] as an [int] on each event.
  /// Emits [Status.networkError] when the backend cannot resolve the count
  /// (e.g. the aggregate query is unsupported offline).
  ///
  /// ```dart
  /// // 1. Show live unread message count
  /// repo.listenCount().listen((response) {
  ///   final count = response.data ?? 0;
  ///   badge.update(count);
  /// });
  ///
  /// // 2. Listen to count of a dynamic sub-collection
  /// repo.listenCount(
  ///   params: KeyParams({'userId': 'u1'}),
  ///   // source path 'users/{userId}/notifications'
  /// ).listen((response) {
  ///   notificationBadge.value = response.data ?? 0;
  /// });
  ///
  /// // 3. Use in a StreamBuilder
  /// StreamBuilder<Response<int>>(
  ///   stream: postRepo.listenCount(
  ///     params: KeyParams({'userId': currentUserId}),
  ///   ),
  ///   builder: (context, snapshot) {
  ///     final count = snapshot.data?.data ?? 0;
  ///     return Text('$count posts');
  ///   },
  /// );
  /// ```
  Stream<Response<int>> listenCount({DataFieldParams? params}) {
    return _applyStreamModifier<int>(DataModifiers.listenCount, () {
      return _streamWithFallback(
        (source) => source.listenCount(params: params),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // listenById
  // ---------------------------------------------------------------------------

  /// Returns a stream for a single document at `<sourcePath>/<id>`,
  /// re-emitting whenever that document changes.
  ///
  /// Returns [Status.invalidId] immediately (as a single-event stream) when
  /// [id] is empty. Emits [Status.notFound] when the document does not exist
  /// or is deleted.
  ///
  /// When [resolveRefs] is `true` every `@`-prefixed field is hydrated on
  /// each emission. When [countable] is `true` every `#`-prefixed field is
  /// replaced with a live integer count.
  ///
  /// ```dart
  /// // 1. Listen to a single user document
  /// repo.listenById('u1').listen((response) {
  ///   if (response.isSuccessful) {
  ///     print(response.data?.name);
  ///   }
  /// });
  ///
  /// // 2. Listen with @-reference hydration
  /// repo.listenById('u1', resolveRefs: true).listen((response) {
  ///   // '@profile' is replaced with full profile map on every emission
  /// });
  ///
  /// // 3. Listen with #-count hydration
  /// repo.listenById('u1', countable: true).listen((response) {
  ///   // '#posts' is replaced with integer count on every emission
  /// });
  ///
  /// // 4. Listen to a document in a dynamic sub-collection
  /// repo.listenById(
  ///   'msg1',
  ///   params: KeyParams({'chatId': 'c1'}),
  ///   // source path 'chats/{chatId}/messages'
  /// ).listen((response) { ... });
  ///
  /// // 5. Ignore specific fields during ref resolution
  /// repo.listenById(
  ///   'u1',
  ///   resolveRefs: true,
  ///   ignore: (key, _) => key == '@settings',
  /// ).listen((response) { ... });
  ///
  /// // 6. Use in a StreamBuilder widget
  /// StreamBuilder<Response<User>>(
  ///   stream: userRepo.listenById(userId),
  ///   builder: (context, snapshot) {
  ///     final user = snapshot.data?.data;
  ///     if (user == null) return const CircularProgressIndicator();
  ///     return Text(user.name);
  ///   },
  /// );
  ///
  /// // 7. Offline-aware fallback (RemoteDataRepository with local backup)
  /// remoteRepo.listenById('u1').listen((response) {
  ///   // Served from local backup automatically when offline
  /// });
  /// ```
  Stream<Response<T>> listenById(
    String id, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    Ignore? ignore,
  }) {
    if (id.isEmpty) {
      return Stream.value(Response(status: Status.invalidId));
    }
    return _applyStreamModifier<T>(DataModifiers.listenById, () {
      return _streamWithFallback(
        (source) => source.listenById(
          id,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          ignore: ignore,
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // listenByIds
  // ---------------------------------------------------------------------------

  /// Returns a stream for multiple documents by their IDs, re-emitting a
  /// merged snapshot whenever any of the watched documents changes.
  ///
  /// Returns [Status.invalidId] immediately for an empty [ids] list.
  ///
  /// When the number of IDs exceeds [DataLimitations.whereIn] the call is
  /// split into individual [listenById] streams that are merged via
  /// [StreamGroup.merge]; results are accumulated in a local map keyed by
  /// entity id so each emission contains the latest known state of all IDs.
  /// Otherwise a single `whereIn` query stream is opened.
  ///
  /// ```dart
  /// // 1. Listen to several documents simultaneously
  /// repo.listenByIds(['u1', 'u2', 'u3']).listen((response) {
  ///   final users = response.result;
  ///   print('${users.length} users loaded');
  /// });
  ///
  /// // 2. Listen with @-reference hydration
  /// repo.listenByIds(
  ///   ['u1', 'u2'],
  ///   resolveRefs: true,
  /// ).listen((response) { ... });
  ///
  /// // 3. Listen with #-count hydration
  /// repo.listenByIds(
  ///   ['u1', 'u2'],
  ///   countable: true,
  /// ).listen((response) { ... });
  ///
  /// // 4. Listen within a dynamic sub-collection
  /// repo.listenByIds(
  ///   ['p1', 'p2', 'p3'],
  ///   params: KeyParams({'userId': 'u1'}),
  ///   // source path 'users/{userId}/posts'
  /// ).listen((response) { ... });
  ///
  /// // 5. Listen to delta changes across the watched IDs
  /// repo.listenByIds(
  ///   ['u1', 'u2'],
  ///   resolveDocChangesRefs: true,
  /// ).listen((response) { ... });
  ///
  /// // 6. Use in a StreamBuilder
  /// StreamBuilder<Response<Post>>(
  ///   stream: postRepo.listenByIds(pinnedIds),
  ///   builder: (context, snapshot) {
  ///     final posts = snapshot.data?.result ?? [];
  ///     return Column(
  ///       children: posts.map((p) => PostCard(p)).toList(),
  ///     );
  ///   },
  /// );
  /// ```
  Stream<Response<T>> listenByIds(
    Iterable<String> ids, {
    DataFieldParams? params,
    bool? countable,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  }) {
    if (ids.isEmpty) {
      return Stream.value(Response(status: Status.invalidId));
    }
    return _applyStreamModifier<T>(DataModifiers.listenByIds, () {
      return _streamWithFallback(
        (source) => source.listenByIds(
          ids,
          params: params,
          countable: countable,
          resolveRefs: resolveRefs,
          resolveDocChangesRefs: resolveDocChangesRefs,
          ignore: ignore,
        ),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // listenByQuery
  // ---------------------------------------------------------------------------

  /// Returns a stream of documents matching a set of [DataQuery] filters,
  /// [DataSelection] cursors, and [DataSorting] orderings, re-emitting
  /// whenever the result set changes.
  ///
  /// [DataQuery] fields are resolved through [DataDelegate.onResolveFieldPath]
  /// and [DataDelegate.onResolveFieldValue] so backend-native field path
  /// objects are produced transparently.
  ///
  /// Use [DataFetchOptions] to control page size and fetch direction.
  /// Use [onlyUpdates] to emit only changed documents per event.
  ///
  /// ```dart
  /// // 1. Listen to active users
  /// repo.listenByQuery(
  ///   queries: [DataQuery('status', isEqualTo: 'active')],
  /// ).listen((response) {
  ///   final activeUsers = response.result;
  /// });
  ///
  /// // 2. Listen with compound filter, sort and page size
  /// repo.listenByQuery(
  ///   queries: [
  ///     DataQuery('published', isEqualTo: true),
  ///     DataQuery('views', isGreaterThan: 100),
  ///   ],
  ///   sorts: [DataSorting('createdAt', descending: true)],
  ///   options: DataFetchOptions.limit(20),
  /// ).listen((response) { ... });
  ///
  /// // 3. Listen with whereIn filter
  /// repo.listenByQuery(
  ///   queries: [
  ///     DataQuery('category', whereIn: ['tech', 'science']),
  ///   ],
  /// ).listen((response) { ... });
  ///
  /// // 4. Listen filtered by document IDs
  /// repo.listenByQuery(
  ///   queries: [
  ///     DataQuery(DataFieldPath.documentId, whereIn: ['p1', 'p2']),
  ///   ],
  /// ).listen((response) { ... });
  ///
  /// // 5. Listen with array-contains filter
  /// repo.listenByQuery(
  ///   queries: [DataQuery('tags', arrayContains: 'flutter')],
  /// ).listen((response) { ... });
  ///
  /// // 6. Listen with cursor pagination (start after last snapshot)
  /// repo.listenByQuery(
  ///   sorts: [DataSorting('createdAt', descending: true)],
  ///   options: DataFetchOptions.limit(10),
  ///   selections: [DataSelection.startAfterDocument(lastSnapshot)],
  /// ).listen((response) { ... });
  ///
  /// // 7. Listen and resolve @-reference fields on each emission
  /// repo.listenByQuery(
  ///   queries: [DataQuery('role', isEqualTo: 'admin')],
  ///   resolveRefs: true,
  /// ).listen((response) { ... });
  ///
  /// // 8. Listen to delta changes only
  /// repo.listenByQuery(
  ///   queries: [DataQuery('active', isEqualTo: true)],
  ///   onlyUpdates: true,
  /// ).listen((response) { ... });
  ///
  /// // 9. Scoped to a dynamic sub-collection
  /// repo.listenByQuery(
  ///   params: KeyParams({'userId': 'u1'}),
  ///   queries: [DataQuery('read', isEqualTo: false)],
  ///   sorts: [DataSorting('sentAt', descending: true)],
  ///   options: DataFetchOptions.limit(50),
  /// ).listen((response) { ... });
  ///
  /// // 10. Composite OR filter
  /// repo.listenByQuery(
  ///   queries: [
  ///     DataQuery.filter(DataFilter.or([
  ///       DataFilter('status', isEqualTo: 'draft'),
  ///       DataFilter('status', isEqualTo: 'pending'),
  ///     ])),
  ///   ],
  /// ).listen((response) { ... });
  ///
  /// // 11. Use in a StreamBuilder widget
  /// StreamBuilder<Response<Message>>(
  ///   stream: messageRepo.listenByQuery(
  ///     params: KeyParams({'chatId': currentChatId}),
  ///     sorts: [DataSorting('sentAt', descending: false)],
  ///   ),
  ///   builder: (context, snapshot) {
  ///     final messages = snapshot.data?.result ?? [];
  ///     return MessageList(messages: messages);
  ///   },
  /// );
  ///
  /// // 12. Offline-aware: falls back to local backup automatically
  /// //     (RemoteDataRepository with local backup configured)
  /// remoteRepo.listenByQuery(
  ///   queries: [DataQuery('pinned', isEqualTo: true)],
  /// ).listen((response) {
  ///   // Served from local backup when offline
  /// });
  /// ```
  Stream<Response<T>> listenByQuery({
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
    return _applyStreamModifier<T>(DataModifiers.listenByQuery, () {
      return _streamWithFallback(
        (source) => source.listenByQuery(
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
    });
  }
}
