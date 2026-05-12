part of 'base.dart';

mixin _CreateMixin on _ErrorHandlingMixin, _WriteTransformMixin {
  DataDelegate get delegate;

  Future<void> _doCreate(
    String path,
    Map<String, dynamic> data, {
    required bool merge,
    required bool createRefs,
  }) async {
    final safe = Map<String, dynamic>.from(data);
    if (!createRefs) {
      await _guardAsync(
        () => delegate.onCreate(path, safe, merge),
        operation: 'create',
        path: path,
      );
      return;
    }
    await _guardAsync(
      () async {
        final batch = delegate.onBatch();
        final transformed = _transformWrite(batch, safe, merge);
        batch.onSet(path, transformed, merge: merge);
        await batch.onCommit();
      },
      operation: 'create.refs',
      path: path,
    );
  }
}
