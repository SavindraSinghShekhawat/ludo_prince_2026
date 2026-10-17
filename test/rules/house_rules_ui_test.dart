import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/games/ludo/domain/models/game_rules.dart';
import 'package:ludo_prince/games/ludo/ui/widgets/house_rules_selector.dart';

void main() {
  testWidgets('HouseRulesSelector shows CLASSIC and default summary when uncustomized', (tester) async {
    const rules = GameRules();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HouseRulesSelector(
            rules: rules,
            onRulesChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('HOUSE RULES'), findsOneWidget);
    expect(find.text('CLASSIC'), findsOneWidget);
    expect(find.text('Standard rules (Tap to customize)'), findsOneWidget);
  });

  testWidgets('HouseRulesSelector shows CUSTOM and active rules text when custom rules selected', (tester) async {
    const rules = GameRules(
      openOnOneAndSix: true,
      tokensPerPlayer: 2,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HouseRulesSelector(
            rules: rules,
            onRulesChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('HOUSE RULES'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);
    expect(find.text('Open on 1 & 6 • 2 Tokens (Quick)'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(1));
  });

  testWidgets('HouseRulesSelector expands and allows toggling rules', (tester) async {
    GameRules currentRules = const GameRules();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return HouseRulesSelector(
                rules: currentRules,
                onRulesChanged: (newRules) {
                  setState(() => currentRules = newRules);
                },
              );
            },
          ),
        ),
      ),
    );

    // Tap header to expand
    await tester.tap(find.text('HOUSE RULES'));
    await tester.pumpAndSettle();

    expect(find.text('Open on 1 or 6'), findsOneWidget);
    expect(find.text('Tokens per Player'), findsOneWidget);
    expect(find.text('Three 6s Penalty'), findsOneWidget);
    expect(find.text('4 Tokens'), findsOneWidget);
    expect(find.text('2 Tokens'), findsOneWidget);

    // Three 6s penalty is ON by default
    expect(find.text('ON'), findsOneWidget);

    // Select 2 Tokens
    await tester.tap(find.text('2 Tokens'));
    await tester.pumpAndSettle();

    expect(currentRules.tokensPerPlayer, equals(2));
    expect(find.text('QUICK'), findsOneWidget);
    expect(find.text('CUSTOM'), findsOneWidget);
  });
}
