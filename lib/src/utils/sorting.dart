class DataSorting {
  final String field;
  final bool descending;

  const DataSorting(this.field, {this.descending = false});

  @override
  int get hashCode => Object.hash(field, descending);

  @override
  bool operator ==(Object other) {
    return other is DataSorting &&
        other.field == field &&
        other.descending == descending;
  }

  @override
  String toString() {
    return "DataSorting(field: $field, descending: $descending)";
  }
}
