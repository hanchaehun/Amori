class BackendException implements Exception {
  const BackendException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => 'BackendException($code, $message)';
}
