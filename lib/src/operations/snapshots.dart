class DataGetSnapshot {
  final Map<String, dynamic> doc;
  final Object? snapshot;

  bool get exists => doc.isNotEmpty;

  const DataGetSnapshot({Map<String, dynamic>? doc, this.snapshot})
      : doc = doc ?? const {};

  DataGetSnapshot copyWith({Map<String, dynamic>? doc, Object? snapshot}) {
    return DataGetSnapshot(
      doc: doc ?? this.doc,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

class DataGetsSnapshot {
  final Iterable<Map<String, dynamic>> docs;
  final Iterable<Map<String, dynamic>> docChanges;
  final Object? snapshot;

  bool get exists => docs.isNotEmpty;

  const DataGetsSnapshot({
    this.docs = const [],
    this.docChanges = const [],
    this.snapshot,
  });

  DataGetsSnapshot copyWith({
    Iterable<Map<String, dynamic>>? docs,
    Iterable<Map<String, dynamic>>? docChanges,
    Object? snapshot,
  }) {
    return DataGetsSnapshot(
      docs: docs ?? this.docs,
      docChanges: docChanges ?? this.docChanges,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}

class DataAggregateSnapshot {
  final int? count;
  final Object? snapshot;

  const DataAggregateSnapshot({this.count, this.snapshot});

  DataAggregateSnapshot copyWith({
    int? count,
    Iterable<Map<String, dynamic>>? docs,
    Object? snapshot,
  }) {
    return DataAggregateSnapshot(
      count: count ?? this.count,
      snapshot: snapshot ?? this.snapshot,
    );
  }
}
