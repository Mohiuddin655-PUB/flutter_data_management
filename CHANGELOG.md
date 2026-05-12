# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.4.9] — 2026-05-12

Initial stable release.

### Added

#### Core Architecture

- `DataOperation` — low-level CRUD + listen engine built from composable mixins
- `DataSource<T>` — abstract typed source with `LocalDataSource` and `RemoteDataSource` subclasses
- `DataRepository<T>` — high-level repository with `LocalDataRepository` and `RemoteDataRepository`
  convenience subclasses
- `DataDelegate` — abstract backend adapter interface (implement once, swap freely)
- `MulticastDataDelegate` — shared upstream stream subscriptions to prevent duplicate listeners per
  path
- `ErrorDelegate` — pluggable error reporting (`silent`, `printing`, or custom)
- `DataWriteBatch` — abstract atomic batch with committed-state guard

#### Write API

- `create(entity)` — write entity using `Entity.id` + `Entity.filtered`
- `createById(id, data)` — write document with explicit id and raw data map
- `creates(entities)` — parallel batch-create multiple entities
- `createByWriters(writers)` — batch-create from explicit `DataWriter` list
- `updateById(id, data)` — partial update preserving untouched fields
- `updateByWriters(writers)` — partial update multiple documents in parallel
- `deleteById(id)` — single document delete with optional cascade
- `deleteByIds(ids)` — multi-document delete queued as one operation
- `clear()` — delete all documents in the collection (optionally cascade)
- `write(writers)` — low-level heterogeneous atomic batch (`DataSetWriter` / `DataUpdateWriter` /
  `DataDeleteWriter`)

#### Read API

- `checkById(id)` — existence check with optional backup auto-sync
- `count()` — aggregate document count
- `get()` — full collection fetch
- `getById(id)` — single document fetch
- `getByIds(ids)` — multi-document fetch with automatic `whereIn` splitting
- `getByQuery(...)` — filter / sort / paginate
- `search(checker)` — `Checker.contains` and `Checker.equal` text search

#### Listen (Real-time) API

- `listen()` — real-time stream of all documents
- `listenById(id)` — real-time stream of a single document
- `listenByIds(ids)` — merged real-time stream of multiple documents
- `listenByQuery(...)` — filtered and sorted real-time stream
- `listenCount()` — real-time aggregate count stream

#### `@` Reference Fields

- `DataFieldValueWriter.set` — atomic set of a related document in the same batch
- `DataFieldValueWriter.update` — atomic update of a related document in the same batch
- `DataFieldValueWriter.delete` — atomic delete of a related document in the same batch
- `@` field as `String` path — resolved to full document on read (`resolveRefs: true`)
- `@` field as `List` of paths / writers — resolved to `List<Map>` on read
- `@` field as `Map` of paths / writers — resolved to `Map<String, Map>` on read
- Up to 8 levels of recursive reference resolution
- Configurable concurrency via `DataOperationSemaphore` (`refConcurrency` default 16)

#### `#` Countable Fields

- `#` field as collection path — resolved to live `int` count on read (`countable: true`)
- `#` field as `List` of paths — resolved to `List<int>` on read
- `#` field as `Map` of paths — resolved to `Map<String, int>` on read

#### `DataFieldValueReader` — Deferred Read-Time Resolution

- `DataFieldValueReader.get(path)` — fetch and inline a document on every read
- `DataFieldValueReader.count(path)` — count and inline a collection on every read
- `DataFieldValueReader.filter(path, options)` — query and inline results on every read

#### `DataFieldValue` — Write Sentinels

- `DataFieldValue.serverTimestamp()`
- `DataFieldValue.increment(num)`
- `DataFieldValue.arrayUnion(List)`
- `DataFieldValue.arrayRemove(List)`
- `DataFieldValue.delete()`

#### `DataQuery` — Filter Operators

- `isEqualTo`, `isNotEqualTo`
- `isLessThan`, `isLessThanOrEqualTo`
- `isGreaterThan`, `isGreaterThanOrEqualTo`
- `arrayContains`, `arrayContainsAny`, `arrayNotContains`, `arrayNotContainsAny`
- `whereIn`, `whereNotIn`
- `isNull`
- `DataQuery.filter(DataFilter)` — composite `DataFilter.and` / `DataFilter.or`

#### `DataSelection` — Cursor Pagination

- `startAt`, `startAfter`, `endAt`, `endBefore` (value-based)
- `startAtDocument`, `startAfterDocument`, `endAtDocument`, `endBeforeDocument` (snapshot-based)

#### `DataFieldPath`

- `DataFieldPath.documentId` — backend-agnostic document-ID field reference

#### `DataFieldParams` — Dynamic Path Replacement

- `KeyParams(Map<String, String>)` — named placeholder replacement `{key}`
- `IterableParams(List<String>)` — positional placeholder replacement `{0}`, `{1}`

#### Dual-Write & Backup

- Primary-first execution with connectivity awareness
- Optional eager (`lazyMode: false`) or lazy (`lazyMode: true`) backup mirroring
- Per-call override of `backupMode`, `lazyMode`, `queueMode`

#### Offline Queue

- Automatic persistence of failed remote writes to `DataCacheDelegate`
- Auto-drain on reconnect via `DM.connectivityChanges`
- Manual drain via `DM.i.drainAll()`
- Up to 5 retry attempts per queued operation before discard
- Supersession logic: pending creates/updates are removed when a delete for the same ID is enqueued
- `DataQueuedOpKind`: `create`, `creates`, `updateById`, `updateByWriters`, `deleteById`,
  `deleteByIds`, `clear`

#### Fallback Streams

- `_FallbackStream` — automatically switches between remote and local source based on connectivity
- 300 ms debounce on connectivity transitions to prevent rapid swapping
- Generation counter prevents stale events from cancelled subscriptions

#### Local ↔ Remote Sync

- `restore()` — hydrate local source from remote backup on first launch
- Idempotent restore flag stored in `DataCacheDelegate`
- `clearRestoredFlag()` — force re-restore on next call
- `flushBackupNow()` — immediate local→remote flush

#### Cache

- `CacheManager` — TTL-aware LRU in-memory cache
- `CacheConfig` — `maxSize`, `defaultTtl`, `deduplicateInFlight`, `evictionInterval`
- In-flight deduplication — identical concurrent requests share one `Future`
- Optional persistent `CacheStorageAdapter` (no-op on native, `localStorage` on Web)
- `CacheStats` — `hits`, `misses`, `writes`, `evictions`, `expirations`, `inFlightDedupes`,
  `hitRate`
- `CacheManager.put`, `pick`, `pickByKey`, `remove`, `removeByKey`, `clear`, `evictExpired`

#### Encryption

- `DataEncryptor` — AES-256-CBC with per-document fresh IV
- Platform-adaptive backend: `encrypt` package on IO, Web Crypto API on Web
- `DataEncryptor.generateKey()` — secure 32-byte hex key generator
- Custom `EncryptorRequestBuilder` / `EncryptorResponseBuilder` for envelope format control

#### Global Manager (`DM`)

- `DM.i.configure(connectivity, cache)` — wire connectivity + cache once at startup
- `DM.i.isConnected` — current connectivity state
- `DM.i.connectivityChanges` — broadcast stream of connectivity changes
- `DM.i.register` / `unregister` — per-repository drain callback registry
- `DM.i.drainAll()` — re-entrant-safe sequential drain of all queued operations

#### Utilities

- `DataLimitations` — `whereIn` split threshold, `batchLimit`, `maximumDeleteLimit`
- `DataOperationSemaphore` — bounded concurrency for parallel async operations
- `DataIdGenerator` — cryptographically secure random ID / hex key generation
- `DataByteType` — `x2` through `x128` byte-size enum for key generation
- `DataFieldReplacer` — regex-based path placeholder replacement
- `Checker` — `contains` / `equal` search descriptor

---

## [0.9.0] — 2025-04-01 (pre-release)

### Added

- Initial internal beta with basic CRUD, Firestore delegate, and offline queue prototype

### Changed

- `CacheDelegate` renamed to `DataCacheDelegate`
- `ConnectivityDelegate` renamed to `DataConnectivityDelegate`

### Fixed

- `DataOperationSemaphore._release` double-decrement when waiter queue is empty
- `_FallbackStream` stale event delivery after rapid connectivity toggle
- `_MulticastStream` teardown race condition when last subscriber cancels during upstream event

---

## [0.8.0] — 2025-03-01 (internal)

### Added

- `MulticastDataDelegate` with per-path stream caching and subscriber reference counting
- `CacheManager` with in-flight deduplication and Web `localStorage` adapter
- `DataEncryptor` with IO / Web platform-adaptive AES-256-CBC backend
- `DataFieldValueReader` deferred resolution (`get`, `count`, `filter`)

### Changed

- `_ReadResolveMixin` refactored to resolve `DataFieldValueReader` fields before `@` prefix fields
- `DataOperation.refSemaphore` now configurable via constructor (`refConcurrency`)

---

## [0.7.0] — 2025-02-01 (internal)

### Added

- Cascade delete via `_CascadeDeleteCollector` with `@` and `#` field traversal
- `batchMaxLimit` parameter to cap cascade collection size
- `DataQueuedOp.copyWith` for attempt increment without full reconstruction

### Fixed

- `_RepoQueueMixin._mergeOnPush` incorrectly superseding multi-writer ops when only a subset of IDs
  matched

---

## [0.6.0] — 2025-01-01 (internal)

### Added

- `_RepoDualWriteMixin` — extracted dual-write logic from repository base
- `_RepoReadWithFallbackMixin` — extracted fallback read + backup sync logic
- `DataFilter.and` / `DataFilter.or` composite filter support
- `DataSelection` cursor pagination helpers
- `DataFetchOptions.single()` / `DataFetchOptions.limit(n, fromLast)`

### Changed

- `_RepoQueueMixin` drain logic split into `_drainPrimaryQueue` and `_drainBackupQueue`
- `DataRepository.queueId` now defaults to `type:sourceType:path` when `id` is not provided

---

## [0.5.0] — 2024-12-01 (internal)

### Added

- `@` reference field write transform via `DataFieldValueWriter`
- `#` countable field resolution via `_ReadResolveMixin`
- `DataFieldValueWriter.set`, `.update`, `.delete`
- `DataFieldPath.documentId` for backend-agnostic ID queries
- `DataFieldValue` sentinels: `serverTimestamp`, `increment`, `arrayUnion`, `arrayRemove`, `delete`

---

## [0.4.0] — 2024-11-01 (internal)

### Added

- `LocalDataRepository` and `RemoteDataRepository` convenience subclasses
- `restore()` with idempotent restore-flag via `DataCacheDelegate`
- `DataRepository.backupFlushInterval` and `backupFlushSize` timer-based flush

---

## [0.3.0] — 2024-10-01 (internal)

### Added

- Offline queue with `DataCacheDelegate` persistence and auto-drain on reconnect
- `DataQueuedOp` serialization / deserialization
- Supersession logic for `deleteById` over pending creates and updates

---

## [0.2.0] — 2024-09-01 (internal)

### Added

- `DataSource<T>` with encryption, path-param resolution, and `DataLimitations`
- `_SourceWriteMixin` with `createRefs` / `updateRefs` / `deleteRefs` flags
- `_SourceListenMixin` with `onlyUpdates` and `resolveDocChangesRefs`
- `_FallbackStream` connectivity-aware stream switching

---

## [0.1.0] — 2024-08-01 (internal)

### Added

- Initial project scaffold
- `DataDelegate` and `DataWriteBatch` abstract interfaces
- `DataOperation` with basic CRUD and listen operations
- `ErrorDelegate` with `silent` and `printing` implementations
- `DataOperationSemaphore` bounded concurrency primitive