class UpdatingInfo {
  final String id;
  final Map<String, dynamic> data;

  const UpdatingInfo({
    required this.id,
    required this.data,
  });

  @override
  int get hashCode => id.hashCode ^ data.hashCode;

  @override
  bool operator ==(Object other) {
    return other is UpdatingInfo && other.id == id && other.data == data;
  }

  @override
  String toString() => "$UpdatingInfo#$hashCode(id: $id, data: $data)";
}
