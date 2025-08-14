part of 'configs.dart';

class DataPagingOptions {
  final bool fetchFromLast;
  final int? fetchingSize;
  final int? initialSize;

  const DataPagingOptions({
    int? initialFetchSize,
    this.fetchFromLast = false,
    this.fetchingSize,
  }) : initialSize = initialFetchSize ?? fetchingSize;

  DataPagingOptions copy({
    bool? fetchFromLast,
    int? fetchingSize,
    int? initialSize,
  }) {
    return DataPagingOptions(
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
    return other is DataPagingOptions &&
        other.fetchFromLast == fetchFromLast &&
        other.fetchingSize == fetchingSize &&
        other.initialSize == initialSize;
  }

  @override
  String toString() {
    return "$DataPagingOptions(fetchingSize: $fetchingSize, initialSize: $initialSize, fetchFromLast: $fetchFromLast)";
  }
}
