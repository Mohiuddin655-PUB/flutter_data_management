import 'dart:convert' show jsonDecode, jsonEncode;

import 'package:hive_flutter/adapters.dart' show Hive, Box;
import 'package:in_app_database/in_app_database.dart'
    show InAppDatabaseDelegate, InAppWriteLimitation, PathDetails;

class HiveDatabase {
  const HiveDatabase._();

  static Future<bool> _execute(void Function() executor) async {
    try {
      executor();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> init(String name) async {
    try {
      await Hive.openBox<String?>(name);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Box<String?> of(String name) => Hive.box<String?>(name);

  static Iterable<String> keys(String name) {
    return of(name).keys.whereType<String>();
  }

  static Object? read(String name, String key, [bool parsed = false]) {
    final source = of(name).get(key);
    if (source == null || source.isEmpty) return null;
    if (!parsed) return source;
    final data = jsonDecode(source);
    if (data is! Map || data.isEmpty) return null;
    return data;
  }

  static Future<bool> write(String name, String key, [Object? value]) {
    return _execute(() async {
      if (value is String && value.isNotEmpty) {
        return of(name).put(key, value);
      }
      if (value is Map && value.isNotEmpty) {
        return of(name).put(key, jsonEncode(value));
      }
      return of(name).delete(key);
    });
  }

  static Future<bool> delete(String name, String key) {
    return _execute(() => of(name).delete(key));
  }

  static Future<bool> close(String name) {
    return _execute(() => of(name).close());
  }
}

class LocalDatabaseDelegate extends InAppDatabaseDelegate {
  @override
  Future<bool> init(String name) {
    return HiveDatabase.init(name);
  }

  @override
  Future<Iterable<String>> paths(String name) async {
    return HiveDatabase.keys(name);
  }

  @override
  Future<bool> drop(String name) {
    return HiveDatabase.close(name);
  }

  @override
  Future<bool> delete(String name, String key) {
    return HiveDatabase.delete(name, key);
  }

  @override
  Future<Object?> read(String name, String key) async {
    return HiveDatabase.read(name, key);
  }

  @override
  Future<bool> write(String name, String key, Object? value) {
    return HiveDatabase.write(name, key, value);
  }

  @override
  Future<InAppWriteLimitation?> limitation(
    String name,
    PathDetails details,
  ) async {
    return {}[details.format];
  }
}
