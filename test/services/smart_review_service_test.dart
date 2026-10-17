import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/services/smart_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SmartReviewService Logic Tests', () {
    test('should not show prompt if fewer than 3 games completed', () async {
      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 2,
        SmartReviewService.keyGamesWon: 1,
      });

      final service = SmartReviewService.instance;
      final shouldShow = await service.shouldShowPrompt(isPostWin: true);
      expect(shouldShow, isFalse);
    });

    test('should not show prompt if user has never won a game and is not post-win', () async {
      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 5,
        SmartReviewService.keyGamesWon: 0,
      });

      final service = SmartReviewService.instance;
      final shouldShow = await service.shouldShowPrompt(isPostWin: false);
      expect(shouldShow, isFalse);
    });

    test('should show prompt if 3+ games completed and post-win', () async {
      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 3,
        SmartReviewService.keyGamesWon: 0,
      });

      final service = SmartReviewService.instance;
      final shouldShow = await service.shouldShowPrompt(isPostWin: true);
      expect(shouldShow, isTrue);
    });

    test('should show prompt if 3+ games completed and has past wins', () async {
      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 4,
        SmartReviewService.keyGamesWon: 2,
      });

      final service = SmartReviewService.instance;
      final shouldShow = await service.shouldShowPrompt(isPostWin: false);
      expect(shouldShow, isTrue);
    });

    test('should never show prompt if already rated', () async {
      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 10,
        SmartReviewService.keyGamesWon: 5,
        SmartReviewService.keyAlreadyRated: true,
      });

      final service = SmartReviewService.instance;
      final shouldShow = await service.shouldShowPrompt(isPostWin: true);
      expect(shouldShow, isFalse);
    });

    test('should snooze prompt if shown recently (< 7 days ago)', () async {
      final twoDaysAgoMillis = DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 5,
        SmartReviewService.keyGamesWon: 3,
        SmartReviewService.keyLastPromptTime: twoDaysAgoMillis,
      });

      final service = SmartReviewService.instance;
      final shouldShow = await service.shouldShowPrompt(isPostWin: true);
      expect(shouldShow, isFalse);
    });

    test('should allow prompt if snooze window (> 14 days) has expired', () async {
      final fifteenDaysAgoMillis = DateTime.now()
          .subtract(const Duration(days: 15))
          .millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 5,
        SmartReviewService.keyGamesWon: 3,
        SmartReviewService.keyLastPromptTime: fifteenDaysAgoMillis,
      });

      final service = SmartReviewService.instance;
      final shouldShow = await service.shouldShowPrompt(isPostWin: true);
      expect(shouldShow, isTrue);
    });

    test('should manage pending victory prompt consumption correctly', () {
      final service = SmartReviewService.instance;
      service.setPendingVictoryPrompt(true);
      expect(service.consumePendingVictoryPrompt(), isTrue);
      // Second consumption must be false
      expect(service.consumePendingVictoryPrompt(), isFalse);
    });

    test('should block prompt for 60 days after negative feedback', () async {
      final twentyDaysAgoMillis = DateTime.now()
          .subtract(const Duration(days: 20))
          .millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 10,
        SmartReviewService.keyGamesWon: 5,
        SmartReviewService.keyNegativeFeedbackTime: twentyDaysAgoMillis,
      });

      final service = SmartReviewService.instance;
      final shouldShow = await service.shouldShowPrompt(isPostWin: true);
      expect(shouldShow, isFalse);
    });

    test('should properly record game completion and wins', () async {
      SharedPreferences.setMockInitialValues({
        SmartReviewService.keyGamesCompleted: 1,
        SmartReviewService.keyGamesWon: 0,
      });

      final service = SmartReviewService.instance;
      await service.recordGameCompleted(isWinner: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(SmartReviewService.keyGamesCompleted), equals(2));
      expect(prefs.getInt(SmartReviewService.keyGamesWon), equals(1));
    });
  });
}
