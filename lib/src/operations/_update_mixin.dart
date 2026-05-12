part of 'base.dart';

mixin _UpdateMixin on _ErrorHandlingMixin, _WriteTransformMixin {
  DataDelegate get delegate;

  Future<void> _doUpdate(
    String path,
    Map<String, dynamic> data, {
    required bool updateRefs,
  }) async {
    final safe = Map<String, dynamic>.from(data);
    if (!updateRefs) {
      await _guardAsync(
        () => delegate.onUpdate(path, safe),
        operation: 'update',
        path: path,
      );
      return;
    }
    await _guardAsync(
      () async {
        final batch = delegate.onBatch();
        final processed = _transformWrite(batch, safe, true);
        batch.onUpdate(path, processed);
        await batch.onCommit();
      },
      operation: 'update.refs',
      path: path,
    );
  }
}
