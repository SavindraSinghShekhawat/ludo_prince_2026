import 'dart:math';

/// Rich royal-themed notification copy bank for Ludo Prince.
class GameReminderMessages {
  GameReminderMessages._();

  static final Random _random = Random();

  /// Curated list of daily evening prime-time match prompts.
  static const List<({String title, String body})> dailyPrompts = [
    (
      title: '👑 The Prince Awaits!',
      body: 'Step onto the royal board for your evening match. Can you roll a six tonight?',
    ),
    (
      title: '🎲 Evening Dice Duel!',
      body: 'The arena is buzzing! Challenge live players and climb the leaderboard.',
    ),
    (
      title: '⚔️ Battle Time!',
      body: 'Your tokens are ready for action. Roll the dice and claim your evening victory.',
    ),
    (
      title: '🏆 Claim Your Crown!',
      body: 'A quick match awaits. Roll your lucky numbers and defend your throne.',
    ),
  ];

  /// Inactivity prompt (after 3 days).
  static const ({String title, String body}) inactivity3DayPrompt = (
    title: '🎲 Your tokens miss you!',
    body: 'Step back into the arena for a quick match. The board is waiting for you!',
  );

  /// Inactivity prompt (after 7 days).
  static const ({String title, String body}) inactivity7DayPrompt = (
    title: '👑 Reclaim Your Throne!',
    body: 'Challengers are ruling the board. Return to Ludo Prince and show them who is king!',
  );

  /// Weekend special battle prompt (Saturday afternoon).
  static const ({String title, String body}) weekendPrompt = (
    title: '⚔️ Weekend Battle Royale!',
    body: 'Weekend rooms are buzzing! Jump in and dominate the board with live players.',
  );

  /// Returns a prompt for the daily reminder (rotating or pseudo-random by day-of-year).
  static ({String title, String body}) getDailyPrompt({DateTime? date}) {
    final now = date ?? DateTime.now();
    final dayOfYear = int.parse('${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}');
    final index = dayOfYear % dailyPrompts.length;
    return dailyPrompts[index];
  }

  /// Returns a random prompt for testing in Settings.
  static ({String title, String body}) getRandomPrompt() {
    return dailyPrompts[_random.nextInt(dailyPrompts.length)];
  }
}
