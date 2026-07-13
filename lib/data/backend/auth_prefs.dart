import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 로그인 편의 설정 저장소.
///
/// - 로그인 유지·페르소나 준비 플래그: SharedPreferences — 민감정보가
///   아니고 splash에서 빠르게 읽어야 한다.
/// - 저장된 이메일(아이디 저장): flutter_secure_storage (Android Keystore
///   암호화). 비밀번호는 저장하지 않는다 — 매 로그인마다 새로 입력받는다.
class AuthPrefs {
  AuthPrefs._();

  static final AuthPrefs instance = AuthPrefs._();

  static const _keepLoggedInKey = 'auth.keep_logged_in';
  static const _personaReadyKey = 'auth.persona_ready';
  static const _emailKey = 'auth.saved_email';
  static const _passwordKey = 'auth.saved_password';

  final _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// 미설정 기본값 = true — 가입 직후(체크박스를 본 적 없는 세션)에도
  /// 앱을 껐다 켰을 때 로그인이 유지되는 쪽이 기대 동작이다.
  Future<bool> keepLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keepLoggedInKey) ?? true;
  }

  Future<void> setKeepLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keepLoggedInKey, value);
  }

  /// 이 기기에서 페르소나 생성까지 마쳤는지 — splash 자동 진입이 홈과
  /// 페르소나 생성 플로우 중 어디로 갈지 결정한다(네트워크 조회 없이).
  /// 미설정 기본값 = true: 이 플래그 도입 전에 이미 로그인돼 있던 기기.
  Future<bool> personaReady() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_personaReadyKey) ?? true;
  }

  Future<void> setPersonaReady(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_personaReadyKey, value);
  }

  Future<String?> savedEmail() async {
    // 과거 빌드가 비밀번호를 저장했을 수 있다 — 더 이상 쓰지 않으므로
    // 발견 즉시 제거한다(마이그레이션).
    await _secure.delete(key: _passwordKey);
    final email = await _secure.read(key: _emailKey);
    return (email == null || email.isEmpty) ? null : email;
  }

  Future<void> saveEmail(String email) =>
      _secure.write(key: _emailKey, value: email);

  Future<void> clearEmail() => _secure.delete(key: _emailKey);
}
