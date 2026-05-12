import 'package:collection/collection.dart' show DeepCollectionEquality;

const _eq = DeepCollectionEquality();

enum DataFilters {
  and,
  or,
  none;

  bool get isAndFilter => this == and;

  bool get isOrFilter => this == or;

  bool get isNoneFilter => this == none;
}

class DataFilter {
  final DataFilters type;
  final Object field;
  final Object? isEqualTo;
  final Object? isNotEqualTo;
  final Object? isLessThan;
  final Object? isLessThanOrEqualTo;
  final Object? isGreaterThan;
  final Object? isGreaterThanOrEqualTo;
  final Object? arrayContains;
  final Object? arrayNotContains;
  final Iterable<Object?>? arrayContainsAny;
  final Iterable<Object?>? arrayNotContainsAny;
  final Iterable<Object?>? whereIn;
  final Iterable<Object?>? whereNotIn;
  final bool? isNull;

  const DataFilter(
    this.field, {
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayNotContains,
    this.arrayContainsAny,
    this.arrayNotContainsAny,
    this.whereIn,
    this.whereNotIn,
    this.isNull,
  }) : type = DataFilters.none;

  const DataFilter._(
    this.field, {
    this.isEqualTo,
    this.isNotEqualTo,
    this.isLessThan,
    this.isLessThanOrEqualTo,
    this.isGreaterThan,
    this.isGreaterThanOrEqualTo,
    this.arrayContains,
    this.arrayNotContains,
    this.arrayContainsAny,
    this.arrayNotContainsAny,
    this.whereIn,
    this.whereNotIn,
    this.isNull,
    this.type = DataFilters.none,
  });

  const DataFilter.and(List<DataFilter> filters)
      : this._(filters, type: DataFilters.and);

  const DataFilter.or(List<DataFilter> filters)
      : this._(filters, type: DataFilters.or);

  @override
  int get hashCode {
    return Object.hashAll([
      type,
      field.toString(),
      isEqualTo,
      isNotEqualTo,
      isLessThan,
      isLessThanOrEqualTo,
      isGreaterThan,
      isGreaterThanOrEqualTo,
      arrayContains,
      arrayNotContains,
      _eq.hash(arrayContainsAny),
      _eq.hash(arrayNotContainsAny),
      _eq.hash(whereIn),
      _eq.hash(whereNotIn),
      isNull,
    ]);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataFilter &&
        type == other.type &&
        field == other.field &&
        isEqualTo == other.isEqualTo &&
        isNotEqualTo == other.isNotEqualTo &&
        isLessThan == other.isLessThan &&
        isLessThanOrEqualTo == other.isLessThanOrEqualTo &&
        isGreaterThan == other.isGreaterThan &&
        isGreaterThanOrEqualTo == other.isGreaterThanOrEqualTo &&
        arrayContains == other.arrayContains &&
        arrayNotContains == other.arrayNotContains &&
        _eq.equals(arrayContainsAny, other.arrayContainsAny) &&
        _eq.equals(arrayNotContainsAny, other.arrayNotContainsAny) &&
        _eq.equals(whereIn, other.whereIn) &&
        _eq.equals(whereNotIn, other.whereNotIn) &&
        isNull == other.isNull;
  }

  @override
  String toString() {
    return "$DataFilter(type: $type, field: $field, isEqualTo: $isEqualTo, isNotEqualTo: $isNotEqualTo, isLessThan: $isLessThan, isLessThanOrEqualTo: $isLessThanOrEqualTo, isGreaterThan: $isGreaterThan, isGreaterThanOrEqualTo: $isGreaterThanOrEqualTo, arrayContains: $arrayContains, arrayNotContains: $arrayNotContains, arrayContainsAny: $arrayContainsAny, arrayNotContainsAny: $arrayNotContainsAny, whereIn: $whereIn, whereNotIn: $whereNotIn, isNull: $isNull)";
  }
}
