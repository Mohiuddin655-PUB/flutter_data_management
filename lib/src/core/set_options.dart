class DataSetOptions {
  final bool merge;

  const DataSetOptions({this.merge = true});

  @override
  int get hashCode => merge.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataSetOptions && merge == other.merge;
  }

  @override
  String toString() {
    return "$DataSetOptions#$hashCode(merge: $merge)";
  }
}
