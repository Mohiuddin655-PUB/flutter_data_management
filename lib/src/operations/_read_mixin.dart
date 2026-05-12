part of 'base.dart';

mixin _ReadMixin on _ErrorHandlingMixin {
  Future<int?> count(String path);

  Future<DataGetSnapshot> getById(
    String path, {
    bool countable = true,
    bool resolveRefs = false,
    Ignore? ignore,
  });

  Future<DataGetsSnapshot> getByQuery(
    String path, {
    Iterable<DataQuery> queries = const [],
    Iterable<DataSelection> selections = const [],
    Iterable<DataSorting> sorts = const [],
    DataFetchOptions options = const DataFetchOptions(),
    bool countable = true,
    bool resolveRefs = false,
    bool resolveDocChangesRefs = false,
    Ignore? ignore,
  });
}
