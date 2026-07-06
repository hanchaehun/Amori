import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amori/core/theme/app_theme.dart';
import 'package:amori/data/repositories/match_repository.dart';
import 'package:amori/features/home/agent_chat_screen.dart';

/// 시퀀스 기반 가짜 리포지토리 — 폴링 호출마다 다음 응답을 돌려준다.
/// 실제 BFF는 건드리지 않는다(super의 ApiClient는 생성만 되고 미사용).
class _FakeRepo extends MatchRepository {
  bool throwOnList = false;
  List<List<MatchSummary>> listSequence = [];
  List<MatchConversation> convSequence = [];
  int _listIdx = 0;
  int _convIdx = 0;

  @override
  Future<List<MatchSummary>> listMatches() async {
    if (throwOnList) throw Exception('offline');
    if (listSequence.isEmpty) return [];
    final r = listSequence[_listIdx];
    if (_listIdx < listSequence.length - 1) _listIdx++;
    return r;
  }

  @override
  Future<MatchConversation> getConversation(String matchId) async {
    final c = convSequence[_convIdx];
    if (_convIdx < convSequence.length - 1) _convIdx++;
    return c;
  }
}

MatchSummary _summary({
  bool agentLive = false,
  int? reportScore,
  String status = 'simulated',
}) => MatchSummary(
  matchId: 'm1',
  partnerId: 'u2',
  partnerName: '수아',
  status: status,
  score: 90,
  appointmentReady: false,
  youAccepted: false,
  partnerAccepted: false,
  lastMessage: null,
  turnCount: 0,
  updatedAt: DateTime(2026, 6, 13),
  reportScore: reportScore,
  agentLive: agentLive,
);

MatchConversation _conv({
  required bool agentLive,
  required List<AgentTurn> turns,
}) => MatchConversation(
  matchId: 'm1',
  partnerName: '수아',
  status: 'simulated',
  chatEnabled: false,
  agentLive: agentLive,
  agentTurns: turns,
  messages: const [],
);

/// 케미 점수는 RichText 스팬에 들어가 find.textContaining이 닿지 않으므로
/// plainText로 직접 매칭한다.
Finder _richTextContaining(String s) => find.byWidgetPredicate(
  (w) => w is RichText && w.text.toPlainText().contains(s),
);

Widget _wrap(MatchRepository repo) => MaterialApp(
  theme: AppTheme.light,
  home: AgentChatScreen(
    repository: repo,
    pollInterval: const Duration(milliseconds: 50),
  ),
);

/// bootstrap의 연쇄 await(listMatches → getConversation)를 흘려보낸다.
Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('백엔드에 닿지 못하면 더미 폴백을 보여준다', (tester) async {
    final repo = _FakeRepo()..throwOnList = true;
    await tester.pumpWidget(_wrap(repo));
    await _flush(tester);

    expect(find.textContaining('주말에는 보통 어떻게 보내세요'), findsOneWidget);
    expect(find.textContaining('메시지 4'), findsOneWidget);
  });

  testWidgets('다녀온 소개팅이 없으면 빈 상태를 보여준다', (tester) async {
    final repo = _FakeRepo()..listSequence = [[]];
    await tester.pumpWidget(_wrap(repo));
    await _flush(tester);

    expect(find.textContaining('아직 다녀온 소개팅이 없어요'), findsOneWidget);
  });

  testWidgets('라이브 매치의 턴이 폴링으로 하나씩 쌓이고, 완료 시 점수가 뜬다', (
    tester,
  ) async {
    final repo = _FakeRepo()
      ..listSequence = [
        [_summary(agentLive: true)], // bootstrap — 점수 비공개
        [_summary(reportScore: 82)], // 완료 후 refreshSummary — 점수 공개
      ]
      ..convSequence = [
        _conv(agentLive: true, turns: const [
          AgentTurn(isMe: true, text: '안녕하세요, 반가워요!'),
        ]),
        _conv(agentLive: true, turns: const [
          AgentTurn(isMe: true, text: '안녕하세요, 반가워요!'),
          AgentTurn(isMe: false, text: '저도 반가워요 ㅎㅎ'),
        ]),
        _conv(agentLive: false, turns: const [
          AgentTurn(isMe: true, text: '안녕하세요, 반가워요!'),
          AgentTurn(isMe: false, text: '저도 반가워요 ㅎㅎ'),
        ]),
      ];

    await tester.pumpWidget(_wrap(repo));
    await _flush(tester);

    // 첫 턴 + 라이브 타이핑 인디케이터, 점수는 계산 중
    expect(find.text('안녕하세요, 반가워요!'), findsOneWidget);
    expect(find.textContaining('수아-AI 응답 생성 중'), findsOneWidget);
    expect(find.text('예상 케미스트리'), findsOneWidget); // 점수 비공개 상태
    expect(_richTextContaining('계산 중'), findsOneWidget);

    // 폴링 1회 → 둘째 턴 도착
    await tester.pump(const Duration(milliseconds: 60));
    await _flush(tester);
    expect(find.text('저도 반가워요 ㅎㅎ'), findsOneWidget);
    expect(find.textContaining('메시지 2'), findsOneWidget);

    // 폴링 2회 → 송출 완료: 타이핑 사라지고 점수 82 노출
    await tester.pump(const Duration(milliseconds: 60));
    await _flush(tester);
    expect(find.textContaining('응답 생성 중'), findsNothing);
    expect(find.textContaining('소개팅 완료 · 메시지 2'), findsOneWidget);
    expect(find.text('케미스트리'), findsOneWidget); // '예상' 떨어짐 = 점수 공개
    expect(_richTextContaining('82'), findsOneWidget);
  });
}
