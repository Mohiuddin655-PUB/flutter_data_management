part of 'base.dart';

mixin _RepoExecutorMixin<T extends Entity> {
  DataSource<T> get primary;

  DataSource<T>? get optional;

  DatabaseType get type;

  bool get isLocalDB;

  Future<bool> get isConnected;

  ErrorDelegate get errorDelegate;

  Future<Response<S>> _runOnPrimary<S extends Object>(
    Future<Response<S>> Function(DataSource<T> source) callback,
  ) async {
    try {
      if (!isLocalDB) {
        final connected = await isConnected;
        if (!connected) return Response(status: Status.networkError);
      }
      return await callback(primary);
    } catch (error, stack) {
      _report('runOnPrimary', error, stack);
      return Response(status: Status.failure, error: error.toString());
    }
  }

  void _runOnPrimaryLazy<S extends Object>(
    Future<Response<S>> Function(DataSource<T> source) callback,
  ) {
    _runOnPrimary(callback).catchError((Object error, StackTrace stack) {
      _report('runOnPrimaryLazy', error, stack);
      return Response<S>(status: Status.failure, error: error.toString());
    });
  }

  Future<Response<S>> _runOnBackup<S extends Object>(
    Future<Response<S>> Function(DataSource<T> source) callback,
  ) async {
    final backup = optional;
    if (backup == null) return Response(status: Status.undefined);
    try {
      if (isLocalDB) {
        final connected = await isConnected;
        if (!connected) return Response(status: Status.networkError);
      }
      return await callback(backup);
    } catch (error, stack) {
      _report('runOnBackup', error, stack);
      return Response(status: Status.failure, error: error.toString());
    }
  }

  void _runOnBackupLazy<S extends Object>(
    Future<Response<S>> Function(DataSource<T> source) callback,
  ) {
    _runOnBackup(callback).catchError((Object error, StackTrace stack) {
      _report('runOnBackupLazy', error, stack);
      return Response<S>(status: Status.failure, error: error.toString());
    });
  }

  Stream<Response<S>> _streamOnPrimary<S extends Object>(
    Stream<Response<S>> Function(DataSource<T> source) callback,
  ) async* {
    Stream<Response<S>> source;
    try {
      source = callback(primary);
    } catch (error, stack) {
      _report('streamOnPrimary.construct', error, stack);
      yield Response(status: Status.failure, error: error.toString());
      return;
    }
    try {
      yield* source;
    } catch (error, stack) {
      _report('streamOnPrimary.event', error, stack);
      yield Response<S>(status: Status.failure, error: error.toString());
    }
  }

  void _report(String operation, Object error, StackTrace stack) {
    errorDelegate.onError(
      DataOperationError(
        operation: 'repository.$operation',
        cause: error,
        stack: stack,
      ),
    );
  }
}
