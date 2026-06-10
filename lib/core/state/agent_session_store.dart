import 'package:flutter/foundation.dart';

import '../../data/models/compatibility_report.dart';
import '../../data/models/conversation_message.dart';
import '../../data/models/persona.dart';

/// 세션 동안 페르소나/대화/리포트를 공유하는 스토어.
///
/// 구 `PersonaStore`(정적 필드 싱글톤, reset 미호출로 세션 간 누수)를 대체한다.
/// ChangeNotifier 기반이라 화면이 구독할 수 있고, 로그아웃 시 [reset]을 호출한다.
class AgentSessionStore extends ChangeNotifier {
  AgentSessionStore._();

  static final AgentSessionStore instance = AgentSessionStore._();

  PersonaProfile? _profile;
  List<ConversationMessage> _conversation = [];
  CompatibilityReport? _report;
  String? _activeMatchId;
  String? _activeMatchUserId;
  bool _usedFallback = false;
  String? _lastError;

  PersonaProfile? get profile => _profile;
  List<ConversationMessage> get conversation =>
      List.unmodifiable(_conversation);
  CompatibilityReport? get report => _report;

  /// 시뮬레이션/리포트가 연결된 백엔드 Match UUID (없으면 더미 플로우).
  String? get activeMatchId => _activeMatchId;
  String? get activeMatchUserId => _activeMatchUserId;

  /// BFF 파이프라인 실패로 더미 데이터로 진행 중인지 — 실패를 삼키지 않고 노출.
  bool get usedFallback => _usedFallback;
  String? get lastError => _lastError;

  set profile(PersonaProfile? value) {
    _profile = value;
    notifyListeners();
  }

  set report(CompatibilityReport? value) {
    _report = value;
    notifyListeners();
  }

  void setActiveMatch({required String matchId, required String userId}) {
    _activeMatchId = matchId;
    _activeMatchUserId = userId;
    notifyListeners();
  }

  void clearConversation() {
    _conversation = [];
    notifyListeners();
  }

  void addConversationMessage(ConversationMessage message) {
    _conversation = [..._conversation, message];
    notifyListeners();
  }

  void setConversation(List<ConversationMessage> messages) {
    _conversation = List.of(messages);
    notifyListeners();
  }

  void markFallback(String error) {
    _usedFallback = true;
    _lastError = error;
    notifyListeners();
  }

  void reset() {
    _profile = null;
    _conversation = [];
    _report = null;
    _activeMatchId = null;
    _activeMatchUserId = null;
    _usedFallback = false;
    _lastError = null;
    notifyListeners();
  }
}
