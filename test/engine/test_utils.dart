import 'package:ludo_prince/models/game_state.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/models/token.dart';

GameState baseState() {
  return GameState(
    gameId: "test",
    players: [
      Player(
        slot: PlayerSlot.slot1,
        name: "Blue",
        tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot1)),
      ),
      Player(
        slot: PlayerSlot.slot4,
        name: "Red",
        tokens: List.generate(4, (i) => Token(id: i, slot: PlayerSlot.slot4)),
      ),
    ],
    turnOrder: [PlayerSlot.slot1, PlayerSlot.slot4],
    currentTurn: PlayerSlot.slot1,
    winners: const [],
  );
}

GameState stateWithTokenAt(
    PlayerSlot slot, int tokenId, TokenState tokenState, int position) {
  final state = baseState();
  return state.copyWith(
    players: state.players.map((p) {
      if (p.slot != slot) return p;
      return p.copyWith(
        tokens: p.tokens.map((t) {
          if (t.id != tokenId) return t;
          return t.copyWith(state: tokenState, position: position);
        }).toList(),
      );
    }).toList(),
  );
}
