import 'package:flutter/foundation.dart';

import '../../core/state/agent_session_store.dart';
import '../backend/scenario_answers_store.dart';
import 'persona_repository.dart';

/// 질문지 완료 후 플로우 — **페르소나 생성까지만** (전부 BFF 경유).
///
/// 제품 설계 (2026-06-13): 매칭과 시뮬레이션은 클라이언트가 시키는 게 아니라
/// 백엔드 스케줄러가 하루 랜덤 N회 "에이전트가 알아서 다녀온다"
/// (`backend/app/services/auto_sim.py`). 결과는 연결(inbox) 화면이
/// GET /matches 로 소비한다. 구 즉시 실행 파이프라인(매칭→시뮬→리포트)은
/// 이 설계로 대체됐다.
///
/// 실패는 null 로 삼켜지지 않고 [AgentSessionStore.usedFallback]
/// 플래그로 화면에 노출된다.
class AgentFlow {
  AgentFlow({
    PersonaRepository? personaRepository,
    AgentSessionStore? store,
  }) : _personas = personaRepository ?? PersonaRepository(),
       _store = store ?? AgentSessionStore.instance;

  final PersonaRepository _personas;
  final AgentSessionStore _store;

  /// 시나리오 답변으로 페르소나를 생성하고 스토어에 채운다.
  Future<void> run() async {
    try {
      _store.setPhase(AgentFlowPhase.buildingPersona);
      final profile = await _personas.buildPersona(
        ScenarioAnswersStore.answers,
      );
      _store.profile = profile;
      _store.setPhase(AgentFlowPhase.done);
      ScenarioAnswersStore.clear();
    } catch (error) {
      debugPrint('AgentFlow 실패: $error');
      _store.markFallback(error.toString());
    }
  }
}
