import 'token.dart';

enum PlayerType { localHuman, remoteHuman, localBot, remoteBot }

enum PlayerStatus { active, left }

class Player {
  final PlayerSlot slot;
  final String name;
  final PlayerType type;
  final PlayerStatus status;
  final List<Token> tokens;

  Player({
    required this.slot,
    required this.name,
    this.type = PlayerType.localHuman,
    this.status = PlayerStatus.active,
    required this.tokens,
  });

  Player copyWith({
    String? name,
    PlayerType? type,
    PlayerStatus? status,
    List<Token>? tokens,
  }) {
    return Player(
      slot: slot,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
        "slot": slot.name,
        "name": name,
        "type": type.name,
        "status": status.name,
        "tokens": tokens.map((t) => t.toJson()).toList(),
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      slot: PlayerSlot.values.firstWhere((e) => e.name == json["slot"]),
      name: json["name"],
      type: PlayerType.values.firstWhere((e) => e.name == json["type"]),
      status: PlayerStatus.values.firstWhere(
        (e) => e.name == (json["status"] ?? "active"),
      ),
      tokens: (json["tokens"] as List).map((e) => Token.fromJson(e)).toList(),
    );
  }
}
