import 'player.dart';
import 'token.dart';

class GameState {
  final List<Player> players;
  final List<PlayerColor> turnOrder;
  final PlayerColor currentTurn;
  final int diceValue;
  final bool isDiceRolled;
  final int consecutiveSixes;
  final String message;

  GameState({
    required this.players,
    required this.turnOrder,
    required this.currentTurn,
    this.diceValue = 1,
    this.isDiceRolled = false,
    this.consecutiveSixes = 0,
    this.message = "Game Started!",
  });

  GameState copyWith({
    List<Player>? players,
    List<PlayerColor>? turnOrder,
    PlayerColor? currentTurn,
    int? diceValue,
    bool? isDiceRolled,
    int? consecutiveSixes,
    String? message,
  }) {
    return GameState(
      players: players ?? this.players,
      turnOrder: turnOrder ?? this.turnOrder,
      currentTurn: currentTurn ?? this.currentTurn,
      diceValue: diceValue ?? this.diceValue,
      isDiceRolled: isDiceRolled ?? this.isDiceRolled,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() => {
        "players": players.map((p) => p.toJson()).toList(),
        "turnOrder": turnOrder.map((e) => e.name).toList(),
        "currentTurn": currentTurn.name,
        "diceValue": diceValue,
        "isDiceRolled": isDiceRolled,
        "consecutiveSixes": consecutiveSixes,
        "message": message,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      players: (json["players"] as List).map((e) => Player.fromJson(e)).toList(),
      turnOrder: (json["turnOrder"] as List).map((e) => PlayerColor.values.firstWhere((p) => p.name == e)).toList(),
      currentTurn: PlayerColor.values.firstWhere((e) => e.name == json["currentTurn"]),
      diceValue: json["diceValue"],
      isDiceRolled: json["isDiceRolled"],
      consecutiveSixes: json["consecutiveSixes"],
      message: json["message"],
    );
  }
}
