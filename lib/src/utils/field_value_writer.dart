import 'package:collection/collection.dart' show DeepCollectionEquality;

import 'set_options.dart' show DataSetOptions;

const _eq = DeepCollectionEquality();

enum DataFieldValueWriterType {
  set,
  update,
  delete;

  bool get isSet => this == set;

  bool get isUpdate => this == update;

  bool get isDelete => this == delete;
}

class DataFieldValueWriter {
  final String path;
  final DataFieldValueWriterType type;
  final Map<String, dynamic>? value;
  final DataSetOptions? options;

  const DataFieldValueWriter._({
    required this.path,
    required this.type,
    this.value,
    this.options,
  });

  const DataFieldValueWriter.delete(String path)
      : this._(path: path, type: DataFieldValueWriterType.delete);

  const DataFieldValueWriter.set(
    String path,
    Map<String, dynamic> value, {
    DataSetOptions options = const DataSetOptions(),
  }) : this._(
          path: path,
          type: DataFieldValueWriterType.set,
          value: value,
          options: options,
        );

  const DataFieldValueWriter.update(String path, Map<String, dynamic> value)
      : this._(path: path, type: DataFieldValueWriterType.update, value: value);

  @override
  int get hashCode => Object.hash(path, type, _eq.hash(value), options);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataFieldValueWriter &&
        path == other.path &&
        type == other.type &&
        _eq.equals(value, other.value) &&
        options == other.options;
  }

  @override
  String toString() {
    return "$DataFieldValueWriter#$hashCode(path: $path, type: $type, value: $value, options: $options)";
  }
}
