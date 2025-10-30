import 'set_options.dart';

enum DataFieldValueWriterType {
  set,
  update,
  delete,
}

class DataFieldValueWriter {
  final String path;
  final DataFieldValueWriterType type;
  final Map<String, dynamic>? value;
  final Object? options;

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
  int get hashCode {
    return Object.hash(
      path,
      type,
      value.toString(),
      options.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataFieldValueWriter &&
        path == other.path &&
        type == other.type &&
        value == other.value &&
        options == other.options;
  }

  @override
  String toString() {
    return "$DataFieldValueWriter#$hashCode(path: $path, type: $type, value: $value, options: $options)";
  }
}
