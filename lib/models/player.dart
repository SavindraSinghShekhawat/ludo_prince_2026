import 'token.dart';

enum PlayerType { localHuman, remoteHuman, localBot, remoteBot }

enum PlayerStatus { active, left }

class Player {
  final PlayerSlot slot;
  final String uid;
  final String name;
  final PlayerType type;
  final PlayerStatus status;
  final int skipCount;
  final List<Token> tokens;

  Player({
    required this.slot,
    String? uid,
    required this.name,
    this.type = PlayerType.localHuman,
    this.status = PlayerStatus.active,
    this.skipCount = 0,
    required this.tokens,
  }) : uid =
           uid ?? "local_${slot.name}_${DateTime.now().microsecondsSinceEpoch}";

  Player copyWith({
    String? uid,
    String? name,
    PlayerType? type,
    PlayerStatus? status,
    int? skipCount,
    List<Token>? tokens,
  }) {
    return Player(
      slot: slot,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      skipCount: skipCount ?? this.skipCount,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
    "slot": slot.name,
    "uid": uid,
    "name": name,
    "type": type.name,
    "status": status.name,
    "skipCount": skipCount,
    "tokens": tokens.map((t) => t.toJson()).toList(),
  };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      slot: PlayerSlot.values.firstWhere((e) => e.name == json["slot"]),
      uid: json["uid"] ?? "",
      name: json["name"],
      type: PlayerType.values.firstWhere((e) => e.name == json["type"]),
      status: PlayerStatus.values.firstWhere(
        (e) => e.name == (json["status"] ?? "active"),
      ),
      skipCount: json["skipCount"] ?? 0,
      tokens: (json["tokens"] as List).map((e) => Token.fromJson(e)).toList(),
    );
  }
}
