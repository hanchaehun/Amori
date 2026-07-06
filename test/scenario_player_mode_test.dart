import 'package:amori/core/theme/app_theme.dart';
import 'package:amori/data/dummy/scenarios.dart';
import 'package:amori/features/persona/scenario_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  test('초기 페르소나 설정은 대표 5문항을 사용한다', () {
    final scenarios = scenariosByCodes(kInitialScenarioCodes);

    expect(scenarios.map((s) => s.code), ['R-1', 'R-2', 'R-3', 'R-4', 'R-5']);
  });

  test('데일리 질문 풀은 대표 질문과 강하게 겹치는 기존 문항을 제외한다', () {
    expect(kDailyScenarioCodes, hasLength(24));
    expect(kDailyScenarioCodes, isNot(contains('1-1')));
    expect(kDailyScenarioCodes, isNot(contains('3-1')));
    expect(kDailyScenarioCodes, isNot(contains('8-1')));
    expect(kDailyScenarioCodes, containsAll(['9-2', '1-3', '3-3', '6-3']));
  });

  testWidgets('초기 모드는 5문항 진행률을 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(const ScenarioPlayerScreen()));

    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('R-1'), findsOneWidget);
  });

  testWidgets('데일리 모드는 단일 문항 진행률을 보여준다', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const ScenarioPlayerScreen(
          mode: ScenarioPlayerMode.daily,
          scenarioCodes: ['2-1'],
        ),
      ),
    );

    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('2-1'), findsOneWidget);
    expect(find.text('답변 저장'), findsOneWidget);
  });
}
