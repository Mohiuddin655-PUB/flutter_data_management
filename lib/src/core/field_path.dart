part of 'configs.dart';

enum DataFieldPaths {
  documentId,
  none;

  bool get isDocumentId => this == documentId;

  bool get isNone => this == none;
}

class DataFieldPath {
  final Object? field;
  final DataFieldPaths type;

  const DataFieldPath(
    this.field, [
    this.type = DataFieldPaths.none,
  ]);

  static DataFieldPath get documentId {
    return const DataFieldPath(null, DataFieldPaths.documentId);
  }

  @override
  String toString() => "$DataFieldPath(field: $field, type: $type)";
}
