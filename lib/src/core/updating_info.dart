class DataWriter {
  final String id;
  final Map<String, dynamic> data;

  const DataWriter({
    required this.id,
    required this.data,
  });

  @override
  int get hashCode => id.hashCode ^ data.hashCode;

  @override
  bool operator ==(Object other) {
    return other is DataWriter && other.id == id && other.data == data;
  }

  @override
  String toString() => "$DataWriter(id: $id, data: $data)";
}
