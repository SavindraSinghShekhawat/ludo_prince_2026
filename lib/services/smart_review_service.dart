import 'dart:io';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ludo_prince/services/device_info_service.dart';
import 'package:ludo_prince/services/feedback_service.dart';
import 'package:ludo_prince/ui/dialogs/smart_review_dialog.dart';
import 'package:ludo_prince/utils/app_logger.dart';

class SmartReviewService {
  // App & Store Identifiers
  static const String appStoreId = '6760012267';
  static const String packageName = 'com.paisphere.ludoprince';

  // Smart Tuning Criteria
  static const int minGamesCompletedBeforePrompt = 3;
  static const int minDaysBetweenPrompts = 14;
  static const int negativeFeedbackCooldownDays = 60;
  static const int maxPromptCountPerInstall = 3;

  // SharedPreferences Keys
  static const String keyGamesCompleted = 'smart_review_games_completed';
  static const String keyGamesWon = 'smart_review_games_won';
  static const String keyAlreadyRated = 'smart_review_already_rated';
  static const String keyLastPromptTime = 'smart_review_last_prompt_millis';
  static const String keyPromptCount = 'smart_review_prompt_count';
  static const String keyNegativeFeedbackTime = 'smart_review_negative_feedback_millis';

  InAppReview? _inAppReview;
  DeviceInfoService? _deviceInfoService;
  FeedbackService? _feedbackService;
  bool _pendingVictoryPrompt = false;

  SmartReviewService({
    InAppReview? inAppReview,
    DeviceInfoService? deviceInfoService,
    FeedbackService? feedbackService,
  })  : _inAppReview = inAppReview,
        _deviceInfoService = deviceInfoService,
        _feedbackService = feedbackService;

  static final SmartReviewService instance = SmartReviewService();

  InAppReview get inAppReview => _inAppReview ??= InAppReview.instance;
  DeviceInfoService get deviceInfoService => _deviceInfoService ??= DeviceInfoService();
  FeedbackService get feedbackService => _feedbackService ??= FeedbackService();

  /// Flag set when the player finishes a winning match.
  void setPendingVictoryPrompt(bool value) {
    _pendingVictoryPrompt = value;
  }

  /// Consumes the pending victory prompt flag so it only fires once.
  bool consumePendingVictoryPrompt() {
    final value = _pendingVictoryPrompt;
    _pendingVictoryPrompt = false;
    return value;
  }

  /// Record a game finished by the player.
  Future<void> recordGameCompleted({required bool isWinner}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCompleted = prefs.getInt(keyGamesCompleted) ?? 0;
      await prefs.setInt(keyGamesCompleted, currentCompleted + 1);

      if (isWinner) {
        final currentWins = prefs.getInt(keyGamesWon) ?? 0;
        await prefs.setInt(keyGamesWon, currentWins + 1);
      }
      AppLogger.debug(
        '[SmartReview] Recorded match completed (won: $isWinner). Total: ${currentCompleted + 1}',
      );
    } catch (e) {
      AppLogger.error('[SmartReview] Failed to record game completed', e);
    }
  }

  /// Evaluates whether the user qualifies to see the rating prompt.
  Future<bool> shouldShowPrompt({bool isPostWin = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Rule 1: Never show again if user already rated or went to store
      final alreadyRated = prefs.getBool(keyAlreadyRated) ?? false;
      if (alreadyRated) {
        AppLogger.debug('[SmartReview] Skipping prompt: User already rated');
        return false;
      }

      // Rule 2: Minimum games played condition
      final gamesCompleted = prefs.getInt(keyGamesCompleted) ?? 0;
      if (gamesCompleted < minGamesCompletedBeforePrompt) {
        AppLogger.debug(
          '[SmartReview] Skipping prompt: Only $gamesCompleted/$minGamesCompletedBeforePrompt games played',
        );
        return false;
      }

      // Rule 3: Win condition - strongly prefer players who have experienced a win
      final gamesWon = prefs.getInt(keyGamesWon) ?? 0;
      if (gamesWon < 1 && !isPostWin) {
        AppLogger.debug('[SmartReview] Skipping prompt: Player has not won a game yet');
        return false;
      }

      // Rule 4: Fatigue / Cooldown check (snooze after "Maybe Later" or dismissal)
      final lastPromptTime = prefs.getInt(keyLastPromptTime) ?? 0;
      if (lastPromptTime > 0) {
        final elapsedDays =
            (DateTime.now().millisecondsSinceEpoch - lastPromptTime) /
            (1000 * 60 * 60 * 24);
        if (elapsedDays < minDaysBetweenPrompts) {
          AppLogger.debug(
            '[SmartReview] Skipping prompt: Cooldown active (${elapsedDays.toStringAsFixed(1)}/$minDaysBetweenPrompts days)',
          );
          return false;
        }
      }

      // Rule 5: Negative feedback cooldown (60 days)
      final negativeFeedbackTime = prefs.getInt(keyNegativeFeedbackTime) ?? 0;
      if (negativeFeedbackTime > 0) {
        final elapsedDays =
            (DateTime.now().millisecondsSinceEpoch - negativeFeedbackTime) /
            (1000 * 60 * 60 * 24);
        if (elapsedDays < negativeFeedbackCooldownDays) {
          AppLogger.debug(
            '[SmartReview] Skipping prompt: Negative feedback cooldown active (${elapsedDays.toStringAsFixed(1)}/$negativeFeedbackCooldownDays days)',
          );
          return false;
        }
      }

      // Rule 6: Max prompt count ceiling
      final promptCount = prefs.getInt(keyPromptCount) ?? 0;
      if (promptCount >= maxPromptCountPerInstall) {
        AppLogger.debug('[SmartReview] Skipping prompt: Reached max prompt count ($promptCount)');
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('[SmartReview] Error checking shouldShowPrompt', e);
      return false;
    }
  }

  /// Record that the dialog was shown.
  Future<void> recordPromptShown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final promptCount = prefs.getInt(keyPromptCount) ?? 0;
      await prefs.setInt(keyPromptCount, promptCount + 1);
      await prefs.setInt(
        keyLastPromptTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      AppLogger.error('[SmartReview] Error recording prompt shown', e);
    }
  }

  /// Launch the native store review sheet or store page.
  /// Only called when the user gave a positive rating (4 or 5 stars).
  Future<void> requestStoreReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyAlreadyRated, true);

      AppLogger.info('[SmartReview] Requesting store review...');

      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        await inAppReview.openStoreListing(appStoreId: appStoreId);
      }
    } catch (e) {
      AppLogger.error('[SmartReview] InAppReview failed, falling back to direct URL', e);
      await _openStoreListingFallback();
    }
  }

  /// Record constructive/negative feedback (1 to 3 stars).
  /// NEVER routes to App Store or Play Store.
  Future<void> recordConstructiveFeedback({
    required int rating,
    required String message,
    List<String>? tags,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        keyNegativeFeedbackTime,
        DateTime.now().millisecondsSinceEpoch,
      );

      final deviceMetadata = await deviceInfoService.getDeviceInfo();
      await feedbackService.submitFeedback(
        message.isEmpty ? 'Rating: $rating stars (No comment provided)' : message,
        deviceMetadata: deviceMetadata,
        rating: rating,
        tags: tags,
      );
      AppLogger.info('[SmartReview] Saved private negative feedback to Firestore');
    } catch (e) {
      AppLogger.error('[SmartReview] Error recording negative feedback', e);
    }
  }

  /// Fallback URL launcher when InAppReview is unavailable.
  Future<void> _openStoreListingFallback() async {
    try {
      Uri? storeUri;
      if (Platform.isIOS) {
        storeUri = Uri.parse(
          'itms-apps://itunes.apple.com/app/id$appStoreId?action=write-review',
        );
      } else if (Platform.isAndroid) {
        storeUri = Uri.parse('market://details?id=$packageName');
      }

      if (storeUri != null && await canLaunchUrl(storeUri)) {
        await launchUrl(storeUri, mode: LaunchMode.externalApplication);
      } else {
        final webUrl = Uri.parse(
          Platform.isIOS
              ? 'https://apps.apple.com/app/id$appStoreId?action=write-review'
              : 'https://play.google.com/store/apps/details?id=$packageName',
        );
        if (await canLaunchUrl(webUrl)) {
          await launchUrl(webUrl, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      AppLogger.error('[SmartReview] Store fallback launch failed', e);
    }
  }

  /// Evaluates criteria and shows dialog if eligible, or forced (for manual triggers).
  Future<bool> checkAndPrompt(
    BuildContext context, {
    bool isPostWin = false,
    bool force = false,
  }) async {
    if (!context.mounted) return false;

    if (!force) {
      final eligible = await shouldShowPrompt(isPostWin: isPostWin);
      if (!eligible) return false;
    }

    if (!context.mounted) return false;

    await recordPromptShown();
    if (!context.mounted) return false;
    await showSmartReviewDialog(context);
    return true;
  }

  /// Displays the interactive review dialog.
  Future<void> showSmartReviewDialog(BuildContext context) async {
    if (!context.mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Review Dialog',
      barrierColor: Colors.black.withValues(alpha: 0.8),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) => const SmartReviewDialog(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        return ScaleTransition(
          scale: anim1.drive(
            Tween<double>(begin: 0.85, end: 1.0).chain(
              CurveTween(curve: Curves.easeOutBack),
            ),
          ),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }
}
