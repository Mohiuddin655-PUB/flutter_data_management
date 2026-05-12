abstract class CacheStorageAdapter {
  const CacheStorageAdapter();

  Future<void> init();

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> clear();

  Future<List<String>> keys({String? prefix});
}

class _NoOpStorage extends CacheStorageAdapter {
  const _NoOpStorage();

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {}

  @override
  Future<void> delete(String key) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<List<String>> keys({String? prefix}) async => const [];
}

CacheStorageAdapter defaultCacheStorage({String prefix = 'cm:'}) =>
    const _NoOpStorage();
