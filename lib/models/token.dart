enum PlayerColor { red, green, yellow, blue }

enum TokenState {
  home, // In the base
  board, // On the outer path
  safe, // On a star or safe start square
  homeStretch, // On the inner path towards center
  finished // Reached the center
}

class Token {
  final int id;
  final PlayerColor color;
  TokenState state;
  int position; // 0-56 depending on the path (-1 when in home/finished)

  Token({
    required this.id,
    required this.color,
    this.state = TokenState.home,
    this.position = -1,
  });

  Token copyWith({
    TokenState? state,
    int? position,
  }) {
    return Token(
      id: id,
      color: color,
      state: state ?? this.state,
      position: position ?? this.position,
    );
  }
}
