import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ludo_prince/models/game_reminder_settings.dart';
import 'package:ludo_prince/services/notification_service.dart';

const String _kReminderSettingsKey = 'game_reminder_settings';

class GameReminderNotifier extends Notifier<GameReminderSettings> {
  SharedPreferences? _prefs;

  @override
  GameReminderSettings build() {
    _loadFromPrefs();
    return const GameReminderSettings();
  }

  Future<void> _loadFromPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final jsonStr = _prefs?.getString(_kReminderSettingsKey);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      state = GameReminderSettings.fromJson(jsonStr);
    }
  }

  Future<void> _persist(GameReminderSettings newSettings) async {
    state = newSettings;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_kReminderSettingsKey, newSettings.toJson());
  }

  Future<void> setMasterEnabled(bool enabled) async {
    if (enabled) {
      // Request permissions if enabling
      await notificationService.requestPermissions();
    }
    await _persist(state.copyWith(enabled: enabled));
  }

  Future<void> setDailyReminderEnabled(bool enabled) async {
    if (enabled && !state.enabled) {
      await notificationService.requestPermissions();
      await _persist(state.copyWith(enabled: true, dailyReminderEnabled: true));
    } else {
      await _persist(state.copyWith(dailyReminderEnabled: enabled));
    }
  }

  Future<void> setDailyReminderTime(int hour, int minute) async {
    await _persist(
      state.copyWith(dailyReminderHour: hour, dailyReminderMinute: minute),
    );
  }

  Future<void> setInactivityReminderEnabled(bool enabled) async {
    await _persist(state.copyWith(inactivityReminderEnabled: enabled));
  }

  Future<void> setGameInvitesEnabled(bool enabled) async {
    await _persist(state.copyWith(gameInvitesEnabled: enabled));
  }

  Future<void> setFriendRequestsEnabled(bool enabled) async {
    await _persist(state.copyWith(friendRequestsEnabled: enabled));
  }

  Future<void> setWeekendReminderEnabled(bool enabled) async {
    await _persist(state.copyWith(weekendReminderEnabled: enabled));
  }

  Future<void> resetToDefaults() async {
    await _persist(const GameReminderSettings());
  }
}

final gameReminderProvider =
    NotifierProvider<GameReminderNotifier, GameReminderSettings>(() {
  return GameReminderNotifier();
});
