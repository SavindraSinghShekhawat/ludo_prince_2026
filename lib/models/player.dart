import 'package:ludo_prince/models/token.dart';

class Player {
  final PlayerColor color;
  final String name;
  final List<Token> tokens;

  Player({
    required this.color,
    required this.name,
    required this.tokens,
  });

  Player copyWith({
    String? name,
    List<Token>? tokens,
  }) {
    return Player(
      color: color,
      name: name ?? this.name,
      tokens: tokens ?? this.tokens,
    );
  }

  Map<String, dynamic> toJson() => {
        "color": color.name,
        "name": name,
        "tokens": tokens.map((t) => t.toJson()).toList(),
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      color: PlayerColor.values
          .firstWhere((e) => e.name == json["color"]),
      name: json["name"],
      tokens: (json["tokens"] as List)
          .map((e) => Token.fromJson(e))
          .toList(),
    );
  }
}