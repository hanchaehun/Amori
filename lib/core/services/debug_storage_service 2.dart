import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/models/compatibility_report.dart';
import '../../data/models/conversation_message.dart';
import '../../data/models/persona.dart';

/// LLM 생성 결과를 저장 (디버깅용)
/// - 네이티브: 로컬 JSON 파일로 저장
/// - 웹: 콘솔에 JSON 출력
class DebugStorageService {
  DebugStorageService._();

  static Future<void> saveAll({
    required PersonaProfile profile,
    required List<ConversationMessage> conversation,
    required CompatibilityReport report,
  }) async {
    final payload = {
      'savedAt': DateTime.now().toIso8601String(),
      'persona': {
        'communicationStyle': profile.communicationStyle,
        'relationshipValues': profile.relationshipValues,
        'humorCode': profile.humorCode,
        'attachmentStyle': profile.attachmentStyle,
        'conflictStyle': profile.conflictStyle,
        'strengths': profile.strengths,
        'summary': profile.summary,
      },
      'conversation': conversation
          .map((m) => {
                'isMe': m.isMe,
                'isSystem': m.isSystem,
                'text': m.text,
                'signal': m.signal,
              })
          .toList(),
      'report': {
        'score': report.score,
        'findings': report.findings
            .map((f) =>
                {'emoji': f.emoji, 'title': f.title, 'detail': f.detail})
            .toList(),
        'warnings': report.warnings
            .map((w) =>
                {'emoji': w.emoji, 'title': w.title, 'detail': w.detail})
            .toList(),
        'recommendedPlaces': report.recommendedPlaces
            .map((p) =>
                {'emoji': p.emoji, 'title': p.title, 'detail': p.detail})
            .toList(),
        'conversationStarters': report.conversationStarters,
        'tip': report.tip,
      },
    };

    final json = const JsonEncoder.withIndent('  ').convert(payload);

    // 웹은 파일 시스템 없음 → 콘솔 출력
    if (kIsWeb) {
      debugPrint('✅ LLM 결과 (콘솔):\n$json');
      return;
    }

    // 네이티브: 파일로 저장
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final file = File('${dir.path}/amori_llm_$timestamp.json');
      await file.writeAsString(json);
      debugPrint('✅ LLM 결과 저장됨: ${file.path}');
    } catch (e) {
      debugPrint('⚠️ 파일 저장 실패, 콘솔에 출력:\n$json');
    }
  }
}
