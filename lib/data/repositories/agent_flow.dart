import 'package:flutter/foundation.dart';

import '../../core/state/agent_session_store.dart';
import '../backend/scenario_answers_store.dart';
import 'match_repository.dart';
import 'persona_repository.dart';
import 'report_repository.dart';
import 'simulation_repository.dart';

/// 페르소나 → 매칭 → 시뮬레이션 → 리포트 파이프라인 (전부 BFF 경유).
///
/// 구 persona_loading_screen 의 initState 속 LLM 3연속 직접 호출을 대체한다.
/// 실패는 더 이상 null 로 삼켜지지 않고 [AgentSessionStore.usedFallback]
/// 플래그로 화면에 노출된다.
class AgentFlow {
  AgentFlow({
    PersonaRepository? personaRepository,
    MatchRepository? matchRepository,
    SimulationRepository? simulationRepository,
    ReportRepository? reportRepository,
    AgentSessionStore? store,
  }) : _personas = personaRepository ?? PersonaRepository(),
       _matches = matchRepository ?? MatchRepository(),
       _simulations = simulationRepository ?? SimulationRepository(),
       _reports = reportRepository ?? ReportRepository(),
       _store = store ?? AgentSessionStore.instance;

  final PersonaRepository _personas;
  final MatchRepository _matches;
  final SimulationRepository _simulations;
  final ReportRepository _reports;
  final AgentSessionStore _store;

  /// 시나리오 답변으로 전체 플로우를 실행하고 결과를 스토어에 채운다.
  Future<void> run() async {
    try {
      // 1. 페르소나 생성 (서버가 임베딩까지 생성·저장)
      final profile = await _personas.buildPersona(
        ScenarioAnswersStore.answers,
      );
      _store.profile = profile;

      // 2. 벡터 매칭 — 후보가 없으면(초기 DB) 시뮬레이션 없이 종료
      final candidates = await _matches.findMatches(topK: 1);
      if (candidates.isEmpty) {
        _store.markFallback('매칭 후보가 아직 없습니다.');
        return;
      }
      final target = candidates.first;
      _store.setActiveMatch(matchId: target.matchId, userId: target.userId);

      // 3. 에이전트 시뮬레이션 — SSE 턴을 도착 순서대로 스토어에 적재
      _store.clearConversation();
      await for (final message in _simulations.run(
        targetUserId: target.userId,
      )) {
        _store.addConversationMessage(message);
      }

      // 4. 궁합 리포트 (서버 캐싱)
      _store.report = await _reports.fetch(target.matchId);

      ScenarioAnswersStore.clear();
    } catch (error) {
      debugPrint('AgentFlow 실패: $error');
      _store.markFallback(error.toString());
    }
  }
}
