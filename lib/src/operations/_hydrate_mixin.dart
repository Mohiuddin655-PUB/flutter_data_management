part of 'base.dart';

mixin _HydrateMixin on _ReadResolveMixin {
  Future<DataGetSnapshot> _hydrateOne(
    DataGetSnapshot? data, {
    required bool countable,
    required bool resolveRefs,
    required Ignore? ignore,
  }) async {
    if (data == null || !data.exists) return DataGetSnapshot();
    if (!resolveRefs) return data;
    final resolved = await _resolveRefs(data.doc, ignore, countable);
    return data.copyWith(doc: resolved);
  }

  Future<DataGetsSnapshot> _hydrateMany(
    DataGetsSnapshot? data, {
    required bool countable,
    required bool resolveRefs,
    required bool resolveDocChangesRefs,
    required Ignore? ignore,
  }) async {
    if (data == null || !data.exists) return DataGetsSnapshot();
    if (!resolveRefs) return data;
    final docs = await Future.wait(
      data.docs.map((e) => _resolveRefs(e, ignore, countable)),
    );
    final docChanges = resolveDocChangesRefs
        ? await Future.wait(
            data.docChanges.map((e) => _resolveRefs(e, ignore, countable)),
          )
        : data.docChanges;
    return data.copyWith(docs: docs, docChanges: docChanges);
  }
}
