import 'token.dart';

enum PlayerType { localHuman, remoteHuman, localBot, remoteBot }

class Player {
  final PlayerSlot slot;
  final String name;
  final String? userId; // Added for online multiplayer
  final PlayerType type;
  final List<Token> tokens;

  Player({
    required this.slot,
    required this.name,
    this.userId,
    this.type = PlayerType.localHuman,
    required this.tokens,
  });

  Player copyWith({
    String? name,
    String? userId,
    PlayerType? type,
    List<Token>? tokens,
  }) {
    return Player(
      slot: slot,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
        "slot": slot.name,
        "name": name,
        "userId": userId,
        "type": type.name,
        "tokens": tokens.map((t) => t.toJson()).toList(),
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      slot: PlayerSlot.values.firstWhere((e) => e.name == json["slot"]),
      name: json["name"],
      userId: json["userId"],
      type: PlayerType.values.firstWhere((e) => e.name == json["type"]),
      tokens: (json["tokens"] as List).map((e) => Token.fromJson(e)).toList(),
    );
  }
}
