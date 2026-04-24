part of 'configs.dart';

class DataQuery {
  final Object field;
  final bool? isNull;
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

  const DataQuery(
    this.field, {
    this.isNull,
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
  });

  const DataQuery.filter(DataFilter filter) : this(filter);

  DataQuery adjust(Object? Function(Object? value) converter) {
    return DataQuery(
      field,
      isNull: isNull,
      isEqualTo: converter(isEqualTo),
      isNotEqualTo: converter(isNotEqualTo),
      isLessThan: converter(isLessThan),
      isLessThanOrEqualTo: converter(isLessThanOrEqualTo),
      isGreaterThan: converter(isGreaterThan),
      isGreaterThanOrEqualTo: converter(isGreaterThanOrEqualTo),
      arrayContains: converter(arrayContains),
      arrayNotContains: converter(arrayNotContains),
      arrayContainsAny: arrayContainsAny?.map(converter),
      arrayNotContainsAny: arrayNotContainsAny?.map(converter),
      whereIn: whereIn?.map(converter),
      whereNotIn: whereNotIn?.map(converter),
    );
  }

  @override
  int get hashCode => Object.hash(
        field,
        isNull,
        isEqualTo,
        isNotEqualTo,
        isLessThan,
        isLessThanOrEqualTo,
        isGreaterThan,
        isGreaterThanOrEqualTo,
        arrayContains,
        arrayNotContains,
        arrayContainsAny,
        arrayNotContainsAny,
        whereIn,
        whereNotIn,
      );

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
