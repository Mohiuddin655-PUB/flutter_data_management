import 'package:flutter_entity/entity.dart' show Entity;

import 'base.dart' show DataRepository;

/// A [DataRepository] whose primary is a remote database (Firestore,
/// REST API, etc.) and whose optional backup is a local source.
///
/// When [DataRepository.queueMode] is enabled (default), writes that
/// fail with `Status.networkError` are persisted to the offline queue
/// and replayed automatically when connectivity returns. Successful
/// writes are mirrored to the local backup when
/// [DataRepository.backupMode] is `true`.
///
/// ### Simple example — remote-only
///
/// ```dart
/// final repo = RemoteDataRepository<User>(
///   source: FirestoreUserSource(),
/// );
///
/// await repo.create(User(id: 'u1', name: 'Alice'));
/// final user = await repo.getById('u1');
/// ```
///
/// ### Advanced example — offline-first remote with local backup
///
/// ```dart
/// final repo = RemoteDataRepository<Message>(
///   id: 'messages',
///   source: FirestoreMessageSource(),
///   backup: HiveMessageSource(),
///   backupMode: true,    // mirror successful writes to local
///   lazyMode: true,      // mirror in the background
///   restoreMode: true,   // hydrate local on first launch
///   queueMode: true,     // queue writes when offline
///   cacheMode: false,    // disable in-memory read cache
/// );
///
/// await repo.restore();
///
/// // Works whether online or offline:
/// // - online  → write goes through, mirrors to local
/// // - offline → write queues, returns Status.ok, replays on reconnect
/// await repo.create(Message(id: 'm1', body: 'hi'));
/// ```
///
/// ### Strict-online example — fail fast when offline
///
/// ```dart
/// final repo = RemoteDataRepository<Payment>(
///   source: StripePaymentSource(),
///   queueMode: false, // offline writes return Status.networkError
/// );
///
/// // For a single critical write you can also override per-call:
/// await repo.create(payment, queueMode: false);
/// ```
class RemoteDataRepository<T extends Entity> extends DataRepository<T> {
  RemoteDataRepository({
    super.id,
    required super.source,
    super.backup,
    super.errorDelegate,
    super.backupMode,
    super.lazyMode,
    super.restoreMode,
    super.cacheMode,
    super.queueMode,
    super.backupFlushInterval,
    super.backupFlushSize,
  }) : super.remote();
}
