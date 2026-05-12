import 'package:collection/collection.dart' show MapEquality;

class DataWriter {
  static const _eq = MapEquality<String, dynamic>();

  final String id;
  final Map<String, dynamic> data;

  DataWriter({required this.id, required Map<String, dynamic> data})
      : data = Map<String, dynamic>.unmodifiable(data);

  @override
  int get hashCode => Object.hash(id, _eq.hash(data));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataWriter &&
        other.id == id &&
        _eq.equals(other.data, data);
  }

  @override
  String toString() => 'DataWriter(id: $id, data: $data)';
}
