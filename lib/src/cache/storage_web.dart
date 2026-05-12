import 'package:web/web.dart' show window;

import 'storage_stub.dart' show CacheStorageAdapter;

export 'storage_stub.dart' show CacheStorageAdapter;

class _WebStorage extends CacheStorageAdapter {
  const _WebStorage(this._prefix);

  final String _prefix;

  String _k(String key) => '$_prefix$key';

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async =>
      window.localStorage.getItem(_k(key));

  @override
  Future<void> write(String key, String value) async =>
      window.localStorage.setItem(_k(key), value);

  @override
  Future<void> delete(String key) async =>
      window.localStorage.removeItem(_k(key));

  @override
  Future<void> clear() async {
    final toRemove = _allRawKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in toRemove) {
      window.localStorage.removeItem(k);
    }
  }

  @override
  Future<List<String>> keys({String? prefix}) async {
    final search = _prefix + (prefix ?? '');
    return _allRawKeys()
        .where((k) => k.startsWith(search))
        .map((k) => k.substring(_prefix.length))
        .toList();
  }

  List<String> _allRawKeys() {
    final length = window.localStorage.length;
    return [for (var i = 0; i < length; i++) window.localStorage.key(i) ?? '']
      ..removeWhere((k) => k.isEmpty);
  }
}

CacheStorageAdapter defaultCacheStorage({String prefix = 'cm:'}) =>
    _WebStorage(prefix);
