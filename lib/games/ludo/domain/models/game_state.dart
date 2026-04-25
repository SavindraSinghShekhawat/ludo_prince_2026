import 'player.dart';
import 'token.dart';

enum GameAction { none, roll, move, capture, finish, skip, quit }

enum GameMode { classic, team }

enum GameType { local, online }

class GameState {
  final String gameId;
  final List<Player> players;
  final List<PlayerSlot> turnOrder;
  final PlayerSlot currentTurn;
  final GameMode gameMode;
  final int diceValue;
  final bool isDiceRolled;
  final bool isRolling;
  final bool isWaitingForResult;
  final int consecutiveSixes;
  final String message;
  final GameAction lastAction;
  final List<PlayerSlot> winners;
  final GameType gameType;
  final int? prefetchedSeed;

  final int? turnStartedAt;
  final int turnTimeSeconds;
  final int turnActionCount;

  bool get isGameOver {
    // Game is over when all players are added to the winners list
    return players.length > 1 && winners.length >= players.length;
  }

  GameState({
    required this.gameId,
    required this.players,
    required this.turnOrder,
    required this.currentTurn,
    this.gameMode = GameMode.classic,
    this.diceValue = 1,
    this.isDiceRolled = false,
    this.isRolling = false,
    this.isWaitingForResult = false,
    this.consecutiveSixes = 0,
    this.message = "Game Started!",
    this.lastAction = GameAction.none,
    this.winners = const [],
    this.gameType = GameType.local,
    this.prefetchedSeed,
    this.turnStartedAt,
    this.turnTimeSeconds = 15,
    this.turnActionCount = 0,
  });

  GameState copyWith({
    String? gameId,
    List<Player>? players,
    List<PlayerSlot>? turnOrder,
    PlayerSlot? currentTurn,
    GameMode? gameMode,
    int? diceValue,
    bool? isDiceRolled,
    bool? isRolling,
    bool? isWaitingForResult,
    int? consecutiveSixes,
    String? message,
    GameAction? lastAction,
    List<PlayerSlot>? winners,
    GameType? gameType,
    int? turnStartedAt,
    int? prefetchedSeed,
    int? turnTimeSeconds,
    int? turnActionCount,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      players: players ?? this.players,
      turnOrder: turnOrder ?? this.turnOrder,
      currentTurn: currentTurn ?? this.currentTurn,
      gameMode: gameMode ?? this.gameMode,
      diceValue: diceValue ?? this.diceValue,
      isDiceRolled: isDiceRolled ?? this.isDiceRolled,
      isRolling: isRolling ?? this.isRolling,
      isWaitingForResult: isWaitingForResult ?? this.isWaitingForResult,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      message: message ?? this.message,
      lastAction: lastAction ?? this.lastAction,
      winners: winners ?? this.winners,
      gameType: gameType ?? this.gameType,
      prefetchedSeed: prefetchedSeed ?? this.prefetchedSeed,
      turnStartedAt: turnStartedAt ?? this.turnStartedAt,
      turnTimeSeconds: turnTimeSeconds ?? this.turnTimeSeconds,
      turnActionCount: turnActionCount ?? this.turnActionCount,
    );
  }

  Map<String, dynamic> toJson() => {
        "gameId": gameId,
        "players": players.map((p) => p.toJson()).toList(),
        "turnOrder": turnOrder.map((e) => e.name).toList(),
        "currentTurn": currentTurn.name,
        "gameMode": gameMode.name,
        "diceValue": diceValue,
        "isDiceRolled": isDiceRolled,
        "isRolling": isRolling,
        "isWaitingForResult": isWaitingForResult,
        "consecutiveSixes": consecutiveSixes,
        "message": message,
        "lastAction": lastAction.name,
        "winners": winners.map((e) => e.name).toList(),
        "gameType": gameType.name,
        "prefetchedSeed": prefetchedSeed,
        "turnStartedAt": turnStartedAt,
        "turnTimeSeconds": turnTimeSeconds,
        "turnActionCount": turnActionCount,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      gameId: json["gameId"],
      players:
          (json["players"] as List).map((e) => Player.fromJson(e)).toList(),
      turnOrder: (json["turnOrder"] as List)
          .map((e) => PlayerSlot.values.firstWhere((p) => p.name == e))
          .toList(),
      currentTurn: PlayerSlot.values.firstWhere(
        (e) => e.name == json["currentTurn"],
      ),
      gameMode: GameMode.values.firstWhere(
        (e) => e.name == (json["gameMode"] ?? GameMode.classic.name),
      ),
      diceValue: json["diceValue"],
      isDiceRolled: json["isDiceRolled"],
      isRolling: json["isRolling"] ?? false,
      isWaitingForResult: json["isWaitingForResult"] ?? false,
      consecutiveSixes: json["consecutiveSixes"],
      message: json["message"],
      lastAction: GameAction.values.firstWhere(
        (e) => e.name == json["lastAction"],
      ),
      winners: (json["winners"] as List?)
              ?.map((e) => PlayerSlot.values.firstWhere((p) => p.name == e))
              .toList() ??
          [],
      gameType: GameType.values.firstWhere(
        (e) => e.name == (json["gameType"] ?? GameType.local.name),
      ),
      prefetchedSeed: json["prefetchedSeed"],
      turnStartedAt: json["turnStartedAt"] != null
          ? (json["turnStartedAt"] is int
              ? json["turnStartedAt"]
              : (json["turnStartedAt"] as num).toInt())
          : null,
      turnTimeSeconds: json["turnTimeSeconds"] ?? 8,
      turnActionCount: json["turnActionCount"] ?? 0,
    );
  }
}

extension GameStateVisual on GameState {
  PlayerSlot get localPlayerSlot {
    final localPlayer = players.firstWhere(
      (p) => p.type == PlayerType.localHuman,
      orElse: () => players.first,
    );
    return localPlayer.slot;
  }

  PlayerSlot getVisualSlot(PlayerSlot logicalSlot) {
    if (gameType != GameType.online) return logicalSlot;

    final local = localPlayerSlot;
    if (local == PlayerSlot.slot1) return logicalSlot;

    const List<PlayerSlot> seq = [
      PlayerSlot.slot1, // Blue
      PlayerSlot.slot4, // Red
      PlayerSlot.slot3, // Green
      PlayerSlot.slot2, // Yellow
    ];

    int localIdx = seq.indexOf(local);
    int logicalIdx = seq.indexOf(logicalSlot);

    int visualIdx = (logicalIdx - localIdx) % 4;
    if (visualIdx < 0) visualIdx += 4;

    return seq[visualIdx];
  }
}
