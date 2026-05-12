part of 'base.dart';

mixin _RepoDualWriteMixin<T extends Entity>
    on _RepoExecutorMixin<T>, _RepoModifierMixin<T>, _RepoQueueMixin<T> {
  Future<Response<T>> _dualWrite(
    DataModifiers modifierId, {
    required Future<Response<T>> Function(DataSource<T> source) write,
    required _DataQueuedOp Function() opBuilder,
    bool? backupMode,
    bool? lazyMode,
    bool? queueMode,
  }) {
    return _applyModifier<T>(modifierId, () async {
      final primaryResponse = await _runOnPrimary(write);

      if (isLocalDB) {
        if (!primaryResponse.isSuccessful) return primaryResponse;
        if (_shouldUseBackup(backupMode)) {
          _scheduleBackup(opBuilder());
        }
        return primaryResponse;
      }

      if (primaryResponse.status == Status.networkError) {
        if (_shouldUseQueue(queueMode)) {
          await _enqueuePrimary(opBuilder());
          if (_shouldUseBackup(backupMode)) {
            _runOnBackupLazy(write);
          }
          return Response(status: Status.ok);
        }
        return primaryResponse;
      }

      if (!primaryResponse.isSuccessful) return primaryResponse;
      if (!_shouldUseBackup(backupMode)) return primaryResponse;

      if (_shouldUseLazy(lazyMode)) {
        _runOnBackupLazy(write);
      } else {
        await _runOnBackup(write);
      }
      return primaryResponse;
    });
  }
}
