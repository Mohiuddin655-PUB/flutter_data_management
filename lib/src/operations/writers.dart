import 'package:collection/collection.dart' show DeepCollectionEquality;

import '../utils/set_options.dart' show DataSetOptions;

const _e = DeepCollectionEquality();

abstract class DataBatchWriter {
  final String path;

  const DataBatchWriter(this.path);

  @override
  int get hashCode => path.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    return other is DataBatchWriter && other.path == path;
  }

  @override
  String toString() => '$runtimeType#$hashCode{path: $path}';
}

class DataSetWriter<T> extends DataBatchWriter {
  final T data;
  final DataSetOptions options;

  const DataSetWriter(
    super.path,
    this.data, [
    this.options = const DataSetOptions(),
  ]);

  @override
  int get hashCode => Object.hash(path, data, options);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DataSetWriter<T>) return false;
    if (other.path != path) return false;
    if (other.data != data) return false;
    if (other.options != options) return false;
    return true;
  }

  @override
  String toString() {
    return '$runtimeType#$hashCode{path: $path, data: $data, options: $options}';
  }
}

class DataUpdateWriter extends DataBatchWriter {
  final Map<String, dynamic> data;

  const DataUpdateWriter(super.path, this.data);

  @override
  int get hashCode => Object.hash(path, _e.hash(data));

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DataUpdateWriter) return false;
    if (other.path != path) return false;
    return _e.equals(other.data, data);
  }

  @override
  String toString() {
    return '$runtimeType#$hashCode{path: $path, data: $data}';
  }
}

class DataDeleteWriter extends DataBatchWriter {
  const DataDeleteWriter(super.path);

  @override
  String toString() {
    return '$runtimeType#$hashCode{path: $path}';
  }
}
