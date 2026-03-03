enum PlayerColor { red, green, yellow, blue }
enum TokenState { home, board, homeStretch, finished }

class Token {
  final int id;
  final PlayerColor color;
  final TokenState state;
  final int position;

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

  Map<String, dynamic> toJson() => {
        "id": id,
        "color": color.name,
        "state": state.name,
        "position": position,
      };

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      id: json["id"],
      color: PlayerColor.values
          .firstWhere((e) => e.name == json["color"]),
      state:
          TokenState.values.firstWhere((e) => e.name == json["state"]),
      position: json["position"],
    );
  }
}