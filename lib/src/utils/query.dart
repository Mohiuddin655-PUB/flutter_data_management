import 'package:collection/collection.dart' show ListEquality;

import 'filter.dart' show DataFilter;

class DataQuery {
  static const _listEquality = ListEquality<Object?>();

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
  final List<Object?>? arrayContainsAny;
  final List<Object?>? arrayNotContainsAny;
  final List<Object?>? whereIn;
  final List<Object?>? whereNotIn;

  DataQuery(
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
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? arrayNotContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
  })  : arrayContainsAny = _freeze(arrayContainsAny),
        arrayNotContainsAny = _freeze(arrayNotContainsAny),
        whereIn = _freeze(whereIn),
        whereNotIn = _freeze(whereNotIn);

  DataQuery.filter(DataFilter filter) : this(filter);

  static List<Object?>? _freeze(Iterable<Object?>? source) =>
      source == null ? null : List<Object?>.unmodifiable(source);

  DataQuery adjust(
    String documentId,
    Object Function(Object field, String documentId) field,
    Object? Function(Object? value) value,
  ) {
    Object? convertValue(Object? v) => v == null ? null : value(v);
    List<Object?>? convertAllValues(List<Object?>? src) {
      return src?.map(value).toList(growable: false);
    }

    return DataQuery(
      field(this.field, documentId),
      isNull: isNull,
      isEqualTo: convertValue(isEqualTo),
      isNotEqualTo: convertValue(isNotEqualTo),
      isLessThan: convertValue(isLessThan),
      isLessThanOrEqualTo: convertValue(isLessThanOrEqualTo),
      isGreaterThan: convertValue(isGreaterThan),
      isGreaterThanOrEqualTo: convertValue(isGreaterThanOrEqualTo),
      arrayContains: convertValue(arrayContains),
      arrayNotContains: convertValue(arrayNotContains),
      arrayContainsAny: convertAllValues(arrayContainsAny),
      arrayNotContainsAny: convertAllValues(arrayNotContainsAny),
      whereIn: convertAllValues(whereIn),
      whereNotIn: convertAllValues(whereNotIn),
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
        arrayContainsAny == null ? null : _listEquality.hash(arrayContainsAny),
        arrayNotContainsAny == null
            ? null
            : _listEquality.hash(arrayNotContainsAny),
        whereIn == null ? null : _listEquality.hash(whereIn),
        whereNotIn == null ? null : _listEquality.hash(whereNotIn),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataQuery &&
        other.field == field &&
        other.isNull == isNull &&
        other.isEqualTo == isEqualTo &&
        other.isNotEqualTo == isNotEqualTo &&
        other.isLessThan == isLessThan &&
        other.isLessThanOrEqualTo == isLessThanOrEqualTo &&
        other.isGreaterThan == isGreaterThan &&
        other.isGreaterThanOrEqualTo == isGreaterThanOrEqualTo &&
        other.arrayContains == arrayContains &&
        other.arrayNotContains == arrayNotContains &&
        _listEquality.equals(other.arrayContainsAny, arrayContainsAny) &&
        _listEquality.equals(other.arrayNotContainsAny, arrayNotContainsAny) &&
        _listEquality.equals(other.whereIn, whereIn) &&
        _listEquality.equals(other.whereNotIn, whereNotIn);
  }

  @override
  String toString() {
    return 'DataQuery('
        'field: $field, '
        'isNull: $isNull, '
        'isEqualTo: $isEqualTo, '
        'isNotEqualTo: $isNotEqualTo, '
        'isLessThan: $isLessThan, '
        'isLessThanOrEqualTo: $isLessThanOrEqualTo, '
        'isGreaterThan: $isGreaterThan, '
        'isGreaterThanOrEqualTo: $isGreaterThanOrEqualTo, '
        'arrayContains: $arrayContains, '
        'arrayNotContains: $arrayNotContains, '
        'arrayContainsAny: $arrayContainsAny, '
        'arrayNotContainsAny: $arrayNotContainsAny, '
        'whereIn: $whereIn, '
        'whereNotIn: $whereNotIn)';
  }
}
