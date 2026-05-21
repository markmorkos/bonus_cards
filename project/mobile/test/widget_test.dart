import "package:flutter_test/flutter_test.dart";

import "package:bonus_cards_mobile/app.dart";

void main() {
  testWidgets("App builds", (WidgetTester tester) async {
    await tester.pumpWidget(const BonusApp());
    expect(find.byType(BonusApp), findsOneWidget);
  });
}