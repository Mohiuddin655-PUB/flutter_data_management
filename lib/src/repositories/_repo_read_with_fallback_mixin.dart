part of 'base.dart';

mixin _RepoReadWithFallbackMixin<T extends Entity>
    on _RepoExecutorMixin<T>, _RepoModifierMixin<T> {
  Future<Response<T>> _readWithFallback({
    required DataModifiers modifierId,
    required Future<Response<T>> Function(DataSource<T> source) read,
    DataFieldParams? params,
    bool? createRefs,
    bool resolveRefs = false,
    bool merge = true,
    bool? lazyMode,
    bool? backupMode,
    bool? cacheMode,
    String? cacheKey,
    List<Object?> cacheKeyProps = const [],
  }) {
    return _applyModifier<T>(modifierId, () async {
      Response<T> feedback;
      if (cacheKey == null) {
        feedback = await _runOnPrimary(read);
      } else {
        feedback = await CacheManager.i.cache(
          cacheKey,
          enabled: _shouldUseCache(cacheMode),
          keyProps: cacheKeyProps,
          callback: () => _runOnPrimary(read),
        );
      }

      if (feedback.isValid) {
        if (!_shouldUseBackup(backupMode)) return feedback;
        await _syncToBackup(
          feedback.result,
          params: params,
          createRefs: createRefs ?? resolveRefs,
          merge: merge,
          useLazy: _shouldUseLazy(lazyMode),
        );
        return feedback;
      }

      if (!_shouldUseBackup(backupMode)) return feedback;

      final backup = await _runOnBackup(read);
      return backup;
    });
  }

  Future<void> _syncToBackup(
    Iterable<T> result, {
    required DataFieldParams? params,
    required bool createRefs,
    required bool merge,
    required bool useLazy,
  }) async {
    if (result.isEmpty) return;
    if (optional == null) return;
    final writers = result.map((e) => DataWriter(id: e.id, data: e.filtered));
    Future<Response<T>> task(DataSource<T> source) {
      return source.creates(
        writers,
        params: params,
        createRefs: createRefs,
        merge: merge,
      );
    }

    if (useLazy) {
      _runOnBackupLazy(task);
    } else {
      await _runOnBackup(task);
    }
  }

  Future<void> _syncToPrimary(
    Iterable<T> result, {
    required DataFieldParams? params,
    required bool createRefs,
    required bool merge,
    required bool useLazy,
  }) async {
    if (result.isEmpty) return;
    if (optional == null) return;
    final writers = result.map((e) => DataWriter(id: e.id, data: e.filtered));
    Future<Response<T>> task(DataSource<T> source) {
      return source.creates(
        writers,
        params: params,
        createRefs: createRefs,
        merge: merge,
      );
    }

    if (useLazy) {
      _runOnPrimaryLazy(task);
    } else {
      await _runOnPrimary(task);
    }
  }
}
