import 'dart:async' show StreamController, StreamSubscription, Timer;

import 'package:flutter_entity/entity.dart' show Entity, Response, Status;
import 'package:meta/meta.dart' show protected;

import '../cache/base.dart' show CacheManager;
import '../operations/cache_delegate.dart' show DataCacheDelegate;
import '../operations/error_delegate.dart' show ErrorDelegate;
import '../operations/exception.dart' show DataOperationError;
import '../operations/typedefs.dart' show Ignore;
import '../operations/writers.dart' show DataBatchWriter;
import '../sources/base.dart' show DataSource;
import '../sources/local.dart' show LocalDataSource;
import '../sources/remote.dart' show RemoteDataSource;
import '../utils/checker.dart' show Checker;
import '../utils/database_type.dart' show DatabaseType;
import '../utils/fetch_options.dart' show DataFetchOptions;
import '../utils/modifiers.dart' show DataModifiers;
import '../utils/params.dart' show DataFieldParams;
import '../utils/query.dart' show DataQuery;
import '../utils/selection.dart' show DataSelection;
import '../utils/sorting.dart' show DataSorting;
import '../utils/updating_info.dart' show DataWriter;
import 'global.dart' show DM;

part '_repo_dual_write_mixin.dart';
part '_repo_executor_mixin.dart';
part '_repo_fallback_stream.dart';
part '_repo_listen_mixin.dart';
part '_repo_modifier_mixin.dart';
part '_repo_queue_mixin.dart';
part '_repo_queued_op.dart';
part '_repo_read_mixin.dart';
part '_repo_read_with_fallback_mixin.dart';
part '_repo_write_mixin.dart';

class DataRepository<T extends Entity>
    with
        _RepoExecutorMixin<T>,
        _RepoModifierMixin<T>,
        _RepoQueueMixin<T>,
        _RepoDualWriteMixin<T>,
        _RepoReadWithFallbackMixin<T>,
        _RepoReadMixin<T>,
        _RepoWriteMixin<T>,
        _RepoListenMixin<T> {
  final String? id;

  @override
  final DatabaseType type;

  @override
  final bool backupMode;

  @override
  final bool lazyMode;

  final bool restoreMode;

  @override
  final bool cacheMode;

  @override
  final bool queueMode;

  @override
  final DataSource<T> primary;

  @override
  final DataSource<T>? optional;

  @override
  final ErrorDelegate errorDelegate;

  @override
  final Duration backupFlushInterval;

  @override
  final int backupFlushSize;

  DataRepository.local({
    this.id,
    this.backupMode = true,
    this.lazyMode = true,
    this.restoreMode = true,
    this.cacheMode = false,
    this.queueMode = true,
    required LocalDataSource<T> source,
    RemoteDataSource<T>? backup,
    ErrorDelegate? errorDelegate,
    this.backupFlushInterval = const Duration(seconds: 30),
    this.backupFlushSize = 50,
  })  : type = DatabaseType.local,
        primary = source,
        optional = backup,
        errorDelegate = errorDelegate ?? ErrorDelegate.printing {
    _initQueue();
  }

  DataRepository.remote({
    this.id,
    this.backupMode = true,
    this.lazyMode = true,
    this.restoreMode = true,
    this.cacheMode = false,
    this.queueMode = true,
    required RemoteDataSource<T> source,
    LocalDataSource<T>? backup,
    ErrorDelegate? errorDelegate,
    this.backupFlushInterval = const Duration(seconds: 30),
    this.backupFlushSize = 50,
  })  : type = DatabaseType.remote,
        primary = source,
        optional = backup,
        errorDelegate = errorDelegate ?? ErrorDelegate.printing {
    _initQueue();
  }

  @override
  String get queueId =>
      id ?? '${type.name}:${primary.runtimeType}:${primary.path}';

  @override
  Future<bool> get isConnected => DM.i.isConnected;

  Future<bool> get isDisconnected async => !(await isConnected);

  @override
  bool get isLocalDB => type == DatabaseType.local;

  @protected
  @override
  Future<Response<T>> modifier(
    Response<T> value,
    DataModifiers modifier,
  ) async {
    return value;
  }

  Future<Response<void>> restore({
    DataFieldParams? params,
    bool onlyUpdates = false,
    bool? countable,
    bool? resolveRefs,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
    bool createRefs = false,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
    bool force = false,
  }) async {
    if (!restoreMode) {
      return Response(status: Status.canceled, error: 'restoreMode disabled');
    }
    if (!_shouldUseBackup(backupMode)) {
      return Response(status: Status.canceled, error: 'backup unavailable');
    }
    if (!force) {
      if (await _isRestored()) {
        return Response(status: Status.canceled, error: 'already restored');
      }
      final existing = await _runOnPrimary(
        (source) => source.count(params: params),
      );
      final hasData = existing.isSuccessful && (existing.data ?? 0) > 0;
      if (hasData) {
        await _markRestored();
        return Response(status: Status.canceled, error: 'primary has data');
      }
    }
    final backup = await _runOnBackup((source) {
      return source.get(
        params: params,
        countable: countable,
        resolveRefs: resolveRefs ?? createRefs,
        resolveDocChangesRefs: resolveDocChangesRefs,
        onlyUpdates: onlyUpdates,
        ignore: ignore,
      );
    });
    if (!backup.isValid) {
      return Response(status: backup.status, error: backup.error);
    }
    await _syncToPrimary(
      backup.result,
      params: params,
      createRefs: createRefs,
      merge: merge,
      useLazy: _shouldUseLazy(lazyMode),
    );
    await _markRestored();
    return Response(status: Status.ok);
  }

  Future<void> dispose() async {
    _disposeQueue();
  }
}
