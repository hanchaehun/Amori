import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// BFF(FastAPI) 접속 설정.
///
/// LLM API 키는 더 이상 앱에 들어가지 않는다 — 모든 LLM 호출은
/// Flutter → BFF → Gemini 경로로 일원화 (디컴파일 키 유출·쿼터 우회 차단).
class AppConfig {
  AppConfig._();

  static String get apiBaseUrl {
    final fromEnv = dotenv.env['API_BASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    // Android 에뮬레이터는 호스트 머신이 10.0.2.2
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }
}
