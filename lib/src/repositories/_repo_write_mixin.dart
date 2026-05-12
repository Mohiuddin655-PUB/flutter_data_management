part of 'base.dart';

/// Write operations for a typed [DataRepository].
///
/// Each method routes through [_dualWrite], which handles:
/// - Primary-first execution with connectivity awareness
/// - Optional lazy or eager backup mirroring
/// - Offline queueing when [queueMode] is enabled
///
/// ## Key Concepts
///
/// ### @ prefix — embedded reference writes
/// A field whose key starts with `@` is treated as a **reference write**.
/// Its value must be a path string (or a [DataFieldValueWriter]) pointing
/// to another document. During a write transform the system will write that
/// embedded document in the same batch.
///
/// ```dart
/// // The '@profile' key causes a separate write to 'users/u1/profile'
/// // inside the same batch, and the field value is replaced with the path.
/// await repo.createById('u1', {
///   'name': 'Alice',
///   '@profile': DataFieldValueWriter.set(
///     'users/u1/profile',
///     {'bio': 'Flutter developer', 'avatar': 'https://...'},
///   ),
/// });
///
/// // Reading back with resolveRefs: true hydrates '@profile' → full map
/// final user = await repo.getById('u1', resolveRefs: true);
/// // user.data!.filtered == {
/// //   'name': 'Alice',
/// //   'profile': {'bio': 'Flutter developer', 'avatar': 'https://...'},
/// // }
/// ```
///
/// ### # prefix — countable collection references
/// A field whose key starts with `#` is treated as a **countable reference**.
/// Its value is a collection path. When reading with `countable: true` the
/// system replaces the field with the live document count of that collection.
///
/// ```dart
/// // '#posts' stores a path; on read the count of that collection is injected
/// await repo.createById('u1', {
///   'name': 'Alice',
///   '#posts': 'users/u1/posts', // collection path
/// });
///
/// // Reading back with countable: true replaces '#posts' → int count
/// final user = await repo.getById('u1', countable: true);
/// // user.data!.filtered == {'name': 'Alice', 'posts': 3}
/// ```
///
/// ### DataFieldPath — document-id based queries
/// Use [DataFieldPath.documentId] as a query field to filter by document ID
/// without knowing the backend's internal ID field name.
///
/// ```dart
/// await repo.getByQuery(
///   queries: [
///     DataQuery(DataFieldPath.documentId, whereIn: ['u1', 'u2', 'u3']),
///   ],
/// );
/// ```
///
/// ### DataFieldValue — special write sentinels
/// Use [DataFieldValue] to emit backend-native special values such as
/// server timestamps, array unions/removes, and increment.
///
/// ```dart
/// await repo.updateById('u1', {
///   'lastSeen': DataFieldValue.serverTimestamp(),
///   'score':    DataFieldValue.increment(10),
///   'tags':     DataFieldValue.arrayUnion(['flutter', 'dart']),
///   'oldTag':   DataFieldValue.arrayRemove(['legacy']),
///   'tempKey':  DataFieldValue.delete(),
/// });
/// ```
///
/// ### DataFieldValueWriter — inline batch sub-writes
/// [DataFieldValueWriter] lets you embed a **set / update / delete** of
/// another document directly inside a parent write map. All embedded writes
/// are committed in a single batch alongside the parent.
///
/// ```dart
/// await repo.createById('post1', {
///   'title': 'Hello World',
///   // Creates 'posts/post1/meta' in the same batch
///   '@meta': DataFieldValueWriter.set(
///     'posts/post1/meta',
///     {'wordCount': 120, 'readTime': '1 min'},
///   ),
///   // Updates 'counters/global' in the same batch
///   '@counter': DataFieldValueWriter.update(
///     'counters/global',
///     {'postCount': DataFieldValue.increment(1)},
///   ),
/// });
/// ```
///
/// ### DataFieldValueReader — deferred read-time resolution
/// [DataFieldValueReader] stored as a field value signals that on read the
/// system should fetch or count a related path and inline the result.
///
/// ```dart
/// // Store a reader so that every getById call resolves it live
/// await repo.createById('u1', {
///   'name': 'Alice',
///   // On read: fetch the doc at 'users/u1/settings' and inline it
///   '@settings': DataFieldValueReader.get('users/u1/settings'),
///   // On read: count 'users/u1/posts' and inline the integer
///   '#posts': DataFieldValueReader.count('users/u1/posts'),
///   // On read: query 'users/u1/posts' with filters and inline array
///   '@recentPosts': DataFieldValueReader.filter(
///     'users/u1/posts',
///     DataFieldValueQueryOptions(
///       queries: [DataQuery('published', isEqualTo: true)],
///       sorts: [DataSorting('createdAt', descending: true)],
///       options: DataFetchOptions.limit(5),
///     ),
///   ),
/// });
/// ```
mixin _RepoWriteMixin<T extends Entity>
    on
        _RepoExecutorMixin<T>,
        _RepoModifierMixin<T>,
        _RepoQueueMixin<T>,
        _RepoDualWriteMixin<T> {
  String _opId(String kind, [String? extra]) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '$queueId:$kind:${extra ?? ''}:$now';
  }

  List<Map<String, dynamic>> _writersToJson(Iterable<DataWriter> writers) {
    return writers.map((w) => {'id': w.id, 'data': w.data}).toList();
  }

  // ---------------------------------------------------------------------------
  // create
  // ---------------------------------------------------------------------------

  /// Writes a single entity using its [Entity.id] and [Entity.filtered] map.
  ///
  /// Shorthand for [createById] — the id and data are extracted from [data].
  ///
  /// **Backup / queue behaviour** (all writes share this contract):
  /// - [backupMode] — mirror the write to the optional backup source.
  /// - [lazyMode]   — perform the backup write in the background (fire-and-forget).
  /// - [queueMode]  — persist the write offline and replay when reconnected.
  ///
  /// Returns [Status.ok] on success, [Status.invalidId] when the entity id is
  /// empty, or [Status.networkError] / [Status.failure] on transport errors.
  ///
  /// ```dart
  /// final post = Post(id: 'p1', title: 'Hello', authorId: 'u1');
  ///
  /// // Basic
  /// await repo.create(post);
  ///
  /// // With a reference write: '@author' creates/merges the author sub-doc
  /// final richPost = Post.fromMap({
  ///   'id': 'p1',
  ///   'title': 'Hello',
  ///   '@author': DataFieldValueWriter.set(
  ///     'posts/p1/author',
  ///     {'name': 'Alice', 'uid': 'u1'},
  ///   ),
  /// });
  /// await repo.create(richPost, createRefs: true);
  ///
  /// // Force online-only (skip queue even if queueMode is globally on)
  /// await repo.create(payment, queueMode: false);
  /// ```
  Future<Response<T>> create(
    T data, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    return createById(
      data.id,
      data.filtered,
      params: params,
      merge: merge,
      createRefs: createRefs,
      lazyMode: lazyMode,
      backupMode: backupMode,
      queueMode: queueMode,
    );
  }

  // ---------------------------------------------------------------------------
  // createById
  // ---------------------------------------------------------------------------

  /// Writes a document at `<sourcePath>/<id>` with an explicit [data] map.
  ///
  /// When [createRefs] is `true` every [DataFieldValueWriter] embedded in
  /// [data] is executed in the same atomic batch:
  /// - [DataFieldValueWriter.set]    → batch set the target path
  /// - [DataFieldValueWriter.update] → batch update the target path
  /// - [DataFieldValueWriter.delete] → batch delete the target path
  ///
  /// When [merge] is `true` (default) existing fields not present in [data]
  /// are preserved (Firestore-style merge / upsert).
  ///
  /// ```dart
  /// // 1. Plain write
  /// await repo.createById('u1', {'name': 'Alice', 'age': 30});
  ///
  /// // 2. Merge-false — overwrites the entire document
  /// await repo.createById('u1', {'name': 'Alice'}, merge: false);
  ///
  /// // 3. With @-reference — creates sibling profile doc in same batch
  /// await repo.createById('u1', {
  ///   'name': 'Alice',
  ///   '@profile': DataFieldValueWriter.set(
  ///     'users/u1/profile',
  ///     {'bio': 'Flutter dev'},
  ///   ),
  /// }, createRefs: true);
  ///
  /// // 4. With #-countable reference stored for later reads
  /// await repo.createById('u1', {
  ///   'name': 'Alice',
  ///   '#posts': 'users/u1/posts', // collection path for count resolution
  /// });
  ///
  /// // 5. With server-side field values
  /// await repo.createById('u1', {
  ///   'name': 'Alice',
  ///   'createdAt': DataFieldValue.serverTimestamp(),
  ///   'score':     DataFieldValue.increment(0),
  ///   'tags':      DataFieldValue.arrayUnion(['new']),
  /// });
  ///
  /// // 6. Dynamic path via KeyParams
  /// await repo.createById(
  ///   'u1',
  ///   {'name': 'Alice'},
  ///   params: KeyParams({'orgId': 'org42'}),
  ///   // source path might be 'orgs/{orgId}/users' → resolved to 'orgs/org42/users'
  /// );
  ///
  /// // 7. Offline-queue: write survives connectivity loss
  /// await repo.createById('u1', {'name': 'Alice'}, queueMode: true);
  /// ```
  Future<Response<T>> createById(
    String id,
    Map<String, dynamic> data, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    if (id.isEmpty) {
      return Future.value(Response(status: Status.invalidId));
    }
    if (data.isEmpty) {
      return Future.value(Response(status: Status.invalid));
    }
    return _dualWrite(
      DataModifiers.create,
      backupMode: backupMode,
      lazyMode: lazyMode,
      queueMode: queueMode,
      write: (source) => source.create(
        id,
        data,
        params: params,
        createRefs: createRefs,
        merge: merge,
      ),
      opBuilder: () => _DataQueuedOp(
        id: _opId('create', id),
        kind: _DataQueuedOpKind.create,
        entityId: id,
        data: data,
        merge: merge,
        createRefs: createRefs,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // creates
  // ---------------------------------------------------------------------------

  /// Writes multiple entities in parallel, each using its own [Entity.id] and
  /// [Entity.filtered] map. Delegates to [createByWriters] internally.
  ///
  /// Returns [Status.ok] when every write succeeds, [Status.canceled] when
  /// at least one fails (partial success), or [Status.invalid] for an empty
  /// list.
  ///
  /// ```dart
  /// final users = [
  ///   User(id: 'u1', name: 'Alice'),
  ///   User(id: 'u2', name: 'Bob'),
  ///   User(id: 'u3', name: 'Carol'),
  /// ];
  ///
  /// // Batch-create three users; all use the same options
  /// await repo.creates(users, merge: true);
  ///
  /// // With lazy backup mirroring
  /// await repo.creates(users, backupMode: true, lazyMode: true);
  /// ```
  Future<Response<T>> creates(
    Iterable<T> data, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    return createByWriters(
      data.map((e) => DataWriter(id: e.id, data: e.filtered)),
      params: params,
      merge: merge,
      createRefs: createRefs,
      lazyMode: lazyMode,
      backupMode: backupMode,
      queueMode: queueMode,
    );
  }

  // ---------------------------------------------------------------------------
  // createByWriters
  // ---------------------------------------------------------------------------

  /// Writes multiple documents using explicit [DataWriter] objects,
  /// each carrying an `id` and a raw `data` map.
  ///
  /// Useful when you want to write heterogeneous data maps that do not
  /// correspond to a single entity type, or when the id/data pairs come
  /// from a source other than [Entity.filtered].
  ///
  /// All writers are committed in a single queued operation so they will
  /// be replayed atomically if offline.
  ///
  /// ```dart
  /// // 1. Write several posts in one queued op
  /// await repo.createByWriters([
  ///   DataWriter(id: 'p1', data: {'title': 'First',  'published': false}),
  ///   DataWriter(id: 'p2', data: {'title': 'Second', 'published': true}),
  /// ]);
  ///
  /// // 2. Include @-reference in individual writer data
  /// await repo.createByWriters([
  ///   DataWriter(id: 'p1', data: {
  ///     'title': 'First',
  ///     '@meta': DataFieldValueWriter.set(
  ///       'posts/p1/meta',
  ///       {'wordCount': 200},
  ///     ),
  ///   }),
  /// ], createRefs: true);
  ///
  /// // 3. Dynamic path replacement via IterableParams
  /// await repo.createByWriters(
  ///   writers,
  ///   params: IterableParams(['org42', 'team7']),
  ///   // source path 'orgs/{0}/teams/{1}/posts' → 'orgs/org42/teams/team7/posts'
  /// );
  /// ```
  Future<Response<T>> createByWriters(
    Iterable<DataWriter> writers, {
    DataFieldParams? params,
    bool merge = true,
    bool createRefs = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    if (writers.isEmpty) {
      return Future.value(Response(status: Status.invalid));
    }
    final list = writers.toList(growable: false);
    return _dualWrite(
      DataModifiers.creates,
      backupMode: backupMode,
      lazyMode: lazyMode,
      queueMode: queueMode,
      write: (source) => source.creates(
        list,
        params: params,
        merge: merge,
        createRefs: createRefs,
      ),
      opBuilder: () => _DataQueuedOp(
        id: _opId('creates'),
        kind: _DataQueuedOpKind.creates,
        writers: _writersToJson(list),
        merge: merge,
        createRefs: createRefs,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // updateById
  // ---------------------------------------------------------------------------

  /// Partially updates the document at `<sourcePath>/<id>`.
  ///
  /// Only the fields present in [data] are written; other fields are
  /// untouched. To remove a field explicitly pass
  /// `DataFieldValue.delete()` as its value.
  ///
  /// When [updateRefs] is `true`, any [DataFieldValueWriter] values inside
  /// [data] are extracted and written to their target paths in the same batch.
  ///
  /// ```dart
  /// // 1. Simple partial update
  /// await repo.updateById('u1', {'age': 31, 'city': 'Dhaka'});
  ///
  /// // 2. Server-side sentinels
  /// await repo.updateById('u1', {
  ///   'lastLogin':  DataFieldValue.serverTimestamp(),
  ///   'loginCount': DataFieldValue.increment(1),
  ///   'badges':     DataFieldValue.arrayUnion(['early-adopter']),
  ///   'tempFlag':   DataFieldValue.delete(),
  /// });
  ///
  /// // 3. Update parent + sibling doc atomically via @-reference
  /// await repo.updateById('post1', {
  ///   'title': 'Updated Title',
  ///   '@meta': DataFieldValueWriter.update(
  ///     'posts/post1/meta',
  ///     {'editedAt': DataFieldValue.serverTimestamp()},
  ///   ),
  /// }, updateRefs: true);
  ///
  /// // 4. Delete a sibling document in the same update batch
  /// await repo.updateById('post1', {
  ///   'draft': false,
  ///   '@draft': DataFieldValueWriter.delete('posts/post1/drafts/latest'),
  /// }, updateRefs: true);
  ///
  /// // 5. Queue update for offline replay
  /// await repo.updateById('u1', {'score': DataFieldValue.increment(5)},
  ///     queueMode: true);
  /// ```
  Future<Response<T>> updateById(
    String id,
    Map<String, dynamic> data, {
    DataFieldParams? params,
    bool? resolveRefs,
    Ignore? ignore,
    bool updateRefs = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    if (id.isEmpty || data.isEmpty) {
      return Future.value(Response(status: Status.invalid));
    }
    return _dualWrite(
      DataModifiers.updateById,
      backupMode: backupMode,
      lazyMode: lazyMode,
      queueMode: queueMode,
      write: (source) => source.updateById(
        id,
        data,
        params: params,
        resolveRefs: resolveRefs,
        ignore: ignore,
        updateRefs: updateRefs,
      ),
      opBuilder: () => _DataQueuedOp(
        id: _opId('updateById', id),
        kind: _DataQueuedOpKind.updateById,
        entityId: id,
        data: data,
        updateRefs: updateRefs,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // updateByWriters
  // ---------------------------------------------------------------------------

  /// Partially updates multiple documents in parallel, each from a
  /// [DataWriter] carrying the target `id` and partial `data` map.
  ///
  /// All writers are queued as a single [_DataQueuedOpKind.updateByWriters]
  /// operation, so if the device goes offline they are replayed together.
  ///
  /// ```dart
  /// // 1. Bulk partial update
  /// await repo.updateByWriters([
  ///   DataWriter(id: 'u1', data: {'status': 'active'}),
  ///   DataWriter(id: 'u2', data: {'status': 'inactive'}),
  /// ]);
  ///
  /// // 2. Mixed field values across writers
  /// await repo.updateByWriters([
  ///   DataWriter(id: 'u1', data: {
  ///     'score':    DataFieldValue.increment(10),
  ///     'lastSeen': DataFieldValue.serverTimestamp(),
  ///   }),
  ///   DataWriter(id: 'u2', data: {
  ///     'tags': DataFieldValue.arrayRemove(['pending']),
  ///   }),
  /// ]);
  ///
  /// // 3. Update with embedded reference sub-writes
  /// await repo.updateByWriters([
  ///   DataWriter(id: 'post1', data: {
  ///     'likes': DataFieldValue.increment(1),
  ///     '@stats': DataFieldValueWriter.update(
  ///       'posts/post1/stats',
  ///       {'likeCount': DataFieldValue.increment(1)},
  ///     ),
  ///   }),
  /// ], updateRefs: true);
  /// ```
  Future<Response<T>> updateByWriters(
    Iterable<DataWriter> writers, {
    DataFieldParams? params,
    bool? resolveRefs,
    Ignore? ignore,
    bool updateRefs = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    if (writers.isEmpty) {
      return Future.value(Response(status: Status.invalid));
    }
    final list = writers.toList(growable: false);
    return _dualWrite(
      DataModifiers.updateByWriters,
      backupMode: backupMode,
      lazyMode: lazyMode,
      queueMode: queueMode,
      write: (source) => source.updateByWriters(
        list,
        params: params,
        resolveRefs: resolveRefs,
        ignore: ignore,
        updateRefs: updateRefs,
      ),
      opBuilder: () => _DataQueuedOp(
        id: _opId('updateByWriters'),
        kind: _DataQueuedOpKind.updateByWriters,
        writers: _writersToJson(list),
        updateRefs: updateRefs,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // deleteById
  // ---------------------------------------------------------------------------

  /// Deletes the document at `<sourcePath>/<id>`.
  ///
  /// When [deleteRefs] is `true` the system first reads the document,
  /// then recursively collects all paths referenced by `@`-prefixed fields
  /// (and, when [counter] is `true`, `#`-prefixed collection paths as well),
  /// and deletes all of them in one or more commit batches.
  ///
  /// ```dart
  /// // 1. Simple delete
  /// await repo.deleteById('u1');
  ///
  /// // 2. Cascade delete — also removes docs referenced by @ fields
  /// await repo.deleteById('u1', deleteRefs: true);
  ///
  /// // 3. Cascade delete + also removes docs in # collection paths
  /// await repo.deleteById('u1', deleteRefs: true, counter: true);
  ///
  /// // 4. Cascade delete ignoring a specific field
  /// await repo.deleteById(
  ///   'u1',
  ///   deleteRefs: true,
  ///   ignore: (key, _) => key == '@avatar', // keep avatar doc alive
  /// );
  ///
  /// // 5. Queue deletion for offline replay
  /// await repo.deleteById('u1', queueMode: true);
  ///
  /// // 6. Mirror deletion to backup eagerly
  /// await repo.deleteById('u1', backupMode: true, lazyMode: false);
  /// ```
  Future<Response<T>> deleteById(
    String id, {
    DataFieldParams? params,
    bool? resolveRefs,
    Ignore? ignore,
    bool counter = false,
    bool deleteRefs = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    if (id.isEmpty) {
      return Future.value(Response(status: Status.invalidId));
    }
    return _dualWrite(
      DataModifiers.deleteById,
      backupMode: backupMode,
      lazyMode: lazyMode,
      queueMode: queueMode,
      write: (source) => source.deleteById(
        id,
        params: params,
        counter: counter,
        resolveRefs: resolveRefs,
        ignore: ignore,
        deleteRefs: deleteRefs,
      ),
      opBuilder: () => _DataQueuedOp(
        id: _opId('deleteById', id),
        kind: _DataQueuedOpKind.deleteById,
        entityId: id,
        deleteRefs: deleteRefs,
        counter: counter,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // deleteByIds
  // ---------------------------------------------------------------------------

  /// Deletes multiple documents by their IDs, each via [deleteById].
  ///
  /// Returns [Status.ok] when every deletion succeeds, [Status.canceled] for
  /// partial success, or [Status.invalid] for an empty list.
  ///
  /// All IDs are queued as a single [_DataQueuedOpKind.deleteByIds] operation.
  /// If any queued `create` or `update` for the same ID is already in the
  /// offline queue, it is automatically superseded (removed) before the delete
  /// is enqueued.
  ///
  /// ```dart
  /// // 1. Delete several documents
  /// await repo.deleteByIds(['u1', 'u2', 'u3']);
  ///
  /// // 2. Cascade — also remove referenced sub-documents
  /// await repo.deleteByIds(
  ///   ['p1', 'p2'],
  ///   deleteRefs: true,
  ///   counter: true,
  /// );
  ///
  /// // 3. Ignore specific reference fields during cascade
  /// await repo.deleteByIds(
  ///   ['p1', 'p2'],
  ///   deleteRefs: true,
  ///   ignore: (key, _) => key == '@thumbnail',
  /// );
  ///
  /// // 4. Queue for offline replay
  /// await repo.deleteByIds(['u1', 'u2'], queueMode: true);
  /// ```
  Future<Response<T>> deleteByIds(
    Iterable<String> ids, {
    DataFieldParams? params,
    bool? resolveRefs,
    Ignore? ignore,
    bool counter = false,
    bool deleteRefs = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    if (ids.isEmpty) {
      return Future.value(Response(status: Status.invalid));
    }
    final list = ids.toList(growable: false);
    return _dualWrite(
      DataModifiers.deleteByIds,
      backupMode: backupMode,
      lazyMode: lazyMode,
      queueMode: queueMode,
      write: (source) => source.deleteByIds(
        list,
        params: params,
        counter: counter,
        resolveRefs: resolveRefs,
        ignore: ignore,
        deleteRefs: deleteRefs,
      ),
      opBuilder: () => _DataQueuedOp(
        id: _opId('deleteByIds'),
        kind: _DataQueuedOpKind.deleteByIds,
        ids: list,
        deleteRefs: deleteRefs,
        counter: counter,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // clear
  // ---------------------------------------------------------------------------

  /// Deletes **all** documents in the source collection (optionally scoped by
  /// [params]).
  ///
  /// Internally fetches all document IDs then delegates to [deleteByIds].
  /// When [deleteRefs] is `true` every referenced document is also removed
  /// in cascade.
  ///
  /// Returns [Status.notFound] when the collection is already empty.
  ///
  /// ```dart
  /// // 1. Clear the entire collection
  /// await repo.clear();
  ///
  /// // 2. Clear a dynamic sub-collection via params
  /// await repo.clear(
  ///   params: KeyParams({'userId': 'u1'}),
  ///   // source path 'users/{userId}/posts' → clears all posts of u1
  /// );
  ///
  /// // 3. Clear with cascade reference deletion
  /// await repo.clear(deleteRefs: true, counter: true);
  ///
  /// // 4. Clear and mirror deletion to backup eagerly
  /// await repo.clear(backupMode: true, lazyMode: false);
  ///
  /// // 5. Queue the clear for offline replay
  /// await repo.clear(queueMode: true);
  /// ```
  Future<Response<T>> clear({
    DataFieldParams? params,
    bool? resolveRefs,
    Ignore? ignore,
    bool deleteRefs = false,
    bool counter = false,
    bool? lazyMode,
    bool? backupMode,
    bool? queueMode,
  }) {
    return _dualWrite(
      DataModifiers.clear,
      backupMode: backupMode,
      lazyMode: lazyMode,
      queueMode: queueMode,
      write: (source) => source.clear(
        params: params,
        counter: counter,
        resolveRefs: resolveRefs,
        ignore: ignore,
        deleteRefs: deleteRefs,
      ),
      opBuilder: () => _DataQueuedOp(
        id: _opId('clear'),
        kind: _DataQueuedOpKind.clear,
        deleteRefs: deleteRefs,
        counter: counter,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // write
  // ---------------------------------------------------------------------------

  /// Executes a heterogeneous list of [DataBatchWriter] operations —
  /// [DataSetWriter], [DataUpdateWriter], and [DataDeleteWriter] — in a single
  /// committed batch against the primary source.
  ///
  /// Unlike the other write methods, [write] does **not** go through
  /// [_dualWrite]: there is no backup mirroring, no offline queueing, and no
  /// [DataModifiers] hook. It is a direct low-level batch execution.
  ///
  /// Use this when you need full control over a heterogeneous atomic
  /// operation across multiple collection paths that does not fit the
  /// higher-level CRUD API.
  ///
  /// Returns [Status.ok] on success, [Status.invalid] for an empty list,
  /// or [Status.failure] / [Status.networkError] on error.
  ///
  /// ```dart
  /// // 1. Mixed set + update + delete in one atomic batch
  /// await repo.write([
  ///   DataSetWriter('users/u1',    {'name': 'Alice', 'active': true}),
  ///   DataSetWriter('users/u2',    {'name': 'Bob'},
  ///                                DataSetOptions(merge: false)),
  ///   DataUpdateWriter('counters/global',
  ///                    {'userCount': DataFieldValue.increment(1)}),
  ///   DataDeleteWriter('pending/u3'),
  /// ]);
  ///
  /// // 2. Bulk-import a snapshot
  /// final writers = snapshot.docs.map((doc) =>
  ///   DataSetWriter('archive/${doc.id}', doc),
  /// ).toList();
  /// await repo.write(writers);
  ///
  /// // 3. Transactional counter adjustment
  /// await repo.write([
  ///   DataUpdateWriter('posts/p1', {
  ///     'likes': DataFieldValue.increment(1),
  ///     'updatedAt': DataFieldValue.serverTimestamp(),
  ///   }),
  ///   DataUpdateWriter('users/u1', {
  ///     'likedPosts': DataFieldValue.arrayUnion(['p1']),
  ///   }),
  /// ]);
  /// ```
  Future<Response<void>> write(List<DataBatchWriter> writers) async {
    if (writers.isEmpty) {
      return Response(status: Status.invalid);
    }
    final response = await _runOnPrimary<Object>((source) async {
      final r = await source.write(writers);
      return r.isSuccessful
          ? Response<Object>(status: Status.ok)
          : Response<Object>(status: r.status, error: r.error);
    });
    return Response(status: response.status, error: response.error);
  }
}
