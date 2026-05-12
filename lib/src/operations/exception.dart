class DataOperationError implements Exception {
  final String operation;
  final String? path;
  final Object cause;
  final StackTrace stack;

  const DataOperationError({
    required this.operation,
    required this.cause,
    required this.stack,
    this.path,
  });

  @override
  String toString() {
    return 'DataOperationError(op: $operation, path: $path, cause: $cause)';
  }
}
