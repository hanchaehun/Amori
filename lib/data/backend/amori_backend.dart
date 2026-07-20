import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/config/app_config.dart';
import '../../core/state/agent_session_store.dart';
import '../../core/state/profile_store.dart';
import 'backend_exception.dart';

/// Firebase 래퍼 — 책임은 Authentication과 FCM 토큰까지만 (리팩토링 결정 3).
///
/// 도메인 데이터(페르소나/매치/리포트/만남신청/피드백)는 더 이상 Firestore에
/// 쓰지 않는다. 단일 원천은 BFF 뒤의 Postgres이며, `lib/data/repositories/`
/// 를 통해 접근한다.
class AmoriBackend {
  AmoriBackend({FirebaseAuth? auth, FirebaseMessaging? messaging})
    : _auth = auth ?? FirebaseAuth.instance,
      _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseAuth _auth;
  final FirebaseMessaging _messaging;

  User? get currentUser => _auth.currentUser;

  /// BFF를 호출할 수 있는 인증 상태인가 — 실 Firebase 로그인 또는 DEV_UID 우회.
  /// (매칭 탭 등 currentUser로 게이트하던 화면이 dev 모드에서 빈 화면이 되던 문제)
  bool get isAuthenticated => _auth.currentUser != null || AppConfig.devUid != null;

  String get requireUid {
    final uid = currentUser?.uid;
    if (uid == null) {
      throw const BackendException('로그인이 필요합니다.', code: 'unauthenticated');
    }
    return uid;
  }

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const BackendException('계정 생성에 실패했습니다.');
      }
      await user.updateDisplayName(displayName);
      return credential;
    } on FirebaseAuthException catch (error) {
      throw BackendException(_authMessage(error), code: error.code);
    }
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw BackendException(_authMessage(error), code: error.code);
    }
  }

  Future<void> signOut() async {
    AgentSessionStore.instance.reset();
    ProfileStore.instance.reset();
    await _auth.signOut();
  }

  /// 회원 탈퇴 마무리 — 세션 스토어를 비우고 Firebase Auth 계정을 삭제한다.
  /// (서버 도메인 데이터 삭제는 UserRepository.deleteAccount가 선행한다.)
  /// Firebase 삭제가 재인증을 요구하거나 실패해도 최소한 로그아웃은 보장해
  /// 탈퇴 흐름이 막다른 길이 되지 않게 한다(베스트에포트).
  Future<void> deleteAccount() async {
    AgentSessionStore.instance.reset();
    ProfileStore.instance.reset();
    final user = _auth.currentUser;
    if (user == null) return; // DEV_UID 우회 모드 등
    try {
      await user.delete();
    } on FirebaseAuthException catch (_) {
      await _auth.signOut();
    }
  }

  Future<String?> getFcmToken() => _messaging.getToken();

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => '이미 가입된 이메일이에요.',
    'invalid-email' => '올바른 이메일 형식이 아니에요.',
    'weak-password' => '비밀번호가 너무 약해요.',
    'user-not-found' => '아이디를 확인해 주세요.',
    'wrong-password' => '비밀번호를 확인해 주세요.',
    // 계정 열거 방지가 켜진 Firebase는 위 두 코드 대신 이것만 준다 —
    // 아이디/비밀번호 중 무엇이 틀렸는지 서버가 알려주지 않는다.
    'invalid-credential' ||
    'INVALID_LOGIN_CREDENTIALS' => '아이디 또는 비밀번호를 확인해 주세요.',
    'user-disabled' => '이용이 정지된 계정이에요.',
    'too-many-requests' => '시도가 너무 많았어요. 잠시 후 다시 시도해 주세요.',
    'network-request-failed' => '네트워크 연결을 확인해 주세요.',
    // Firebase 원문(영어)을 그대로 노출하지 않는다.
    _ => '요청에 실패했어요. 잠시 후 다시 시도해 주세요.',
  };
}
