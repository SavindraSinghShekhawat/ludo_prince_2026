import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ludo_prince/models/game_reminder_settings.dart';
import 'package:ludo_prince/providers/game_reminder_provider.dart';
import 'package:ludo_prince/services/notification_service.dart';
import 'package:ludo_prince/services/game_reminder_messages.dart';
import 'package:ludo_prince/utils/app_logger.dart';

final gameReminderSyncServiceProvider =
    Provider<GameReminderSyncService>((ref) {
  final service = GameReminderSyncService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class GameReminderSyncService {
  final Ref _ref;
  bool _isSyncing = false;

  static const int idDailyPrimeTime = 2001;
  static const int idWeekendSpecial = 2002;
  static const int idInactivity3Day = 2003;
  static const int idInactivity7Day = 2004;
  static const int idTestNotification = 2099;

  GameReminderSyncService(this._ref) {
    _init();
  }

  void _init() {
    _ref.listen<GameReminderSettings>(
      gameReminderProvider,
      (previous, next) => syncReminders(next),
    );

    // Initial sync
    syncReminders(_ref.read(gameReminderProvider));
  }

  void dispose() {}

  /// Synchronizes scheduled notifications with current [GameReminderSettings].
  Future<void> syncReminders([GameReminderSettings? currentSettings]) async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final GameReminderSettings settings =
          currentSettings ?? _ref.read(gameReminderProvider);

      if (!settings.enabled) {
        // Master switch is OFF: cancel all active reminders
        await notificationService.cancelReminder(idDailyPrimeTime);
        await notificationService.cancelReminder(idWeekendSpecial);
        await notificationService.cancelReminder(idInactivity3Day);
        await notificationService.cancelReminder(idInactivity7Day);
        AppLogger.debug('GameReminderSyncService: Master switch OFF, cancelled all reminders.');
        return;
      }

      // 1. Daily Evening Prime-Time Match Reminder
      if (settings.dailyReminderEnabled) {
        final prompt = GameReminderMessages.getDailyPrompt();
        await notificationService.scheduleDailyReminder(
          id: idDailyPrimeTime,
          title: prompt.title,
          body: prompt.body,
          hour: settings.dailyReminderHour,
          minute: settings.dailyReminderMinute,
          payload: 'daily_prime_time',
        );
      } else {
        await notificationService.cancelReminder(idDailyPrimeTime);
      }

      // 2. Weekend Special Battle (Saturday 3:00 PM)
      if (settings.weekendReminderEnabled) {
        final prompt = GameReminderMessages.weekendPrompt;
        await notificationService.scheduleWeeklyReminder(
          id: idWeekendSpecial,
          title: prompt.title,
          body: prompt.body,
          dayOfWeek: DateTime.saturday,
          hour: settings.weekendHour,
          minute: settings.weekendMinute,
          payload: 'weekend_special',
        );
      } else {
        await notificationService.cancelReminder(idWeekendSpecial);
      }

      // 3. Inactivity Re-engagement Nudges
      if (settings.inactivityReminderEnabled) {
        await _rescheduleInactivityReminders(settings.inactivityDays);
      } else {
        await notificationService.cancelReminder(idInactivity3Day);
        await notificationService.cancelReminder(idInactivity7Day);
      }
    } catch (e, st) {
      AppLogger.error('GameReminderSyncService: Error during sync: $e', st);
    } finally {
      _isSyncing = false;
    }
  }

  /// Records active play or app launch and pushes inactivity timers forward.
  Future<void> recordAppActivity() async {
    final settings = _ref.read(gameReminderProvider);
    if (settings.enabled && settings.inactivityReminderEnabled) {
      await _rescheduleInactivityReminders(settings.inactivityDays);
      AppLogger.debug('GameReminderSyncService: Recorded activity, refreshed inactivity reminders.');
    }
  }

  /// Pushes the 3-day and 7-day inactivity reminders into the future from now.
  Future<void> _rescheduleInactivityReminders(int daysThreshold) async {
    final now = DateTime.now();

    // 3 Days away (at 7:30 PM)
    final prompt3 = GameReminderMessages.inactivity3DayPrompt;
    final scheduledDate3 = DateTime(
      now.year,
      now.month,
      now.day,
      19,
      30,
    ).add(Duration(days: daysThreshold));

    await notificationService.scheduleOneTimeReminder(
      id: idInactivity3Day,
      title: prompt3.title,
      body: prompt3.body,
      scheduledTime: scheduledDate3,
      payload: 'inactivity_3d',
    );

    // 7 Days away (at 7:30 PM)
    final prompt7 = GameReminderMessages.inactivity7DayPrompt;
    final scheduledDate7 = DateTime(
      now.year,
      now.month,
      now.day,
      19,
      30,
    ).add(const Duration(days: 7));

    await notificationService.scheduleOneTimeReminder(
      id: idInactivity7Day,
      title: prompt7.title,
      body: prompt7.body,
      scheduledTime: scheduledDate7,
      payload: 'inactivity_7d',
    );
  }

  /// Dispatches a sample notification immediately for user testing.
  Future<void> sendTestNotification({
    String? title,
    String? body,
    String? payload,
  }) async {
    await notificationService.requestPermissions();
    final prompt = GameReminderMessages.getRandomPrompt();
    await notificationService.showImmediateNotification(
      id: idTestNotification,
      title: title ?? prompt.title,
      body: body ?? prompt.body,
      payload: payload ?? 'test_notification',
    );
  }

  /// Dispatches a test game invite notification.
  Future<void> sendTestGameInvite() async {
    await sendTestNotification(
      title: '⚔️ Game Invitation',
      body: 'PrinceAlex invited you to play a Quick Match!',
      payload: 'test_game_invite|test_invite_001|PrinceAlex|demo_room_101|PRINCE7',
    );
  }

  /// Dispatches a test friend request notification.
  Future<void> sendTestFriendRequest() async {
    await sendTestNotification(
      title: '👑 Friend Request',
      body: 'QueenVictoria wants to add you to their royal circle!',
      payload: 'test_friend_request|test_req_001|QueenVictoria',
    );
  }

  /// Dispatches a test daily battle reminder notification.
  Future<void> sendTestBattleReminder() async {
    final prompt = GameReminderMessages.getDailyPrompt();
    await sendTestNotification(
      title: prompt.title,
      body: prompt.body,
      payload: 'test_battle_reminder',
    );
  }
}
