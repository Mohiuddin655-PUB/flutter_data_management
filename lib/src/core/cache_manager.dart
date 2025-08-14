import 'package:flutter_entity/entity.dart';

class DataCacheManager {
  static DataCacheManager? _i;

  static DataCacheManager get i => _i ??= DataCacheManager._();

  final Map<String, Response> _db = {};

  Iterable<String> get keys => _db.keys;

  Iterable<Response> get values => _db.values;

  DataCacheManager._();

  String hashKey(Type type, String name, [Iterable<Object?> props = const []]) {
    final key = [
      name,
      type.toString(),
      ...props.where((e) => e != null),
    ].join(':');
    final hash =
        key.codeUnits.fold<int>(0, (h, c) => (31 * h + c) & 0x7fffffff);
    return '$name:$type#$hash';
  }

  Future<Response<T>> cache<T extends Object>(
    String name, {
    bool? enabled,
    Iterable<Object?> keyProps = const [],
    required Future<Response<T>> Function() callback,
  }) async {
    enabled ??= false;
    if (!enabled) return callback();
    final k = hashKey(T, name, keyProps);
    final x = _db[k];
    if (x is Response<T> && x.isValid) return x;
    final y = await callback();
    if (y.isValid) _db[k] = y;
    return y;
  }

  Response<T>? pick<T extends Object>(String key) {
    final x = _db[key];
    if (x is Response<T>) return x;
    return null;
  }

  void remove(String key) => _db.remove(key);

  void clear() => _db.clear();
}
