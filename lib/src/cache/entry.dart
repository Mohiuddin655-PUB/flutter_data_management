import 'package:flutter_entity/entity.dart' show Response;

class CacheEntry {
  final Response response;
  final DateTime? expiresAt;

  const CacheEntry(this.response, this.expiresAt);

  bool get isExpired {
    final exp = expiresAt;
    return exp != null && DateTime.now().isAfter(exp);
  }
}
