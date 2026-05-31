import '../../data/models/compatibility_report.dart';
import '../../data/models/conversation_message.dart';
import '../../data/models/persona.dart';

/// 화면 간 페르소나/대화/리포트 데이터를 공유하는 단순 싱글턴 저장소
class PersonaStore {
  PersonaStore._();

  /// 시나리오 플레이어에서 수집한 답변 (인덱스 → 선택지 letter)
  static Map<int, String> answers = {};

  /// LLM이 생성한 사용자 페르소나
  static PersonaProfile? profile;

  /// LLM이 생성한 AI 간 대화 로그
  static List<ConversationMessage> conversation = [];

  /// LLM이 생성한 호환성 리포트
  static CompatibilityReport? report;

  static void reset() {
    answers = {};
    profile = null;
    conversation = [];
    report = null;
  }
}
