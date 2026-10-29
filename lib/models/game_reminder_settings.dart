import 'dart:convert';

/// Settings model for scheduling and configuring notifications by type in Ludo Prince.
class GameReminderSettings {
  /// Master toggle for all reminder notifications.
  final bool enabled;

  /// Real-time match invites from friends.
  final bool gameInvitesEnabled;

  /// Real-time friend requests from players.
  final bool friendRequestsEnabled;

  /// Daily prime-time match reminder (e.g. 8:00 PM).
  final bool dailyReminderEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;

  /// Smart re-engagement nudge for inactive players (after 3 days).
  final bool inactivityReminderEnabled;
  final int inactivityDays;

  /// Special weekend reminder (Saturday 3:00 PM).
  final bool weekendReminderEnabled;
  final int weekendHour;
  final int weekendMinute;

  const GameReminderSettings({
    this.enabled = true,
    this.gameInvitesEnabled = true,
    this.friendRequestsEnabled = true,
    this.dailyReminderEnabled = true,
    this.dailyReminderHour = 20, // 8:00 PM
    this.dailyReminderMinute = 0,
    this.inactivityReminderEnabled = true,
    this.inactivityDays = 3,
    this.weekendReminderEnabled = true,
    this.weekendHour = 15, // 3:00 PM
    this.weekendMinute = 0,
  });

  /// Human-friendly 12-hour formatted time for daily reminder, e.g. "8:00 PM".
  String get dailyTimeString => _formatTime(dailyReminderHour, dailyReminderMinute);

  /// Human-friendly 12-hour formatted time for weekend reminder, e.g. "3:00 PM".
  String get weekendTimeString => _formatTime(weekendHour, weekendMinute);

  static String _formatTime(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $period';
  }

  GameReminderSettings copyWith({
    bool? enabled,
    bool? gameInvitesEnabled,
    bool? friendRequestsEnabled,
    bool? dailyReminderEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    bool? inactivityReminderEnabled,
    int? inactivityDays,
    bool? weekendReminderEnabled,
    int? weekendHour,
    int? weekendMinute,
  }) {
    return GameReminderSettings(
      enabled: enabled ?? this.enabled,
      gameInvitesEnabled: gameInvitesEnabled ?? this.gameInvitesEnabled,
      friendRequestsEnabled:
          friendRequestsEnabled ?? this.friendRequestsEnabled,
      dailyReminderEnabled: dailyReminderEnabled ?? this.dailyReminderEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      inactivityReminderEnabled:
          inactivityReminderEnabled ?? this.inactivityReminderEnabled,
      inactivityDays: inactivityDays ?? this.inactivityDays,
      weekendReminderEnabled:
          weekendReminderEnabled ?? this.weekendReminderEnabled,
      weekendHour: weekendHour ?? this.weekendHour,
      weekendMinute: weekendMinute ?? this.weekendMinute,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'gameInvitesEnabled': gameInvitesEnabled,
      'friendRequestsEnabled': friendRequestsEnabled,
      'dailyReminderEnabled': dailyReminderEnabled,
      'dailyReminderHour': dailyReminderHour,
      'dailyReminderMinute': dailyReminderMinute,
      'inactivityReminderEnabled': inactivityReminderEnabled,
      'inactivityDays': inactivityDays,
      'weekendReminderEnabled': weekendReminderEnabled,
      'weekendHour': weekendHour,
      'weekendMinute': weekendMinute,
    };
  }

  factory GameReminderSettings.fromMap(Map<String, dynamic> map) {
    return GameReminderSettings(
      enabled: map['enabled'] as bool? ?? true,
      gameInvitesEnabled: map['gameInvitesEnabled'] as bool? ?? true,
      friendRequestsEnabled: map['friendRequestsEnabled'] as bool? ?? true,
      dailyReminderEnabled: map['dailyReminderEnabled'] as bool? ?? true,
      dailyReminderHour: map['dailyReminderHour'] as int? ?? 20,
      dailyReminderMinute: map['dailyReminderMinute'] as int? ?? 0,
      inactivityReminderEnabled:
          map['inactivityReminderEnabled'] as bool? ?? true,
      inactivityDays: map['inactivityDays'] as int? ?? 3,
      weekendReminderEnabled: map['weekendReminderEnabled'] as bool? ?? true,
      weekendHour: map['weekendHour'] as int? ?? 15,
      weekendMinute: map['weekendMinute'] as int? ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory GameReminderSettings.fromJson(String source) {
    try {
      final decoded = jsonDecode(source) as Map<String, dynamic>;
      return GameReminderSettings.fromMap(decoded);
    } catch (_) {
      return const GameReminderSettings();
    }
  }
}
