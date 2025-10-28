part of 'configs.dart';

enum DataFieldValues {
  arrayUnion,
  arrayRemove,
  delete,
  serverTimestamp,
  increment,
  none;

  bool get isArrayUnion => this == arrayUnion;

  bool get isArrayRemove => this == arrayRemove;

  bool get isDelete => this == delete;

  bool get isServerTimestamp => this == serverTimestamp;

  bool get isIncrement => this == increment;

  bool get isNone => this == none;
}

class DataFieldValue {
  final Object? value;
  final DataFieldValues type;

  const DataFieldValue(this.value, [this.type = DataFieldValues.none]);

  factory DataFieldValue.arrayUnion(List<dynamic> elements) {
    return DataFieldValue(elements, DataFieldValues.arrayUnion);
  }

  factory DataFieldValue.arrayRemove(List<dynamic> elements) {
    return DataFieldValue(elements, DataFieldValues.arrayRemove);
  }

  factory DataFieldValue.delete() {
    return const DataFieldValue(null, DataFieldValues.delete);
  }

  factory DataFieldValue.serverTimestamp() {
    return const DataFieldValue(null, DataFieldValues.serverTimestamp);
  }

  factory DataFieldValue.increment(num value) {
    return DataFieldValue(value, DataFieldValues.increment);
  }

  @override
  int get hashCode => value.hashCode ^ type.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DataFieldValue &&
        other.value == value &&
        other.type == type;
  }

  @override
  String toString() => "$DataFieldValue(value: $value, type: $type)";
}
