import 'package:flutter_test/flutter_test.dart';

import 'package:amori/app.dart';

void main() {
  testWidgets('AmoriApp boots into the splash screen', (tester) async {
    await tester.pumpWidget(const AmoriApp());
    await tester.pumpAndSettle();

    expect(find.text('시작하기'), findsOneWidget);
    expect(find.textContaining('amori'), findsWidgets);
  });
}
