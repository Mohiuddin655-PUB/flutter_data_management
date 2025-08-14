part of 'configs.dart';

/// You can use like
/// * [KeyParams]
/// * [IterableParams]
abstract class DataFieldParams {
  const DataFieldParams();
}

/// Replaces placeholders in the given [path] using the provided [params] map.
///
/// Example:
/// ```dart
/// FieldParams params = Params({'param1': 'value1', 'param2': 'value2'});     // Params: param1 = value1, param2 = value2
/// String root = "/path/{param1}/endpoint/{param2}";                          // Input : /path/{param1}/endpoint/{param2}
/// String path = params.generate(root);                                       // Output: /path/value1/endpoint/value2
/// ```
class KeyParams extends DataFieldParams {
  final Map<String, String> values;

  const KeyParams(this.values);

  @override
  int get hashCode => values.hashCode;

  @override
  bool operator ==(Object other) {
    return other is KeyParams && other.values == values;
  }

  @override
  String toString() => "$KeyParams($values)";
}

/// Replaces placeholders in the given [path] using values from the [params] iterable.
///
/// Example:
/// ```dart
/// FieldParams params = IterableParams(['value1', 'value2']);     // Params: param1 = value1, param2 = value2
/// String root = "/path/{param1}/endpoint/{param2}";              // Input : /path/{param1}/endpoint/{param2}
/// String path = params.generate(root);                           // Output: /path/value1/endpoint/value2
/// ```
class IterableParams extends DataFieldParams {
  final List<String> values;

  const IterableParams(this.values);

  @override
  int get hashCode => values.hashCode;

  @override
  bool operator ==(Object other) {
    return other is IterableParams && other.values == values;
  }

  @override
  String toString() => "$IterableParams($values)";
}

extension DataFieldParamsHelper on DataFieldParams? {
  String generate(String root) {
    final params = this;
    if (params is KeyParams) {
      return DataFieldReplacer.replace(root, params.values);
    } else if (params is IterableParams) {
      return DataFieldReplacer.replaceByIterable(root, params.values);
    } else {
      return root;
    }
  }
}
