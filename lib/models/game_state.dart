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
  final int consecutiveSixes;
  final String message;
  final GameAction lastAction;

  bool get isGameOver {
    int finishedPlayers = players.where((p) => p.tokens.every((t) => t.state == TokenState.finished)).length;
    // Game is over if all but one player has finished (or if all players have finished)
    return players.length > 1 && finishedPlayers >= players.length - 1;
  }

  GameState({
    required this.gameId,
    required this.players,
    required this.turnOrder,
    required this.currentTurn,
    this.diceValue = 1,
    this.isDiceRolled = false,
    this.consecutiveSixes = 0,
    this.message = "Game Started!",
    this.lastAction = GameAction.none,
  });

  GameState copyWith({
    String? gameId,
    List<Player>? players,
    List<PlayerSlot>? turnOrder,
    PlayerSlot? currentTurn,
    int? diceValue,
    bool? isDiceRolled,
    int? consecutiveSixes,
    String? message,
    GameAction? lastAction,
  }) {
    return GameState(
      gameId: gameId ?? this.gameId,
      players: players ?? this.players,
      turnOrder: turnOrder ?? this.turnOrder,
      currentTurn: currentTurn ?? this.currentTurn,
      diceValue: diceValue ?? this.diceValue,
      isDiceRolled: isDiceRolled ?? this.isDiceRolled,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      message: message ?? this.message,
      lastAction: lastAction ?? this.lastAction,
    );
  }

  Map<String, dynamic> toJson() => {
        "gameId": gameId,
        "players": players.map((p) => p.toJson()).toList(),
        "turnOrder": turnOrder.map((e) => e.name).toList(),
        "currentTurn": currentTurn.name,
        "diceValue": diceValue,
        "isDiceRolled": isDiceRolled,
        "consecutiveSixes": consecutiveSixes,
        "message": message,
        "lastAction": lastAction.name,
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
      consecutiveSixes: json["consecutiveSixes"],
      message: json["message"],
      lastAction:
          GameAction.values.firstWhere((e) => e.name == json["lastAction"]),
    );
  }
}
