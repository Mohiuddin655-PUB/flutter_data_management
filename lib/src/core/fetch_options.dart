part of 'configs.dart';

class DataFetchOptions {
  final bool fetchFromLast;
  final int? fetchingSize;
  final int? initialSize;

  const DataFetchOptions({
    int? initialFetchSize,
    this.fetchFromLast = false,
    this.fetchingSize,
  }) : initialSize = initialFetchSize ?? fetchingSize;

  const DataFetchOptions.limit(int value, [bool fetchFromLast = false])
      : this(fetchingSize: value, fetchFromLast: fetchFromLast);

  const DataFetchOptions.single([bool fetchFromLast = false])
      : this.limit(1, fetchFromLast);

  DataFetchOptions copy({
    bool? fetchFromLast,
    int? fetchingSize,
    int? initialSize,
  }) {
    return DataFetchOptions(
      initialFetchSize: initialSize ?? this.initialSize,
      fetchingSize: fetchingSize ?? this.fetchingSize,
      fetchFromLast: fetchFromLast ?? this.fetchFromLast,
    );
  }

  @override
  int get hashCode {
    return fetchFromLast.hashCode ^
        fetchingSize.hashCode ^
        initialSize.hashCode;
  }

  @override
  bool operator ==(Object other) {
    return other is DataFetchOptions &&
        other.fetchFromLast == fetchFromLast &&
        other.fetchingSize == fetchingSize &&
        other.initialSize == initialSize;
  }

  @override
  String toString() {
    return "$DataFetchOptions(fetchingSize: $fetchingSize, initialSize: $initialSize, fetchFromLast: $fetchFromLast)";
  }
}
