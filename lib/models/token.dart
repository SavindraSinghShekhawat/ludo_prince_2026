enum PlayerSlot { slot1, slot2, slot3, slot4 }
enum TokenState { home, board, homeStretch, finished }

class Token {
  final int id;
  final PlayerSlot slot;
  final TokenState state;
  final int position;

  Token({
    required this.id,
    required this.slot,
    this.state = TokenState.home,
    this.position = -1,
  });

  Token copyWith({
    TokenState? state,
    int? position,
  }) {
    return Token(
      id: id,
      slot: slot,
      state: state ?? this.state,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "slot": slot.name,
        "state": state.name,
        "position": position,
      };

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      id: json["id"],
      slot: PlayerSlot.values
          .firstWhere((e) => e.name == json["slot"]),
      state:
          TokenState.values.firstWhere((e) => e.name == json["state"]),
      position: json["position"],
    );
  }
}