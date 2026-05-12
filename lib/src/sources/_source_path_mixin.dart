part of 'base.dart';

mixin _SourcePathMixin<T extends Entity> on _SourceFieldMixin {
  String get path;

  String _ref(DataFieldParams? params, DataModifiers modifier, [String? id]) {
    final base = params.generate(path);
    if (id == null || id.isEmpty) return base;
    return '$base/$id';
  }
}
