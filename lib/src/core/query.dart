part of 'configs.dart';

class DataQuery {
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

  const DataQuery(
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
  });

  const DataQuery.filter(DataFilter filter) : this(filter);

  @override
  int get hashCode =>
      field.hashCode ^
      isEqualTo.hashCode ^
      isNotEqualTo.hashCode ^
      isLessThan.hashCode ^
      isLessThanOrEqualTo.hashCode ^
      isGreaterThan.hashCode ^
      isGreaterThanOrEqualTo.hashCode ^
      arrayContains.hashCode ^
      arrayNotContains.hashCode ^
      arrayContainsAny.hashCode ^
      arrayNotContainsAny.hashCode ^
      whereIn.hashCode ^
      whereNotIn.hashCode ^
      isNull.hashCode;

  @override
  bool operator ==(Object other) {
    return other is DataQuery &&
        other.field == field &&
        other.isEqualTo == isEqualTo &&
        other.isNotEqualTo == isNotEqualTo &&
        other.isLessThan == isLessThan &&
        other.isLessThanOrEqualTo == isLessThanOrEqualTo &&
        other.isGreaterThan == isGreaterThan &&
        other.isGreaterThanOrEqualTo == isGreaterThanOrEqualTo &&
        other.arrayContains == arrayContains &&
        other.arrayNotContains == arrayNotContains &&
        other.arrayContainsAny == arrayContainsAny &&
        other.arrayNotContainsAny == arrayNotContainsAny &&
        other.whereIn == whereIn &&
        other.whereNotIn == whereNotIn &&
        other.isNull == isNull;
  }

  @override
  String toString() {
    return "$DataQuery(field: $field, isEqualTo: $isEqualTo, isNotEqualTo: $isNotEqualTo, isLessThan: $isLessThan, isLessThanOrEqualTo: $isLessThanOrEqualTo, isGreaterThan: $isGreaterThan, isGreaterThanOrEqualTo: $isGreaterThanOrEqualTo, arrayContains: $arrayContains, arrayNotContains: $arrayNotContains, arrayContainsAny: $arrayContainsAny, arrayNotContainsAny: $arrayNotContainsAny, whereIn: $whereIn, whereNotIn: $whereNotIn, isNull: $isNull)";
  }
}
