import 'package:flutter_entity/flutter_entity.dart' show EntityKey;

extension DataMapHelper on Map<String, dynamic>? {
  String? get id => (this ?? {})[EntityKey.i.id];

  Map<String, dynamic> withId(String id) {
    return (this ?? {})..addAll({EntityKey.i.id: id});
  }
}
