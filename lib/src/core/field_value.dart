part of 'configs.dart';

enum DataFieldValues {
  arrayUnion,
  arrayRemove,
  delete,
  serverTimestamp,
  increment,
  none;

  bool get isArrayUnion => this == arrayUnion;

  bool get isArrayRemove => this == arrayRemove;

  bool get isDelete => this == delete;

  bool get isServerTimestamp => this == serverTimestamp;

  bool get isIncrement => this == increment;

  bool get isNone => this == none;
}

class DataFieldWriteRef {
  final String path;
  final List<Map<String, dynamic>> create;
  final List<Map<String, dynamic>> update;
  final List<String> delete;

  bool get isNotEmpty {
    return path.isNotEmpty &&
        (create.isNotEmpty || update.isNotEmpty || delete.isNotEmpty);
  }

  const DataFieldWriteRef(
    this.path, {
    this.create = const [],
    this.update = const [],
    this.delete = const [],
  });

  Map<String, dynamic> get metadata {
    return {
      "path": path,
      if (create.isNotEmpty) "create": create,
      if (update.isNotEmpty) "update": update,
      if (delete.isNotEmpty) "delete": delete,
    };
  }

  @override
  int get hashCode => Object.hash(path, create, update, delete);

  @override
  operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DataFieldWriteRef) return false;
    return path == other.path &&
        create == other.create &&
        delete == other.delete &&
        update == other.update;
  }

  @override
  String toString() {
    return '$DataFieldWriteRef(path: $path, create: $create, delete: $delete, update: $update)';
  }
}

class DataFieldValue {
  final Object? value;
  final DataFieldValues type;

  const DataFieldValue(this.value, [this.type = DataFieldValues.none]);

  factory DataFieldValue.arrayUnion(List<dynamic> elements) {
    return DataFieldValue(elements, DataFieldValues.arrayUnion);
  }

  factory DataFieldValue.arrayRemove(List<dynamic> elements) {
    return DataFieldValue(elements, DataFieldValues.arrayRemove);
  }

  factory DataFieldValue.delete() {
    return const DataFieldValue(null, DataFieldValues.delete);
  }

  factory DataFieldValue.serverTimestamp() {
    return const DataFieldValue(null, DataFieldValues.serverTimestamp);
  }

  factory DataFieldValue.increment(num value) {
    return DataFieldValue(value, DataFieldValues.increment);
  }

  factory DataFieldValue.write(
    String path, {
    List<Map<String, dynamic>>? create,
    List<Map<String, dynamic>>? update,
    List<String>? delete,
  }) {
    return DataFieldValue(
      DataFieldWriteRef(
        path,
        create: create ?? [],
        update: update ?? [],
        delete: delete ?? [],
      ),
      DataFieldValues.none,
    );
  }

  @override
  int get hashCode => value.hashCode ^ type.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataFieldValue &&
        other.value == value &&
        other.type == type;
  }

  @override
  String toString() => "$DataFieldValue(value: $value, type: $type)";
}
