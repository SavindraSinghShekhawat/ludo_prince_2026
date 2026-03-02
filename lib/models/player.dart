import 'token.dart';

class Player {
  final PlayerColor color;
  final String name;
  final List<Token> tokens;
  final bool isActive; // false if player disconnected or not playing in match

  Player({
    required this.color,
    required this.name,
    required this.tokens,
    this.isActive = true,
  });

  bool get hasFinished {
    return tokens.every((token) => token.state == TokenState.finished);
  }

  Player copyWith({
    String? name,
    List<Token>? tokens,
    bool? isActive,
  }) {
    return Player(
      color: color,
      name: name ?? this.name,
      tokens: tokens ?? this.tokens,
      isActive: isActive ?? this.isActive,
    );
  }
}
