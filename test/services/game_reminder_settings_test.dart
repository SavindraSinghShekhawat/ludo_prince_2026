import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/models/game_reminder_settings.dart';
import 'package:ludo_prince/services/game_reminder_messages.dart';

void main() {
  group('GameReminderSettings', () {
    test('default settings are enabled with 8:00 PM battle time', () {
      const settings = GameReminderSettings();
      expect(settings.enabled, isTrue);
      expect(settings.gameInvitesEnabled, isTrue);
      expect(settings.friendRequestsEnabled, isTrue);
      expect(settings.dailyReminderEnabled, isTrue);
      expect(settings.dailyReminderHour, 20);
      expect(settings.dailyReminderMinute, 0);
      expect(settings.dailyTimeString, '8:00 PM');
      expect(settings.inactivityReminderEnabled, isTrue);
      expect(settings.inactivityDays, 3);
      expect(settings.weekendReminderEnabled, isTrue);
      expect(settings.weekendTimeString, '3:00 PM');
    });

    test('serializes and deserializes cleanly to/from json', () {
      const original = GameReminderSettings(
        enabled: true,
        dailyReminderEnabled: true,
        dailyReminderHour: 21,
        dailyReminderMinute: 30,
        inactivityReminderEnabled: false,
        inactivityDays: 5,
        weekendReminderEnabled: true,
        weekendHour: 16,
        weekendMinute: 15,
      );

      final jsonStr = original.toJson();
      final restored = GameReminderSettings.fromJson(jsonStr);

      expect(restored.dailyReminderHour, 21);
      expect(restored.dailyReminderMinute, 30);
      expect(restored.dailyTimeString, '9:30 PM');
      expect(restored.inactivityReminderEnabled, isFalse);
      expect(restored.inactivityDays, 5);
      expect(restored.weekendHour, 16);
      expect(restored.weekendMinute, 15);
      expect(restored.weekendTimeString, '4:15 PM');
    });

    test('copyWith updates properties properly', () {
      const settings = GameReminderSettings();
      final updated = settings.copyWith(
        dailyReminderHour: 19,
        dailyReminderMinute: 45,
      );
      expect(updated.dailyReminderHour, 19);
      expect(updated.dailyReminderMinute, 45);
      expect(updated.dailyTimeString, '7:45 PM');
      expect(updated.enabled, isTrue);
    });
  });

  group('GameReminderMessages', () {
    test('daily prompts rotation provides rich royal copy', () {
      final prompt = GameReminderMessages.getDailyPrompt();
      expect(prompt.title, isNotEmpty);
      expect(prompt.body, isNotEmpty);
      expect(GameReminderMessages.dailyPrompts.length, greaterThanOrEqualTo(3));
    });

    test('inactivity and weekend prompts are available', () {
      expect(GameReminderMessages.inactivity3DayPrompt.title, contains('tokens'));
      expect(GameReminderMessages.inactivity7DayPrompt.title, contains('Throne'));
      expect(GameReminderMessages.weekendPrompt.title, contains('Weekend'));
    });
  });
}
