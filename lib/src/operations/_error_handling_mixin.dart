part of 'base.dart';

mixin _ErrorHandlingMixin {
  ErrorDelegate get errorDelegate;

  Future<T?> _guardAsync<T>(
    Future<T> Function() task, {
    required String operation,
    String? path,
    T? fallback,
  }) async {
    try {
      return await task();
    } catch (e, s) {
      errorDelegate.onError(
        DataOperationError(
          operation: operation,
          path: path,
          cause: e,
          stack: s,
        ),
      );
      return fallback;
    }
  }

  Stream<T> _guardStream<T>(
    Stream<T> Function() source, {
    required String operation,
    required String path,
    required T empty,
  }) async* {
    try {
      yield* source().handleError((Object e, StackTrace s) {
        errorDelegate.onError(
          DataOperationError(
            operation: operation,
            path: path,
            cause: e,
            stack: s,
          ),
        );
      });
    } catch (e, s) {
      errorDelegate.onError(
        DataOperationError(
          operation: operation,
          path: path,
          cause: e,
          stack: s,
        ),
      );
      yield empty;
    }
  }
}
