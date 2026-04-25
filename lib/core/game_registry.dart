import 'game_definition.dart';

/// Central registry for all available game modules.
///
/// Games register themselves at startup via [register].
/// The Home Screen reads [all] to auto-populate game cards.
class GameRegistry {
  GameRegistry._();

  static final Map<String, GameDefinition> _games = {};

  /// Register a game module. Duplicate [gameId] values are silently replaced.
  static void register(GameDefinition definition) {
    _games[definition.gameId] = definition;
  }

  /// Look up a game by its id.
  static GameDefinition? get(String gameId) => _games[gameId];

  /// All registered game definitions, ordered by registration.
  static List<GameDefinition> get all => _games.values.toList();

  /// Clear all registrations (useful for testing).
  static void clear() => _games.clear();
}
