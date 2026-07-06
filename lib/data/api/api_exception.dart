/// BFF 표준 에러 응답 ({error_code, message, request_id})을 담는 예외.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.errorCode = 'UNKNOWN',
    this.statusCode,
    this.requestId,
  });

  final String message;
  final String errorCode;
  final int? statusCode;
  final String? requestId;

  bool get isQuotaExceeded => errorCode == 'QUOTA_EXCEEDED';
  bool get isNotFound => errorCode == 'NOT_FOUND';
  bool get isUnauthorized => errorCode == 'UNAUTHORIZED';

  @override
  String toString() => 'ApiException($errorCode, $statusCode): $message';
}
