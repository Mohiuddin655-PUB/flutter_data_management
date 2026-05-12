abstract class DataWriteBatch {
  bool _committed = false;
  int _operationCount = 0;

  int get operationCount => _operationCount;

  bool get isEmpty => _operationCount == 0;

  bool get isNotEmpty => _operationCount > 0;

  bool get isCommitted => _committed;

  void _ensureNotCommitted() {
    if (_committed) {
      throw StateError(
        'DataWriteBatch has already been committed and cannot be reused.',
      );
    }
  }

  void set(String path, Object data, {bool merge = true});

  void onSet(String path, Object data, {bool merge = true}) {
    _ensureNotCommitted();
    final payload =
        data is Map<String, dynamic> ? Map<String, dynamic>.from(data) : data;
    set(path, payload, merge: merge);
    _operationCount++;
  }

  void update(String path, Map<String, dynamic> data);

  void onUpdate(String path, Map<String, dynamic> data) {
    _ensureNotCommitted();
    update(path, Map<String, dynamic>.from(data));
    _operationCount++;
  }

  void delete(String path);

  void onDelete(String path) {
    _ensureNotCommitted();
    delete(path);
    _operationCount++;
  }

  Future<void> commit();

  Future<void> onCommit() async {
    _ensureNotCommitted();
    _committed = true;
    await commit();
  }
}
