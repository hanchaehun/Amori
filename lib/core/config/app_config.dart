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

  /// 배포 백엔드(BFF) — 릴리스 빌드의 단일 원천.
  static const String _prodBaseUrl = 'https://amori-backend-3ldw.onrender.com';

  static String get apiBaseUrl {
    final fromEnv = dotenv.env['API_BASE_URL'];
    // 개발용 로컬 주소(에뮬레이터·로컬호스트)는 릴리스에서 무시한다.
    final envIsLocal = fromEnv == null ||
        fromEnv.isEmpty ||
        fromEnv.contains('localhost') ||
        fromEnv.contains('127.0.0.1') ||
        fromEnv.contains('10.0.2.2');
    // 릴리스 빌드는 반드시 실서버(HTTPS)로 붙는다. 번들된 개발용 .env가
    // localhost를 가리켜도(App Store 배포 시 평문 HTTP·무동작·ATS 위반 방지)
    // 로컬 주소는 버리고 배포 백엔드로 폴백한다. 실 원격 URL을 명시로 넣은
    // 경우엔(예: 스테이징) 그 값을 그대로 존중한다.
    if (kReleaseMode && envIsLocal) return _prodBaseUrl;
    if (fromEnv != null && fromEnv.isNotEmpty) return fromEnv;
    // Android 에뮬레이터는 호스트 머신이 10.0.2.2
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://localhost:8000';
  }

  /// 지인 필터(주소록 연동) 노출 게이트.
  ///
  /// 등록(수집)은 지금부터 받되, 매칭 실적용은 서버 CONTACT_FILTER_ENFORCED가
  /// 본인인증(PASS) 도입과 함께 켜질 때부터다(2026-07-19 결정 — 자기신고
  /// 번호는 미검증이라 매칭엔 안 쓴다). 그 전까지 화면은 "본인인증 도입 후
  /// 적용" 안내 배너를 띄운다.
  static const bool contactFilterEnabled = true;

  /// 로컬 개발용 인증 우회 uid — 설정 시 Firebase 로그인 없이
  /// `Bearer dev:<uid>`로 BFF에 인증한다 (백엔드 DEBUG=true 전용).
  /// 릴리스 빌드에서는 항상 null.
  static String? get devUid {
    if (kReleaseMode) return null;
    final uid = dotenv.env['DEV_UID'];
    return (uid == null || uid.isEmpty) ? null : uid;
  }
}
