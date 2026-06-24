import 'package:flutter/foundation.dart';

import '../../data/models/compatibility_report.dart';
import '../../data/models/conversation_message.dart';
import '../../data/models/persona.dart';

/// AgentFlow 파이프라인의 현재 단계 — 화면이 실시간 진행 상태를 구독한다.
enum AgentFlowPhase {
  idle,
  buildingPersona,
  matching,
  simulating,
  reporting,
  done,
  failed;

  /// 파이프라인이 아직 돌고 있는가 (시뮬레이션 포함 전후 단계).
  bool get isRunning =>
      this == buildingPersona ||
      this == matching ||
      this == simulating ||
      this == reporting;
}

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
  String? _partnerName;
  AgentFlowPhase _phase = AgentFlowPhase.idle;
  bool _usedFallback = false;
  String? _lastError;
  String? _dailyScenarioCode;
  DateTime? _dailyCompletedDate;

  PersonaProfile? get profile => _profile;
  List<ConversationMessage> get conversation =>
      List.unmodifiable(_conversation);
  CompatibilityReport? get report => _report;

  /// 시뮬레이션/리포트가 연결된 백엔드 Match UUID (없으면 더미 플로우).
  String? get activeMatchId => _activeMatchId;
  String? get activeMatchUserId => _activeMatchUserId;

  /// 매칭된 상대 표시 이름 (백엔드 display_name, 없으면 null → 더미 이름).
  String? get partnerName => _partnerName;

  /// AgentFlow 파이프라인 진행 단계 — agent_chat_screen 실시간 표시의 신호원.
  AgentFlowPhase get phase => _phase;

  /// BFF 파이프라인 실패로 더미 데이터로 진행 중인지 — 실패를 삼키지 않고 노출.
  bool get usedFallback => _usedFallback;
  String? get lastError => _lastError;
  String? get dailyScenarioCode => _dailyScenarioCode;
  DateTime? get dailyCompletedDate => _dailyCompletedDate;

  set profile(PersonaProfile? value) {
    _profile = value;
    notifyListeners();
  }

  set report(CompatibilityReport? value) {
    _report = value;
    notifyListeners();
  }

  void setActiveMatch({
    required String matchId,
    required String userId,
    String? partnerName,
  }) {
    _activeMatchId = matchId;
    _activeMatchUserId = userId;
    _partnerName = partnerName;
    notifyListeners();
  }

  void setPhase(AgentFlowPhase value) {
    if (_phase == value) return;
    _phase = value;
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
    _phase = AgentFlowPhase.failed;
    notifyListeners();
  }

  void setDailyPersonaStatus({
    required String? scenarioCode,
    DateTime? completedDate,
  }) {
    _dailyScenarioCode = scenarioCode;
    _dailyCompletedDate = completedDate;
    notifyListeners();
  }

  void markDailyPersonaCompleted(DateTime date) {
    _dailyScenarioCode = null;
    _dailyCompletedDate = date;
    notifyListeners();
  }

  void reset() {
    _profile = null;
    _conversation = [];
    _report = null;
    _activeMatchId = null;
    _activeMatchUserId = null;
    _partnerName = null;
    _phase = AgentFlowPhase.idle;
    _usedFallback = false;
    _lastError = null;
    _dailyScenarioCode = null;
    _dailyCompletedDate = null;
    notifyListeners();
  }
}
