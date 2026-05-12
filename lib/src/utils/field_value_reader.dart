import 'package:collection/collection.dart' show DeepCollectionEquality;

import 'fetch_options.dart' show DataFetchOptions;
import 'query.dart' show DataQuery;
import 'selection.dart' show DataSelection;
import 'sorting.dart' show DataSorting;

const _eq = DeepCollectionEquality();

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
      _eq.hash(queries),
      _eq.hash(selections),
      _eq.hash(sorts),
      options,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataFieldValueQueryOptions &&
        _eq.equals(queries, other.queries) &&
        _eq.equals(selections, other.selections) &&
        _eq.equals(sorts, other.sorts) &&
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
  count;

  bool get isGet => this == get;

  bool get isFilter => this == filter;

  bool get isCount => this == count;
}

class DataFieldValueReader {
  final String path;
  final DataFieldValueReaderType type;
  final DataFieldValueQueryOptions? options;

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
          options: options,
        );

  @override
  int get hashCode => Object.hash(path, type, options);

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
