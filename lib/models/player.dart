import 'token.dart';

enum PlayerType { localHuman, remoteHuman, localBot, remoteBot }

class Player {
  final PlayerSlot slot;
  final String name;
  final PlayerType type;
  final List<Token> tokens;

  Player({
    required this.slot,
    required this.name,
    this.type = PlayerType.localHuman,
    required this.tokens,
  });

  Player copyWith({
    String? name,
    PlayerType? type,
    List<Token>? tokens,
  }) {
    return Player(
      slot: slot,
      name: name ?? this.name,
      type: type ?? this.type,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
        "slot": slot.name,
        "name": name,
        "type": type.name,
        "tokens": tokens.map((t) => t.toJson()).toList(),
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      slot: PlayerSlot.values.firstWhere((e) => e.name == json["slot"]),
      name: json["name"],
      type: PlayerType.values.firstWhere((e) => e.name == json["type"]),
      tokens: (json["tokens"] as List).map((e) => Token.fromJson(e)).toList(),
    );
  }
}
