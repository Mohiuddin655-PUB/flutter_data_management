part of 'configs.dart';

enum DataSelections {
  endAt,
  endAtDocument,
  endBefore,
  endBeforeDocument,
  startAfter,
  startAfterDocument,
  startAt,
  startAtDocument,
  none;

  bool get isNone => this == none;

  bool get isEndAt => this == endAt;

  bool get isEndAtDocument => this == endAtDocument;

  bool get isEndBefore => this == endBefore;

  bool get isEndBeforeDocument => this == endBeforeDocument;

  bool get isStartAfter => this == startAfter;

  bool get isStartAfterDocument => this == startAfterDocument;

  bool get isStartAt => this == startAt;

  bool get isStartAtDocument => this == startAtDocument;
}

class DataSelection {
  final Object? value;
  final DataSelections type;

  Iterable<Object?>? get values {
    return value is Iterable<Object?> ? value as Iterable<Object?> : null;
  }

  const DataSelection._(
    this.value, {
    this.type = DataSelections.none,
  });

  const DataSelection.empty() : this._(null);

  const DataSelection.from(Object? snapshot, DataSelections type)
      : this._(snapshot, type: type);

  const DataSelection.endAt(Iterable<Object?>? values)
      : this._(values, type: DataSelections.endAt);

  const DataSelection.endAtDocument(Object? snapshot)
      : this._(snapshot, type: DataSelections.endAtDocument);

  const DataSelection.endBefore(Iterable<Object?>? values)
      : this._(values, type: DataSelections.endBefore);

  const DataSelection.endBeforeDocument(Object? snapshot)
      : this._(snapshot, type: DataSelections.endBeforeDocument);

  const DataSelection.startAfter(Iterable<Object?>? values)
      : this._(values, type: DataSelections.startAfter);

  const DataSelection.startAfterDocument(Object? snapshot)
      : this._(snapshot, type: DataSelections.startAfterDocument);

  const DataSelection.startAt(Iterable<Object?>? values)
      : this._(values, type: DataSelections.startAt);

  const DataSelection.startAtDocument(Object? snapshot)
      : this._(snapshot, type: DataSelections.startAtDocument);

  @override
  int get hashCode => value.hashCode ^ type.hashCode;

  @override
  bool operator ==(Object other) {
    return other is DataSelection && other.value == value && other.type == type;
  }

  @override
  String toString() {
    return "$DataSelection(type: $type, value: $value)";
  }
}
