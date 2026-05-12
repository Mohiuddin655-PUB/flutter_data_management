# data_management

A production-ready, offline-first Flutter data layer that abstracts Firestore, Hive, SQLite, or any custom backend behind a single typed API.

---

## Features

- **Typed repository** — `LocalDataRepository` / `RemoteDataRepository` over any `DataSource`
- **Dual-write** — primary-first writes with optional eager or lazy backup mirroring
- **Offline queue** — failed remote writes are persisted and replayed automatically on reconnect
- **Fallback streams** — real-time listeners switch between remote and local sources based on connectivity, with debounce
- **`@` reference fields** — embed sibling/sub-document writes or reads inline, resolved in one batch
- **`#` countable fields** — store collection paths; resolved to live integer counts on read
- **`DataFieldValue` sentinels** — `serverTimestamp`, `increment`, `arrayUnion`, `arrayRemove`, `delete`
- **`DataFieldValueWriter`** — atomic set / update / delete of related documents inside a single batch write
- **`DataFieldValueReader`** — deferred read-time resolution (get, count, filter) of related paths
- **`DataFieldPath.documentId`** — backend-agnostic document-ID queries
- **Cascade delete** — follows `@` and `#` refs and deletes all referenced documents in batches
- **In-memory + persistent cache** — TTL-aware LRU cache with optional storage adapter
- **AES-256-CBC encryption** — per-document encryption with platform-adaptive backend (IO / Web)
- **Multicast streams** — shared upstream subscriptions, zero duplicate listeners
- **`DataOperationSemaphore`** — configurable concurrency limit for parallel ref resolution

---

## Installation

```yaml
dependencies:
  data_management: ^2.4.9
```

---

## Setup

Configure the global `DM` singleton once at app start, before constructing any repository.

```dart
void main() {
  DM.i.configure(
    connectivity: MyConnectivityDelegate(), // implements DataConnectivityDelegate
    cache: MyHiveCacheDelegate(),           // implements DataCacheDelegate
  );
  runApp(const MyApp());
}
```

---

## Quick Start

### 1. Define your entity

```dart
class User extends Entity {
  final String name;
  final String email;

  User({required super.id, required this.name, required this.email});

  @override
  Map<String, dynamic> get source => {'name': name, 'email': email};

  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map[EntityKey.i.id] ?? '',
    name: map['name'] ?? '',
    email: map['email'] ?? '',
  );
}
```

### 2. Define your source

```dart
class UserSource extends RemoteDataSource<User> {
  UserSource()
    : super(
        path: 'users',
        documentId: 'id',
        delegate: FirestoreDelegate(),
      );

  @override
  User build(dynamic source) => User.fromMap(source as Map<String, dynamic>);
}
```

### 3. Define your repository

```dart
class UserRepository extends RemoteDataRepository<User> {
  UserRepository()
    : super(
        source: UserSource(),
        backupMode: true,   // mirror writes to local backup
        lazyMode: true,     // mirror in background
        queueMode: true,    // queue writes when offline
      );
}
```

### 4. Use it

```dart
final repo = UserRepository();

// Write
await repo.create(User(id: 'u1', name: 'Alice', email: 'alice@example.com'));

// Read
final result = await repo.getById('u1');
print(result.data?.name); // Alice

// Listen
repo.listenById('u1').listen((response) {
  print(response.data?.name);
});
```

---

## Core Concepts

### `@` Reference Fields

A field whose key starts with `@` embeds a **reference** to another document.

**On write** (`createRefs: true` / `updateRefs: true`) — the value is a `DataFieldValueWriter` that creates, updates, or deletes the referenced document in the **same atomic batch** as the parent.

**On read** (`resolveRefs: true`) — the system fetches the referenced document and **inlines it** as a nested map, removing the `@` prefix from the key.

```dart
// Write: creates 'users/u1' + 'users/u1/profile' in one batch
await repo.createById('u1', {
  'name': 'Alice',
  '@profile': DataFieldValueWriter.set(
    'users/u1/profile',
    {'bio': 'Flutter developer', 'avatar': 'https://...'},
  ),
}, createRefs: true);

// Read: '@profile' → 'profile': { 'bio': '...', 'avatar': '...' }
final result = await repo.getById('u1', resolveRefs: true);
print(result.data!.filtered['profile']); // { bio: Flutter developer, ... }
```

**List of references** — an `@` field can hold a `List` of writers; each is written atomically and resolved to a `List<Map>` on read.

```dart
await repo.createById('post1', {
  'title': 'Hello',
  '@variants': [
    DataFieldValueWriter.set('products/p1/variants/v_red',  {'color': 'Red'}),
    DataFieldValueWriter.set('products/p1/variants/v_blue', {'color': 'Blue'}),
  ],
}, createRefs: true);
```

**Map of references** — an `@` field can hold a `Map<String, Writer>`; resolved to `Map<String, Map>` on read.

```dart
await repo.createById('p1', {
  '@byRegion': {
    'us': DataFieldValueWriter.set('products/p1/regions/us', {'price': 599.0}),
    'bd': DataFieldValueWriter.set('products/p1/regions/bd', {'price': 65000.0}),
  },
}, createRefs: true);
```

---

### `#` Countable Fields

A field whose key starts with `#` stores a **collection path**. On read (`countable: true`) the system replaces the field with the **live document count** of that collection.

```dart
// Write: stores the collection path
await repo.createById('u1', {
  'name': 'Alice',
  '#posts':         'users/u1/posts',
  '#notifications': 'users/u1/notifications',
});

// Read: '#posts' → 'posts': 7, '#notifications' → 'notifications': 3
final result = await repo.getById('u1', countable: true);
print(result.data!.filtered['posts']);         // 7
print(result.data!.filtered['notifications']); // 3
```

---

### `DataFieldValue` — Write Sentinels

```dart
await repo.updateById('u1', {
  'lastSeen':  DataFieldValue.serverTimestamp(), // backend server time
  'score':     DataFieldValue.increment(10),     // atomic increment
  'tags':      DataFieldValue.arrayUnion(['vip']),
  'oldBadge':  DataFieldValue.arrayRemove(['legacy']),
  'tempToken': DataFieldValue.delete(),          // remove the field
});
```

---

### `DataFieldValueWriter` — Inline Batch Sub-Writes

Embed writes to **any path** inside a parent write map. All are committed atomically.

```dart
await repo.createById('order1', {
  'total': 199.0,
  'status': 'pending',

  // set a sub-document
  '@invoice': DataFieldValueWriter.set(
    'orders/order1/invoice/default',
    {'items': 3, 'vat': 19.9},
  ),

  // update a sibling document
  '@userStats': DataFieldValueWriter.update(
    'users/u1/stats',
    {'orderCount': DataFieldValue.increment(1)},
  ),

  // delete a document in the same batch
  '@cart': DataFieldValueWriter.delete('users/u1/cart'),
}, createRefs: true);
```

---

### `DataFieldValueReader` — Deferred Read-Time Resolution

Store a reader as a field value so every subsequent read resolves it live.

```dart
await repo.updateById('u1', {
  // fetch the doc at the path and inline it
  '@settings': DataFieldValueReader.get('users/u1/settings'),

  // count the collection and inline the integer
  '#posts': DataFieldValueReader.count('users/u1/posts'),

  // query the collection with filters and inline as array
  '@recentPosts': DataFieldValueReader.filter(
    'users/u1/posts',
    DataFieldValueQueryOptions(
      queries: [DataQuery('published', isEqualTo: true)],
      sorts:   [DataSorting('createdAt', descending: true)],
      options: const DataFetchOptions.limit(5),
    ),
  ),
});
```

---

### `DataFieldPath.documentId` — Filter by Document ID

```dart
await repo.getByQuery(
  queries: [
    DataQuery(DataFieldPath.documentId, whereIn: ['u1', 'u2', 'u3']),
  ],
);
```

---

### `DataQuery` — All Filter Operators

```dart
DataQuery('field', isEqualTo: value)
DataQuery('field', isNotEqualTo: value)
DataQuery('field', isLessThan: value)
DataQuery('field', isLessThanOrEqualTo: value)
DataQuery('field', isGreaterThan: value)
DataQuery('field', isGreaterThanOrEqualTo: value)
DataQuery('field', arrayContains: value)
DataQuery('field', arrayContainsAny: [v1, v2])
DataQuery('field', whereIn: [v1, v2])
DataQuery('field', whereNotIn: [v1, v2])
DataQuery('field', isNull: true)

// Composite AND / OR
DataQuery.filter(DataFilter.and([
  DataFilter('status', isEqualTo: 'active'),
  DataFilter('age', isGreaterThan: 18),
]))

DataQuery.filter(DataFilter.or([
  DataFilter('role', isEqualTo: 'admin'),
  DataFilter('role', isEqualTo: 'moderator'),
]))
```

---

### `DataSelection` — Cursor Pagination

```dart
DataSelection.startAt([value])
DataSelection.startAfter([value])
DataSelection.startAtDocument(snapshot)
DataSelection.startAfterDocument(snapshot)
DataSelection.endAt([value])
DataSelection.endBefore([value])
DataSelection.endAtDocument(snapshot)
DataSelection.endBeforeDocument(snapshot)
```

---

### `DataFetchOptions` — Page Size

```dart
const DataFetchOptions.limit(20)               // first 20
const DataFetchOptions.limit(20, true)          // last 20
const DataFetchOptions.single()                 // first 1
DataFetchOptions(fetchingSize: 20, initialFetchSize: 5)
```

---

### `DataSorting`

```dart
DataSorting('createdAt', descending: true)
DataSorting('name')                            // ascending default
```

---

### `DataFieldParams` — Dynamic Path Replacement

Paths may contain `{placeholder}` segments resolved at call time.

```dart
// source path: 'orgs/{orgId}/teams/{teamId}/members'

// by name
repo.getById('u1', params: KeyParams({'orgId': 'org42', 'teamId': 't7'}));

// by position
repo.getById('u1', params: IterableParams(['org42', 't7']));
```

---

## Write API

| Method | Description |
|---|---|
| `create(entity)` | Write entity using its `id` + `filtered` map |
| `createById(id, data)` | Write a document with explicit id + data map |
| `creates(entities)` | Batch-create multiple entities |
| `createByWriters(writers)` | Batch-create from explicit `DataWriter` list |
| `updateById(id, data)` | Partial update (preserves untouched fields) |
| `updateByWriters(writers)` | Partial update multiple documents |
| `deleteById(id)` | Delete one document (optionally cascade) |
| `deleteByIds(ids)` | Delete multiple documents |
| `clear()` | Delete all documents in the collection |
| `write(writers)` | Low-level heterogeneous atomic batch |

### Cascade Delete

```dart
await repo.deleteById(
  'u1',
  deleteRefs: true,                           // follow @ fields
  counter: true,                              // also delete # collection docs
  ignore: (key, _) => key == '@avatar',       // skip specific fields
);
```

### Batch Write (low-level)

```dart
await repo.write([
  DataSetWriter('col/doc1',    {'field': 'value'}),
  DataUpdateWriter('col/doc2', {'score': DataFieldValue.increment(1)}),
  DataDeleteWriter('col/doc3'),
]);
```

---

## Read API

| Method | Description |
|---|---|
| `checkById(id)` | Existence check + optional auto-sync to backup |
| `count()` | Total document count in collection |
| `get()` | All documents in collection |
| `getById(id)` | Single document by ID |
| `getByIds(ids)` | Multiple documents by ID list |
| `getByQuery(...)` | Filter / sort / paginate |
| `search(checker)` | Client-side or prefix-scan text search |

### Hydration flags (all read methods)

| Flag | Effect |
|---|---|
| `resolveRefs: true` | Fetch and inline `@`-prefixed reference fields |
| `countable: true` | Replace `#`-prefixed fields with live integer counts |
| `onlyUpdates: true` | Return only changed documents (`docChanges`) |
| `ignore: (key, _) => ...` | Skip specific fields during hydration |
| `cacheMode: true` | Cache result in memory for subsequent calls |
| `backupMode: true` | Fall back to backup source when primary fails |
| `lazyMode: true` | Sync result to backup in the background |

---

## Listen API

| Method | Description |
|---|---|
| `listen()` | Real-time stream of all documents |
| `listenById(id)` | Real-time stream of a single document |
| `listenByIds(ids)` | Real-time merged stream of multiple documents |
| `listenByQuery(...)` | Real-time filtered / sorted stream |
| `listenCount()` | Real-time document count stream |

All listen methods support the same hydration flags as read methods.  
For `RemoteDataRepository` with a local backup, streams automatically fall back to the local source when connectivity is lost (300 ms debounce).

```dart
StreamBuilder<Response<User>>(
  stream: repo.listenByQuery(
    queries: [DataQuery('active', isEqualTo: true)],
    sorts:   [DataSorting('name')],
    resolveRefs: true,
    countable: true,
  ),
  builder: (context, snapshot) {
    final users = snapshot.data?.result ?? [];
    return ListView(children: users.map((u) => Text(u.name)).toList());
  },
);
```

---

## Offline Queue

When `queueMode: true` (default for `RemoteDataRepository`), writes that fail with `Status.networkError` are persisted to `DM.i.cache` and replayed automatically when connectivity returns.

- Up to 5 retry attempts per operation before it is discarded
- Supersession logic: a pending `create` or `update` for the same document is removed when a `delete` for the same ID is enqueued
- Call `DM.i.drainAll()` to force an immediate drain (e.g. after pull-to-refresh)

---

## Local ↔ Remote Sync

```dart
final repo = RemoteDataRepository<User>(
  source: FirestoreUserSource(),
  backup: HiveUserSource(),
  backupMode: true,
  lazyMode: true,
  restoreMode: true,
);

// Hydrate local from remote on first launch
await repo.restore();
```

`restore()` checks whether the local source is empty (and whether the restore has already run) before pulling from the backup, so it is safe to call on every app start.

---

## Encryption

```dart
final encryptor = DataEncryptor(
  key: DataEncryptor.generateKey(), // store this securely
  passcode: 'my-passcode',
);

class SecureUserSource extends RemoteDataSource<User> {
  SecureUserSource()
    : super(
        path: 'users',
        documentId: 'id',
        delegate: FirestoreDelegate(),
        encryptor: encryptor,       // every document is AES-256-CBC encrypted
      );

  @override
  User build(dynamic source) => User.fromMap(source as Map<String, dynamic>);
}
```

---

## Multicast Streams

Extend `MulticastDataDelegate` instead of `DataDelegate` to share a single upstream Firestore listener across multiple subscribers for the same path.

```dart
class FirestoreDelegate extends MulticastDataDelegate {
  FirestoreDelegate() : super(
    multicastListen: true,
    multicastListenById: true,
    multicastListenByQuery: true,
  );
  // ...
}
```

---

## Repository Options

| Option | Type | Default | Description |
|---|---|---|---|
| `backupMode` | `bool` | `true` | Mirror writes/reads to the optional backup source |
| `lazyMode` | `bool` | `true` | Perform backup operations in the background |
| `queueMode` | `bool` | `true` | Queue failed writes for offline replay |
| `restoreMode` | `bool` | `true` | Enable the `restore()` method |
| `cacheMode` | `bool` | `false` | Cache read results in memory by default |
| `backupFlushInterval` | `Duration` | `30s` | How often the local→remote flush timer fires |
| `backupFlushSize` | `int` | `50` | Flush immediately after this many queued ops |

---

## Error Handling

```dart
// Silent — swallow all errors
final repo = RemoteDataRepository<User>(
  source: UserSource(),
  errorDelegate: ErrorDelegate.silent,
);

// Printing — debugPrint every error (default)
final repo = RemoteDataRepository<User>(
  source: UserSource(),
  errorDelegate: ErrorDelegate.printing,
);

// Custom
class MyErrorDelegate implements ErrorDelegate {
  @override
  void onError(DataOperationError error) {
    Sentry.captureException(error.cause, stackTrace: error.stack);
  }
}
```

---

## Response

Every method returns `Response<T>` from `flutter_entity`.

```dart
final r = await repo.getById('u1');

r.isSuccessful   // status == ok
r.isValid        // isSuccessful && result is not empty
r.data           // first item or null
r.result         // Iterable<T>
r.error          // error string or null
r.status         // Status enum value
r.snapshot       // raw backend snapshot (QuerySnapshot, DocumentSnapshot, etc.)
```

---

## Status Codes

| Status | Meaning |
|---|---|
| `Status.ok` | Operation succeeded |
| `Status.notFound` | Document / collection is empty |
| `Status.invalidId` | Empty id was passed |
| `Status.invalid` | Empty data / writers list |
| `Status.networkError` | Connectivity failure |
| `Status.failure` | Unexpected exception |
| `Status.canceled` | Partial success or operation skipped |
| `Status.nullable` | Encryption produced null payload |
| `Status.undefined` | Backup source not configured |

---

## License

MIT