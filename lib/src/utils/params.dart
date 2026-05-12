import 'package:collection/collection.dart' show MapEquality, ListEquality;

import 'path_replacer.dart' show DataFieldReplacer;

abstract class DataFieldParams {
  const DataFieldParams();
}

class KeyParams extends DataFieldParams {
  static const _equality = MapEquality<String, String>();

  final Map<String, String> _values;

  KeyParams(Map<String, String> values)
      : _values = Map<String, String>.unmodifiable(values);

  Map<String, String> get values => _values;

  @override
  int get hashCode => _equality.hash(_values);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is KeyParams && _equality.equals(_values, other._values);
  }

  @override
  String toString() => 'KeyParams($_values)';
}

class IterableParams extends DataFieldParams {
  static const _equality = ListEquality<String>();

  final List<String> _values;

  IterableParams(List<String> values)
      : _values = List<String>.unmodifiable(values);

  List<String> get values => _values;

  @override
  int get hashCode => _equality.hash(_values);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IterableParams && _equality.equals(_values, other._values);
  }

  @override
  String toString() => 'IterableParams($_values)';
}

extension DataFieldParamsHelper on DataFieldParams? {
  String generate(String root) {
    final params = this;
    if (params is KeyParams) {
      return DataFieldReplacer.replace(root, params.values);
    } else if (params is IterableParams) {
      return DataFieldReplacer.replaceByIterable(root, params.values);
    }
    return root;
  }
}
