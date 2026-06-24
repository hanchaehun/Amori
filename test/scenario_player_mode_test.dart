import 'package:amori/core/theme/app_theme.dart';
import 'package:amori/data/dummy/scenarios.dart';
import 'package:amori/features/persona/scenario_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  test('초기 페르소나 설정은 대표 5문항을 사용한다', () {
    final scenarios = scenariosByCodes(kInitialScenarioCodes);

    expect(scenarios.map((s) => s.code), ['1-3', '3-3', '6-3', '8-1', '9-2']);
  });

  testWidgets('초기 모드는 5문항 진행률을 보여준다', (tester) async {
    await tester.pumpWidget(_wrap(const ScenarioPlayerScreen()));

    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('1-3'), findsOneWidget);
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
