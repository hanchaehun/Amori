import 'dart:async';

import 'package:amori/data/api/api_client.dart';
import 'package:amori/data/api/api_exception.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// 응답을 영원히 주지 않는 서버 — 실기기에서 10.0.2.2 같은 도달 불가 주소로
/// 요청이 블랙홀되는 상황 재현 (연결 거부가 아니라 무응답).
class _HangingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
}

void main() {
  setUpAll(() {
    // DEV_UID 인증 경로 — 테스트에서 Firebase 초기화 없이 헤더 구성
    dotenv.loadFromString(envString: 'DEV_UID=test_user');
  });

  test('GET은 타임아웃(첫 시도 + 콜드스타트 재시도) 후 ApiException(TIMEOUT)으로 실패한다',
      () async {
    final api = ApiClient(
      httpClient: _HangingClient(),
      readTimeout: const Duration(milliseconds: 100),
      // 콜드스타트 재시도도 짧게 — 무응답 연결에서 테스트가 오래 매달리지 않게.
      coldStartTimeout: const Duration(milliseconds: 200),
    );
    await expectLater(
      api.getJson('/matches'),
      throwsA(
        isA<ApiException>().having((e) => e.errorCode, 'errorCode', 'TIMEOUT'),
      ),
    );
  });
}
