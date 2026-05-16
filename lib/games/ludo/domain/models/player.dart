import 'package:flutter/foundation.dart';
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
  final int sixPity;
  final List<Token> tokens;

  Player({
    required this.slot,
    String? uid,
    required this.name,
    this.type = PlayerType.localHuman,
    this.status = PlayerStatus.active,
    this.skipCount = 0,
    this.sixPity = 2,
    required this.tokens,
  }) : uid = uid ??
            "local_${slot.name}_${DateTime.now().microsecondsSinceEpoch}";

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Player &&
          slot == other.slot &&
          uid == other.uid &&
          name == other.name &&
          type == other.type &&
          status == other.status &&
          skipCount == other.skipCount &&
          sixPity == other.sixPity &&
          listEquals(tokens, other.tokens);

  @override
  int get hashCode => Object.hash(
        slot,
        uid,
        name,
        type,
        status,
        skipCount,
        sixPity,
        Object.hashAll(tokens),
      );

  Player copyWith({
    String? uid,
    String? name,
    PlayerType? type,
    PlayerStatus? status,
    int? skipCount,
    int? sixPity,
    List<Token>? tokens,
  }) {
    return Player(
      slot: slot,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      type: type ?? this.type,
      status: status ?? this.status,
      skipCount: skipCount ?? this.skipCount,
      sixPity: sixPity ?? this.sixPity,
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
        "sixPity": sixPity,
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
      sixPity: json["sixPity"] ?? 2,
      tokens: (json["tokens"] as List).map((e) => Token.fromJson(e)).toList(),
    );
  }
}
