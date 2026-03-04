import 'player.dart';
import 'token.dart';

enum GameAction {
  none,
  roll,
  move,
  capture,
  finish,
  skip,
}

class GameState {
  final String gameId;
  final List<Player> players;
  final List<PlayerSlot> turnOrder;
  final PlayerSlot currentTurn;
  final int diceValue;
  final bool isDiceRolled;
  final bool isRolling;
  final int consecutiveSixes;
  final String message;
  final GameAction lastAction;
  final List<PlayerSlot> winners;

  bool get isGameOver {
    // Game is over when all players are added to the winners list
    return players.length > 1 && winners.length >= players.length;
  }

  GameState({
    required this.gameId,
    required this.players,
    required this.turnOrder,
    required this.currentTurn,
    this.diceValue = 1,
    this.isDiceRolled = false,
    this.isRolling = false,
    this.consecutiveSixes = 0,
    this.message = "Game Started!",
    this.lastAction = GameAction.none,
    this.winners = const [],
  });

  GameState copyWith({
    String? gameId,
    List<Player>? players,
    List<PlayerSlot>? turnOrder,
    PlayerSlot? currentTurn,
    int? diceValue,
    bool? isDiceRolled,
    bool? isRolling,
    int? consecutiveSixes,
    String? message,
    GameAction? lastAction,
    List<PlayerSlot>? winners,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      players: players ?? this.players,
      turnOrder: turnOrder ?? this.turnOrder,
      currentTurn: currentTurn ?? this.currentTurn,
      diceValue: diceValue ?? this.diceValue,
      isDiceRolled: isDiceRolled ?? this.isDiceRolled,
      isRolling: isRolling ?? this.isRolling,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      message: message ?? this.message,
      lastAction: lastAction ?? this.lastAction,
      winners: winners ?? this.winners,
    );
  }

  Map<String, dynamic> toJson() => {
        "gameId": gameId,
        "players": players.map((p) => p.toJson()).toList(),
        "turnOrder": turnOrder.map((e) => e.name).toList(),
        "currentTurn": currentTurn.name,
        "diceValue": diceValue,
        "isDiceRolled": isDiceRolled,
        "isRolling": isRolling,
        "consecutiveSixes": consecutiveSixes,
        "message": message,
        "lastAction": lastAction.name,
        "winners": winners.map((e) => e.name).toList(),
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      gameId: json["gameId"],
      players:
          (json["players"] as List).map((e) => Player.fromJson(e)).toList(),
      turnOrder: (json["turnOrder"] as List)
          .map((e) => PlayerSlot.values.firstWhere((p) => p.name == e))
          .toList(),
      currentTurn:
          PlayerSlot.values.firstWhere((e) => e.name == json["currentTurn"]),
      diceValue: json["diceValue"],
      isDiceRolled: json["isDiceRolled"],
      isRolling: json["isRolling"] ?? false,
      consecutiveSixes: json["consecutiveSixes"],
      message: json["message"],
      lastAction:
          GameAction.values.firstWhere((e) => e.name == json["lastAction"]),
      winners: (json["winners"] as List?)
              ?.map((e) => PlayerSlot.values.firstWhere((p) => p.name == e))
              .toList() ??
          [],
    );
  }
}
