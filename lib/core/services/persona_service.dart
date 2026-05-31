import 'dart:convert';

import '../../data/dummy/scenarios.dart';
import '../../data/models/persona.dart';
import 'llm_service.dart';

class PersonaService {
  PersonaService._();

  static const _systemPrompt = '''당신은 연애 심리 분석 전문가입니다.
사용자의 소개팅/연애 시나리오 응답을 분석해서 페르소나 프로필을 JSON으로 생성하세요.
반드시 한국어로 작성하고, 아래 JSON 형식만 반환하세요:

{
  "communicationStyle": "대화 스타일을 한 문장으로",
  "relationshipValues": "관계 가치관을 한 문장으로",
  "humorCode": "유머 코드를 한 문장으로",
  "attachmentStyle": "애착 유형을 한 문장으로",
  "conflictStyle": "갈등 해결 방식을 한 문장으로",
  "strengths": ["장점1", "장점2", "장점3"],
  "summary": "이 사람의 연애 스타일 전체 요약을 2-3문장으로"
}''';

  static Future<PersonaProfile> generatePersona(
    Map<int, String> answers,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('아래는 사용자의 시나리오 응답입니다:\n');

    for (int i = 0; i < kScenarios.length; i++) {
      final answer = answers[i];
      if (answer == null) continue;

      final scenario = kScenarios[i];
      final choice =
          scenario.choices.firstWhere((c) => c.letter == answer);

      buffer.writeln('[${scenario.category}] ${scenario.question}');
      buffer.writeln('→ $answer: ${choice.text}');
      buffer.writeln();
    }

    final content = await LlmService.chat(
      systemPrompt: _systemPrompt,
      userMessage: buffer.toString(),
    );

    final json = jsonDecode(content) as Map<String, dynamic>;
    return PersonaProfile.fromJson(json);
  }
}
