import 'package:collection/collection.dart' show ListEquality;

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
  static const _listEquality = ListEquality<Object?>();

  final Object? value;
  final DataSelections type;

  const DataSelection._(this.value, {this.type = DataSelections.none});

  const DataSelection.empty() : this._(null);

  const DataSelection.from(Object? snapshot, DataSelections type)
      : this._(snapshot, type: type);

  DataSelection.endAt(Iterable<Object?>? values)
      : this._(_freeze(values), type: DataSelections.endAt);

  const DataSelection.endAtDocument(Object? snapshot)
      : this._(snapshot, type: DataSelections.endAtDocument);

  DataSelection.endBefore(Iterable<Object?>? values)
      : this._(_freeze(values), type: DataSelections.endBefore);

  const DataSelection.endBeforeDocument(Object? snapshot)
      : this._(snapshot, type: DataSelections.endBeforeDocument);

  DataSelection.startAfter(Iterable<Object?>? values)
      : this._(_freeze(values), type: DataSelections.startAfter);

  const DataSelection.startAfterDocument(Object? snapshot)
      : this._(snapshot, type: DataSelections.startAfterDocument);

  DataSelection.startAt(Iterable<Object?>? values)
      : this._(_freeze(values), type: DataSelections.startAt);

  const DataSelection.startAtDocument(Object? snapshot)
      : this._(snapshot, type: DataSelections.startAtDocument);

  static List<Object?>? _freeze(Iterable<Object?>? source) =>
      source == null ? null : List<Object?>.unmodifiable(source);

  List<Object?>? get values {
    final v = value;
    return v is List<Object?> ? v : null;
  }

  @override
  int get hashCode {
    final v = value;
    final valueHash = v is List<Object?> ? _listEquality.hash(v) : v.hashCode;
    return Object.hash(valueHash, type);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DataSelection || other.type != type) return false;
    final a = value;
    final b = other.value;
    if (a is List<Object?> && b is List<Object?>) {
      return _listEquality.equals(a, b);
    }
    return a == b;
  }

  @override
  String toString() => 'DataSelection(type: $type, value: $value)';
}
