part of 'configs.dart';

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
  String toString() {
    return "$DataFilter(type: $type, field: $field, isEqualTo: $isEqualTo, isNotEqualTo: $isNotEqualTo, isLessThan: $isLessThan, isLessThanOrEqualTo: $isLessThanOrEqualTo, isGreaterThan: $isGreaterThan, isGreaterThanOrEqualTo: $isGreaterThanOrEqualTo, arrayContains: $arrayContains, arrayNotContains: $arrayNotContains, arrayContainsAny: $arrayContainsAny, arrayNotContainsAny: $arrayNotContainsAny, whereIn: $whereIn, whereNotIn: $whereNotIn, isNull: $isNull)";
  }
}
