import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';
import 'api_exception.dart';

/// BFF(FastAPI) HTTP 클라이언트.
///
/// 모든 요청에 Firebase ID 토큰을 Bearer 헤더로 싣고,
/// 표준 에러 응답을 [ApiException]으로 변환한다.
class ApiClient {
  ApiClient({FirebaseAuth? auth, http.Client? httpClient})
    : _auth = auth ?? FirebaseAuth.instance,
      _http = httpClient ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _http;

  static const _timeout = Duration(seconds: 90);

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiBaseUrl}$path').replace(
        queryParameters: query,
      );

  Future<Map<String, String>> _headers() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const ApiException(
        '로그인이 필요합니다.',
        errorCode: 'UNAUTHORIZED',
        statusCode: 401,
      );
    }
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  Future<dynamic> getJson(String path, {Map<String, String>? query}) async {
    final response = await _http
        .get(_uri(path, query), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  Future<dynamic> postJson(String path, Object body) async {
    final response = await _http
        .post(_uri(path), headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(response);
  }

  Future<dynamic> putJson(String path, Object body) async {
    final response = await _http
        .put(_uri(path), headers: await _headers(), body: jsonEncode(body))
        .timeout(_timeout);
    return _decode(response);
  }

  /// SSE(`text/event-stream`) POST — 이벤트의 data(JSON)를 순차 방출한다.
  Stream<Map<String, dynamic>> postSse(String path, Object body) async* {
    final request = http.Request('POST', _uri(path))
      ..headers.addAll(await _headers())
      ..headers['Accept'] = 'text/event-stream'
      ..body = jsonEncode(body);

    final response = await _http.send(request);
    if (response.statusCode >= 400) {
      final raw = await response.stream.bytesToString();
      throw _toException(response.statusCode, raw);
    }

    var event = '';
    final dataLines = <String>[];
    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) {
        // 이벤트 경계
        if (dataLines.isNotEmpty) {
          final payload = jsonDecode(dataLines.join('\n'));
          if (event == 'error') {
            throw ApiException(
              (payload is Map ? payload['message'] : null)?.toString() ??
                  '시뮬레이션이 실패했습니다.',
              errorCode: 'SIMULATION_FAILED',
            );
          }
          if (payload is Map<String, dynamic>) {
            yield {...payload, '_event': event.isEmpty ? 'message' : event};
          }
        }
        event = '';
        dataLines.clear();
        continue;
      }
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
  }

  dynamic _decode(http.Response response) {
    final text = utf8.decode(response.bodyBytes);
    if (response.statusCode >= 400) {
      throw _toException(response.statusCode, text);
    }
    return text.isEmpty ? null : jsonDecode(text);
  }

  ApiException _toException(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final detail = json['detail'];
      final error = detail is Map<String, dynamic> ? detail : json;
      return ApiException(
        error['message'] as String? ?? '요청에 실패했습니다.',
        errorCode: error['error_code'] as String? ?? 'UNKNOWN',
        statusCode: statusCode,
        requestId: error['request_id'] as String?,
      );
    } catch (_) {
      return ApiException(
        '요청에 실패했습니다. (HTTP $statusCode)',
        statusCode: statusCode,
      );
    }
  }
}
