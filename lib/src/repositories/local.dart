import 'package:flutter_entity/entity.dart' show Entity;

import 'base.dart' show DataRepository;

/// A [DataRepository] whose primary is a local database (Hive, Isar,
/// sqflite, etc.) and whose optional backup is a remote source.
///
/// Writes are persisted locally first and then mirrored to the remote
/// backup via a time/size-based flush queue
/// ([DataRepository.backupFlushInterval], [DataRepository.backupFlushSize]).
///
/// Reads fall back to the remote backup when the local source returns
/// no valid data and [DataRepository.backupMode] resolves to `true`.
///
/// ### Simple example — local-only
///
/// ```dart
/// final repo = LocalDataRepository<Todo>(
///   source: HiveTodoSource(),
/// );
///
/// await repo.create(Todo(id: 't1', title: 'Buy milk'));
/// final todo = await repo.getById('t1');
/// ```
///
/// ### Advanced example — local primary + remote backup with restore
///
/// ```dart
/// final repo = LocalDataRepository<Todo>(
///   id: 'todos',
///   source: HiveTodoSource(),
///   backup: FirestoreTodoSource(),
///   backupMode: true,
///   lazyMode: true,
///   restoreMode: true,
///   backupFlushInterval: const Duration(seconds: 15),
///   backupFlushSize: 25,
/// );
///
/// // On first launch — hydrate local from remote
/// await repo.restore();
///
/// // Mirror to remote in the background after every write
/// await repo.updateById('t1', {'done': true});
/// ```
class LocalDataRepository<T extends Entity> extends DataRepository<T> {
  LocalDataRepository({
    super.id,
    required super.source,
    super.backup,
    super.errorDelegate,
    super.lazyMode,
    super.backupMode,
    super.restoreMode,
    super.cacheMode,
    super.backupFlushInterval,
    super.backupFlushSize,
  }) : super.local();
}
