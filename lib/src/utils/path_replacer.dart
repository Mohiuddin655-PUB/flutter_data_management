class DataFieldReplacer {
  const DataFieldReplacer._();

  static final RegExp _placeholder = RegExp(r'\{(\w+)\}');

  static String replace(String path, Map<String, String> params) {
    if (params.isEmpty) return path;
    return path.replaceAllMapped(_placeholder, (match) {
      final key = match.group(1)!;
      final value = params[key];
      return value ?? match.group(0)!;
    });
  }

  static String replaceByIterable(String path, Iterable<String> params) {
    final values = params is List<String> ? params : params.toList();
    if (values.isEmpty) return path;
    var i = 0;
    return path.replaceAllMapped(_placeholder, (match) {
      return i < values.length ? values[i++] : match.group(0)!;
    });
  }
}
