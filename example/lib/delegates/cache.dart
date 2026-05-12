import 'package:data_management/data_management.dart' show DataCacheDelegate;
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

class CacheDelegate extends DataCacheDelegate {
  @override
  Future<String?> read(String storageKey) async {
    final inst = await SharedPreferences.getInstance();
    return inst.getString(storageKey);
  }

  @override
  Future<void> write(String storageKey, String? value) async {
    final inst = await SharedPreferences.getInstance();
    if (value == null) {
      await inst.remove(storageKey);
      return;
    }
    await inst.setString(storageKey, value);
  }
}
