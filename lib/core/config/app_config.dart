import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// BFF(FastAPI) 접속 설정.
///
/// LLM API 키는 더 이상 앱에 들어가지 않는다 — 모든 LLM 호출은
/// Flutter → BFF → Gemini 경로로 일원화 (디컴파일 키 유출·쿼터 우회 차단).
class AppConfig {
  AppConfig._();

  /// 앱 버전 — 설정·프로필 화면 등에서 공통 참조(하드코딩 분산 방지).
  static const String appVersion = '1.0.0';

  static String get apiBaseUrl {
    final fromEnv = dotenv.env['API_BASE_URL'];
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    // 웹 릴리스(QA 배포): 호스팅이 assets/.env(닷파일)를 서빙하지 못해도
    // 실서버 BFF로 동작해야 한다 — 배포 백엔드 URL로 폴백.
    if (kIsWeb && kReleaseMode) {
      return 'https://amori-backend-3ldw.onrender.com';
    }
    // Android 에뮬레이터는 호스트 머신이 10.0.2.2
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  /// 로컬 개발용 인증 우회 uid — 설정 시 Firebase 로그인 없이
  /// `Bearer dev:<uid>`로 BFF에 인증한다 (백엔드 DEBUG=true 전용).
  /// 릴리스 빌드에서는 항상 null.
  static String? get devUid {
    if (kReleaseMode) return null;
    final uid = dotenv.env['DEV_UID'];
    return (uid == null || uid.isEmpty) ? null : uid;
  }
}
