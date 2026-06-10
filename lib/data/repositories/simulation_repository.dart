import '../../data/models/conversation_message.dart';
import '../api/api_client.dart';

/// 에이전트 시뮬레이션 — BFF `POST /simulation/run` SSE 스트림 소비.
///
/// 백엔드의 2-에이전트 턴 루프가 만든 실제 턴이 이벤트 단위로 내려온다.
/// (가짜 타이핑 연출 → 진짜 실시간 스트리밍의 기반)
class SimulationRepository {
  SimulationRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// 턴을 도착하는 대로 방출한다. 스트림 종료 = 시뮬레이션 완료.
  Stream<ConversationMessage> run({
    required String targetUserId,
    int maxTurns = 20,
  }) async* {
    final events = _api.postSse('/simulation/run', {
      'target_user_id': targetUserId,
      'max_turns': maxTurns,
    });
    await for (final event in events) {
      if (event['_event'] != 'turn') continue; // done 등 메타 이벤트
      final speaker = event['speaker'] as String? ?? 'them';
      yield ConversationMessage(
        isMe: speaker == 'me',
        isSystem: speaker == 'system',
        text: event['text'] as String? ?? '',
        signal: event['signal'] as String?,
      );
    }
  }

  /// 전체 턴을 모아서 반환하는 편의 메서드 (1차 결선용).
  Future<List<ConversationMessage>> runToCompletion({
    required String targetUserId,
    int maxTurns = 20,
  }) =>
      run(targetUserId: targetUserId, maxTurns: maxTurns).toList();
}
