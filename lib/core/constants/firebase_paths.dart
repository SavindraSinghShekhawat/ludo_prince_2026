/// Centralised Firebase RTDB path builder.
///
/// All paths that were previously hardcoded (e.g. `ludogames/$gameId`) now
/// go through this class so the schema can evolve in one place.
class FirebasePaths {
  FirebasePaths._();

  // ── Game Sessions ─────────────────────────────────────────────────────────
  /// Root for all game sessions of a given type.
  static String gameRoot(String gameType) => 'games/$gameType';

  /// A specific game session.
  static String session(String gameType, String sessionId) =>
      'games/$gameType/$sessionId';

  /// Players sub-node.
  static String players(String gameType, String sessionId) =>
      'games/$gameType/$sessionId/players';

  /// Events sub-node.
  static String events(String gameType, String sessionId) =>
      'gameEvents/$gameType/$sessionId';

  /// Action requests sub-node (for timeout handling).
  static String actionRequests(String gameType, String sessionId) =>
      'games/$gameType/$sessionId/actionRequests';

  // ── Matchmaking ───────────────────────────────────────────────────────────
  /// Matchmaking queue root for a game type and mode.
  static String matchmakingQueue(String gameType, String modeQueue) =>
      'matchmaking/$gameType/$modeQueue/queue';

  /// A specific player's slot in the queue.
  static String matchmakingSlot(
          String gameType, String modeQueue, String uid) =>
      'matchmaking/$gameType/$modeQueue/queue/$uid';

  /// Player's matchmaking assignment.
  static String matchmakingAssignment(String uid) =>
      'matchmakingAssignments/$uid';

  // ── Private Room Codes ────────────────────────────────────────────────────
  static String privateRoomCode(String code) => 'privateRoomCodes/$code';

  // ── Presence ──────────────────────────────────────────────────────────────
  static String presence(String uid) => 'presence/$uid';

  // ── Invites ───────────────────────────────────────────────────────────────
  static String invites(String uid) => 'invites/$uid';

  // ── Stats ─────────────────────────────────────────────────────────────────
  static String onlineCount() => 'stats/onlineCount';
}
