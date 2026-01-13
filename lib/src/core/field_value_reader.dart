import 'configs.dart';

class DataFieldValueQueryOptions {
  final Iterable<DataQuery> queries;
  final Iterable<DataSelection> selections;
  final Iterable<DataSorting> sorts;
  final DataFetchOptions options;

  const DataFieldValueQueryOptions({
    this.queries = const [],
    this.selections = const [],
    this.sorts = const [],
    this.options = const DataFetchOptions(),
  });

  @override
  int get hashCode {
    return Object.hash(
      queries.toString(),
      selections.toString(),
      sorts.toString(),
      options.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataFieldValueQueryOptions &&
        queries == other.queries &&
        selections == other.selections &&
        sorts == other.sorts &&
        options == other.options;
  }

  @override
  String toString() {
    return "$DataFieldValueQueryOptions#$hashCode(queries: $queries, selections: $selections, sorts: $sorts, options: $options)";
  }
}

enum DataFieldValueReaderType {
  get,
  filter,
  count,
}

class DataFieldValueReader {
  final String path;
  final DataFieldValueReaderType type;
  final Object? options;

  const DataFieldValueReader._({
    required this.path,
    required this.type,
    this.options,
  });

  const DataFieldValueReader.count(String path)
      : this._(path: path, type: DataFieldValueReaderType.count);

  const DataFieldValueReader.get(String path)
      : this._(path: path, type: DataFieldValueReaderType.get);

  const DataFieldValueReader.filter(
    String path,
    DataFieldValueQueryOptions options,
  ) : this._(
            path: path,
            type: DataFieldValueReaderType.filter,
            options: options);

  @override
  int get hashCode {
    return Object.hash(
      path,
      type,
      options.toString(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataFieldValueReader &&
        path == other.path &&
        type == other.type &&
        options == other.options;
  }

  @override
  String toString() {
    return "$DataFieldValueReader#$hashCode(path: $path, type: $type, options: $options)";
  }
}
