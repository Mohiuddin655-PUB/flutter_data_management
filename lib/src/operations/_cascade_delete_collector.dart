part of 'base.dart';

typedef GuardAsync = Future<T?> Function<T>(
  Future<T> Function() task, {
  required String operation,
  String? path,
  T? fallback,
});

class _CascadeDeleteCollector {
  final DataDelegate delegate;
  final GuardAsync guard;
  final bool counter;
  final Ignore? ignore;
  final int? maxLimit;

  final List<String> paths = [];
  final Set<String> _visited = {};

  _CascadeDeleteCollector({
    required this.delegate,
    required this.guard,
    required this.counter,
    required this.ignore,
    required this.maxLimit,
  });

  bool get _full => maxLimit != null && paths.length >= maxLimit!;

  bool _isIgnored(String key, dynamic value) =>
      ignore != null && ignore!(key, value);

  Future<void> _collect(String docPath) async {
    if (_full || !_visited.add(docPath)) return;

    final snap = await guard<DataGetSnapshot>(
      () => delegate.onGetById(docPath),
      operation: 'delete.collect',
      path: docPath,
    );
    if (snap == null || !snap.exists) return;

    await _scanDoc(snap.doc);
    if (!_full) paths.add(docPath);
  }

  Future<void> _scanDoc(Map<String, dynamic> doc) async {
    for (final entry in doc.entries) {
      if (_full) break;
      final key = entry.key;
      final value = entry.value;
      if (_isIgnored(key, value)) continue;
      if (key.startsWith('@')) {
        await _walkRef(value);
      } else if (counter && key.startsWith('#')) {
        await _walkCountable(value);
      }
    }
  }

  Future<void> _walkRef(dynamic value) async {
    if (_full || value == null) return;
    if (value is String) {
      if (value.isNotEmpty) await _collect(value);
    } else if (value is List) {
      for (final v in value) {
        if (_full) break;
        await _walkRef(v);
      }
    } else if (value is Map) {
      for (final v in value.values) {
        if (_full) break;
        await _walkRef(v);
      }
    }
  }

  Future<void> _walkCountable(dynamic value) async {
    if (_full || value == null) return;
    if (value is String) {
      if (value.isNotEmpty) await _collectChildren(value);
    } else if (value is List) {
      for (final v in value) {
        if (_full) break;
        await _walkCountable(v);
      }
    } else if (value is Map) {
      for (final v in value.values) {
        if (_full) break;
        await _walkCountable(v);
      }
    }
  }

  Future<void> _collectChildren(String collectionPath) async {
    final children = await guard<DataGetsSnapshot>(
      () => delegate.onGetByQuery(collectionPath),
      operation: 'delete.children',
      path: collectionPath,
    );
    if (children == null || !children.exists || children.docs.isEmpty) return;

    for (final child in children.docs) {
      if (_full) break;
      await _scanDoc(child);
      _addChildPath(collectionPath, child);
    }
  }

  void _addChildPath(String collectionPath, Map<String, dynamic> child) {
    final id = child['id'];
    if (id is! String || id.isEmpty || _full) return;
    final path = '$collectionPath/$id';
    if (_visited.add(path)) paths.add(path);
  }
}
