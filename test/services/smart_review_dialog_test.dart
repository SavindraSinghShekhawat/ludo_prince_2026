import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/ui/dialogs/smart_review_dialog.dart';
import 'package:ludo_prince/ui/screens/feedback_screen.dart';

void main() {
  testWidgets('SmartReviewDialog transitions smoothly to Platinum store CTA on 5-star rating', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartReviewDialog(),
        ),
      ),
    );

    expect(find.text('ENJOYING LUDO PRINCE?'), findsOneWidget);
    expect(find.byIcon(Icons.star_outline_rounded), findsNWidgets(5));

    // Tap the 5th star
    final stars = find.byIcon(Icons.star_outline_rounded);
    await tester.tap(stars.at(4));
    await tester.pump(const Duration(milliseconds: 50));

    // Immediate reaction text changes smoothly
    expect(find.text('Royally Epic! 👑✨'), findsOneWidget);

    // Initial pacing delay (420ms) before action card reveals to prevent shocking users
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify positive Platinum CTA is now gently revealed
    expect(find.textContaining('RATE ON'), findsOneWidget);
    expect(find.textContaining('helps fellow players discover Ludo Prince'), findsOneWidget);
  });

  testWidgets('SmartReviewDialog reveals constructive feedback CTA on 2-star rating with no store link', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SmartReviewDialog(),
          ),
        ),
      ),
    );

    // Tap the 2nd star
    final stars = find.byIcon(Icons.star_outline_rounded);
    await tester.tap(stars.at(1));
    await tester.pump(const Duration(milliseconds: 50));

    // Reaction text for 2 stars
    expect(find.text('Needs Work 😕'), findsOneWidget);

    // Advance past pacing delay & reveal animation
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify constructive feedback CTA is displayed
    expect(find.text('TELL US HOW TO IMPROVE'), findsOneWidget);

    // CRITICAL: Ensure zero store rating links exist in negative flow
    expect(find.textContaining('RATE ON APP STORE'), findsNothing);
    expect(find.textContaining('RATE ON GOOGLE PLAY'), findsNothing);

    // Tap the feedback button
    await tester.tap(find.text('TELL US HOW TO IMPROVE'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // Verify user is now on FeedbackScreen
    expect(find.byType(FeedbackScreen), findsOneWidget);
    expect(find.text('SHARE FEEDBACK'), findsOneWidget);
    expect(
      find.text("We'd love to make Ludo Prince a 5-star experience for you. What can we improve?"),
      findsOneWidget,
    );
  });

  testWidgets('SmartReviewDialog locks rating after initial selection to prevent modification', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SmartReviewDialog(),
        ),
      ),
    );

    final stars = find.byIcon(Icons.star_outline_rounded);

    // Initial selection: Tap 5th star
    await tester.tap(stars.at(4));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Royally Epic! 👑✨'), findsOneWidget);

    // Attempt to modify rating: Tap 1st star
    final filledStars = find.byIcon(Icons.star_rounded);
    await tester.tap(filledStars.at(0));
    await tester.pump(const Duration(milliseconds: 50));

    // Rating should REMAIN locked at 5 stars, ignoring modification attempt
    expect(find.text('Royally Epic! 👑✨'), findsOneWidget);
    expect(find.text('Disappointed 😞'), findsNothing);
  });
}

