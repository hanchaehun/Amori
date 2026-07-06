import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/state/agent_session_store.dart';
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
    await _auth.signOut();
  }

  Future<String?> getFcmToken() => _messaging.getToken();

  String _authMessage(FirebaseAuthException error) => switch (error.code) {
    'email-already-in-use' => '이미 가입된 이메일이에요.',
    'invalid-email' => '올바른 이메일 형식이 아니에요.',
    'weak-password' => '비밀번호가 너무 약해요.',
    'user-not-found' => '가입된 계정을 찾을 수 없어요.',
    'wrong-password' => '비밀번호가 맞지 않아요.',
    _ => error.message ?? '인증 요청에 실패했습니다.',
  };
}
