part of 'base.dart';

enum _DataQueuedOpKind {
  create,
  creates,
  updateById,
  updateByWriters,
  deleteById,
  deleteByIds,
  clear,
}

class _DataQueuedOp {
  final String id;
  final _DataQueuedOpKind kind;
  final String? entityId;
  final Map<String, dynamic>? data;
  final List<String>? ids;
  final List<Map<String, dynamic>>? writers;
  final bool merge;
  final bool createRefs;
  final bool updateRefs;
  final bool deleteRefs;
  final bool counter;
  final int createdAt;
  final int attempts;

  _DataQueuedOp({
    required this.id,
    required this.kind,
    this.entityId,
    this.data,
    this.ids,
    this.writers,
    this.merge = true,
    this.createRefs = false,
    this.updateRefs = false,
    this.deleteRefs = false,
    this.counter = false,
    int? createdAt,
    this.attempts = 0,
  }) : createdAt = createdAt ?? DateTime.now().microsecondsSinceEpoch;

  _DataQueuedOp copyWith({int? attempts}) => _DataQueuedOp(
        id: id,
        kind: kind,
        entityId: entityId,
        data: data,
        ids: ids,
        writers: writers,
        merge: merge,
        createRefs: createRefs,
        updateRefs: updateRefs,
        deleteRefs: deleteRefs,
        counter: counter,
        createdAt: createdAt,
        attempts: attempts ?? this.attempts,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'entityId': entityId,
        'data': data,
        'ids': ids,
        'writers': writers,
        'merge': merge,
        'createRefs': createRefs,
        'updateRefs': updateRefs,
        'deleteRefs': deleteRefs,
        'counter': counter,
        'createdAt': createdAt,
        'attempts': attempts,
      };

  factory _DataQueuedOp.fromJson(Map<String, dynamic> json) {
    return _DataQueuedOp(
      id: json['id'] as String,
      kind: _DataQueuedOpKind.values.firstWhere(
        (e) => e.name == json['kind'],
        orElse: () => _DataQueuedOpKind.create,
      ),
      entityId: json['entityId'] as String?,
      data: (json['data'] as Map?)?.cast<String, dynamic>(),
      ids: (json['ids'] as List?)?.cast<String>(),
      writers: (json['writers'] as List?)
          ?.map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      merge: json['merge'] as bool? ?? true,
      createRefs: json['createRefs'] as bool? ?? false,
      updateRefs: json['updateRefs'] as bool? ?? false,
      deleteRefs: json['deleteRefs'] as bool? ?? false,
      counter: json['counter'] as bool? ?? false,
      createdAt: json['createdAt'] as int?,
      attempts: json['attempts'] as int? ?? 0,
    );
  }
}
