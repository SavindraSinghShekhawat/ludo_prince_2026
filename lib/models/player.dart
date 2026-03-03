import 'package:ludo_prince/models/token.dart';

class Player {
  final PlayerSlot slot;
  final String name;
  final bool isBot;
  final List<Token> tokens;

  Player({
    required this.slot,
    required this.name,
    this.isBot = false,
    required this.tokens,
  });

  Player copyWith({
    String? name,
    bool? isBot,
    List<Token>? tokens,
  }) {
    return Player(
      slot: slot,
      name: name ?? this.name,
      isBot: isBot ?? this.isBot,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
        "slot": slot.name,
        "name": name,
        "isBot": isBot,
        "tokens": tokens.map((t) => t.toJson()).toList(),
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      slot: PlayerSlot.values.firstWhere((e) => e.name == json["slot"]),
      name: json["name"],
      isBot: json["isBot"] ?? false,
      tokens: (json["tokens"] as List).map((e) => Token.fromJson(e)).toList(),
    );
  }
}
