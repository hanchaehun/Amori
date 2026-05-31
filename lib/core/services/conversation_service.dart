import 'dart:convert';

import '../../data/models/compatibility_report.dart';
import '../../data/models/conversation_message.dart';
import '../../data/models/persona.dart';
import 'llm_service.dart';

class ConversationService {
  ConversationService._();

  // 시연용 상대방 페르소나 (실제 서비스에선 매칭된 상대의 페르소나가 들어옴)
  static const _partnerDescription = '''
이름: 민준
대화 스타일: 빠른 답장을 선호하고 먼저 연락하는 편. 유머를 즐기되 진지한 대화도 좋아함.
관계 가치관: 약속을 매우 중요시하고, 작은 것도 챙기는 세심한 편.
유머 코드: 가벼운 장난과 밈을 즐기지만 상황을 읽을 줄 앎.
갈등 방식: 감정이 생기면 바로 말하는 편, 빠른 해결을 선호.
데이트 취향: 즉흥적인 제안을 좋아하고 활동적인 외출을 즐김.
''';

  static const _systemPrompt = '''당신은 소개팅 AI 시뮬레이션 전문가입니다.
두 사람의 AI 에이전트가 나누는 소개팅 대화를 생성하세요.
반드시 한국어로, 아래 JSON 형식만 반환하세요.
대화는 8~10개 메시지로 구성하고, 중간에 시스템 분석 메시지를 1~2개 포함하세요.

{
  "messages": [
    {"isMe": true, "text": "메시지 내용", "signal": "짧은 시그널 라벨 또는 null"},
    {"isMe": false, "text": "메시지 내용", "signal": null},
    {"isSystem": true, "text": "🔍 분석: 내용", "isMe": false}
  ]
}

규칙:
- isMe: true = 사용자 AI 발화, false = 상대방 AI 발화
- isSystem: true이면 isMe는 false로 설정
- signal은 호환성 힌트 (예: "여행 시그널", "가치관 매치") 또는 null
- 자연스럽고 실제 소개팅 같은 대화 흐름''';

  static Future<List<ConversationMessage>> generate(
    PersonaProfile userPersona,
  ) async {
    final userDesc = '''
사용자 AI 페르소나:
대화 스타일: ${userPersona.communicationStyle}
관계 가치관: ${userPersona.relationshipValues}
유머 코드: ${userPersona.humorCode}
갈등 방식: ${userPersona.conflictStyle}
요약: ${userPersona.summary}
''';

    final content = await LlmService.chat(
      systemPrompt: _systemPrompt,
      userMessage: '$userDesc\n상대방 AI 페르소나:\n$_partnerDescription',
      maxTokens: 1200,
    );

    final json = jsonDecode(content) as Map<String, dynamic>;
    final rawList = json['messages'] as List<dynamic>? ?? [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(ConversationMessage.fromJson)
        .toList();
  }
}

class ReportService {
  ReportService._();

  static const _systemPrompt = '''당신은 연애 궁합 분석 전문가입니다.
두 AI 에이전트의 페르소나와 대화 내용을 분석해서 호환성 리포트를 생성하세요.
반드시 한국어로, 아래 JSON 형식만 반환하세요:

{
  "score": 85,
  "findings": [
    {"emoji": "🎵", "title": "공통점 제목", "detail": "상세 설명"},
    {"emoji": "🌱", "title": "공통점 제목2", "detail": "상세 설명2"}
  ],
  "warnings": [
    {"emoji": "⚠️", "title": "주의할 점 제목", "detail": "상세 설명"}
  ],
  "recommendedPlaces": [
    {"emoji": "🍵", "title": "장소명", "detail": "추천 이유"},
    {"emoji": "🌳", "title": "장소명2", "detail": "추천 이유2"}
  ],
  "conversationStarters": [
    "첫 대화 시작 문장1",
    "첫 대화 시작 문장2",
    "첫 대화 시작 문장3"
  ],
  "tip": "만남 시 유용한 팁 한 문장"
}

규칙:
- score: 0~100 정수
- findings: 2~3개
- warnings: 1~2개
- recommendedPlaces: 2~3개
- conversationStarters: 3개, 따옴표로 감싼 실제 대화 문장''';

  static Future<CompatibilityReport> generate(
    PersonaProfile userPersona,
    List<ConversationMessage> conversation,
  ) async {
    final conversationText = conversation
        .map((m) {
          if (m.isSystem) return '[시스템] ${m.text}';
          final speaker = m.isMe ? '사용자AI' : '상대방AI';
          return '$speaker: ${m.text}';
        })
        .join('\n');

    final userDesc = '''
사용자 페르소나 요약: ${userPersona.summary}
장점: ${userPersona.strengths.join(', ')}
''';

    final message = '''
$userDesc

AI 대화 내용:
$conversationText
''';

    final content = await LlmService.chat(
      systemPrompt: _systemPrompt,
      userMessage: message,
      maxTokens: 1500,
    );

    final json = jsonDecode(content) as Map<String, dynamic>;
    return CompatibilityReport.fromJson(json);
  }
}
