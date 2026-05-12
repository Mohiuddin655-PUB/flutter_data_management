import 'dart:convert' show jsonDecode, jsonEncode;

abstract class DataCacheDelegate {
  static const _separator = '::';
  static const _indexSuffix = '__index__';

  Future<String?> read(String storageKey);

  Future<void> write(String storageKey, String? value);

  String _entryKey(String key, String entryId) => '$key$_separator$entryId';

  String _indexKey(String key) => '$key$_separator$_indexSuffix';

  Future<List<String>> _readIndex(String key) async {
    final raw = await read(_indexKey(key));
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _writeIndex(String key, List<String> ids) async {
    await write(_indexKey(key), ids.isEmpty ? null : jsonEncode(ids));
  }

  Future<void> onPush(
    String key,
    String entryId,
    Map<String, dynamic> entry,
  ) async {
    await write(_entryKey(key, entryId), jsonEncode(entry));
    final ids = await _readIndex(key);
    if (!ids.contains(entryId)) {
      ids.add(entryId);
      await _writeIndex(key, ids);
    }
  }

  Future<List<MapEntry<String, Map<String, dynamic>>>> onReadAll(
    String key,
  ) async {
    final ids = await _readIndex(key);
    if (ids.isEmpty) return [];
    final out = <MapEntry<String, Map<String, dynamic>>>[];
    final stale = <String>[];
    for (final id in ids) {
      final raw = await read(_entryKey(key, id));
      if (raw == null || raw.isEmpty) {
        stale.add(id);
        continue;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          out.add(MapEntry(id, decoded.cast<String, dynamic>()));
        } else {
          stale.add(id);
        }
      } catch (_) {
        stale.add(id);
      }
    }
    if (stale.isNotEmpty) {
      final cleaned = ids.where((e) => !stale.contains(e)).toList();
      await _writeIndex(key, cleaned);
    }
    return out;
  }

  Future<bool> onExists(String key, String entryId) async {
    final raw = await read(_entryKey(key, entryId));
    return raw != null && raw.isNotEmpty;
  }

  Future<void> onRemove(String key, String entryId) async {
    await write(_entryKey(key, entryId), null);
    final ids = await _readIndex(key);
    if (ids.remove(entryId)) {
      await _writeIndex(key, ids);
    }
  }

  Future<void> onClear(String key) async {
    final ids = await _readIndex(key);
    for (final id in ids) {
      await write(_entryKey(key, id), null);
    }
    await write(_indexKey(key), null);
  }
}
