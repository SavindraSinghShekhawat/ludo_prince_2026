import 'package:flutter/material.dart';

/// Contract that every game module must implement to plug into the platform.
///
/// The platform's Home Screen, Lobby, and Matchmaking read from this
/// interface to render game-specific UI and delegate to game-specific logic.
abstract class GameDefinition {
  /// Unique string identifier, e.g. `'ludo'`, `'snakes_and_ladders'`.
  String get gameId;

  /// Human-readable name shown on the Home Screen, e.g. `'Ludo Prince'`.
  String get displayName;

  /// Short tagline shown below the name.
  String get description;

  /// Icon shown on the game card.
  IconData get icon;

  /// Accent colour used for the game card glow and in-game chrome.
  Color get accentColor;

  /// Player counts this game supports, e.g. `[2, 3, 4]`.
  List<int> get supportedPlayerCounts;

  /// Named game modes, e.g. `['classic', 'team']`.
  List<String> get supportedModes;

  /// Whether the game is ready to play (`true`) or "Coming Soon" (`false`).
  bool get isAvailable;

  /// Builds the primary game-play screen widget.
  Widget buildGameScreen({
    required String sessionId,
    required bool isOnline,
  });

  /// Builds a standalone board widget for previews / thumbnails.
  Widget buildBoardPreview();
}
