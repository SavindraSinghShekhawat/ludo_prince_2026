import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/engine/game_engine.dart';
import 'package:ludo_prince/models/game_state.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/models/token.dart';
import 'test_utils.dart';

void main() {
  late GameEngine engine;

  setUp(() {
    engine = GameEngine();
  });

  group("Winner Logic", () {
    test("First player to finish all tokens becomes first winner", () {
      // Slot 1 has 3 tokens finished, 1 in home stretch at 55
      var state = baseState();
      state = state.copyWith(
        players: state.players.map((p) {
          if (p.slot != PlayerSlot.slot1) return p;
          return p.copyWith(
            tokens: [
              p.tokens[0].copyWith(state: TokenState.finished, position: 56),
              p.tokens[1].copyWith(state: TokenState.finished, position: 56),
              p.tokens[2].copyWith(state: TokenState.finished, position: 56),
              p.tokens[3].copyWith(state: TokenState.homeStretch, position: 55),
            ],
          );
        }).toList(),
        diceValue: 1,
        isDiceRolled: true,
      );

      // Finish the last token: advance it and apply the step to the state
      final token = state.players[0].tokens[3];
      final finishedToken = engine.advanceOneStep(token);
      state = engine.applyStep(state, finishedToken).state;

      // Now finalize the turn
      final result = engine.moveToken(state, 3).state;

      expect(result.winners, [PlayerSlot.slot1, PlayerSlot.slot4]);
      expect(result.isGameOver,
          true); // In 2-player game, one winner means game over
    });

    test("Game ends when only one player hasn't finished (in 2 player game)",
        () {
      // Slot 1 finishes
      var state = baseState();
      state = state.copyWith(
        players: state.players.map((p) {
          if (p.slot != PlayerSlot.slot1) return p;
          return p.copyWith(
            tokens: [
              p.tokens[0].copyWith(state: TokenState.finished, position: 56),
              p.tokens[1].copyWith(state: TokenState.finished, position: 56),
              p.tokens[2].copyWith(state: TokenState.finished, position: 56),
              p.tokens[3].copyWith(state: TokenState.homeStretch, position: 55),
            ],
          );
        }).toList(),
        diceValue: 1,
        isDiceRolled: true,
      );

      // Finish the last token
      final token = state.players[0].tokens[3];
      final finishedToken = engine.advanceOneStep(token);
      state = engine.applyStep(state, finishedToken).state;

      final result = engine.moveToken(state, 3).state;

      expect(result.winners.length, 2);
      expect(result.winners, [PlayerSlot.slot1, PlayerSlot.slot4]);
      expect(result.isGameOver, true);
      expect(result.message, "Game Over!");
    });

    test("Turn system skips winners", () {
      // 3 players game (Hypothetical, our baseState has 2 but let's see)
      // Actually our GameEngine handles any number of players in turnOrder.

      final state = GameState(
        gameId: "test",
        players: [
          Player(
              slot: PlayerSlot.slot1,
              name: "B",
              tokens: List.generate(
                  4,
                  (i) => Token(
                      id: i,
                      slot: PlayerSlot.slot1,
                      state: TokenState.finished,
                      position: 56))),
          Player(
              slot: PlayerSlot.slot4,
              name: "R",
              tokens: List.generate(
                  4, (i) => Token(id: i, slot: PlayerSlot.slot4))),
          Player(
              slot: PlayerSlot.slot3,
              name: "G",
              tokens: List.generate(
                  4, (i) => Token(id: i, slot: PlayerSlot.slot3))),
        ],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot4, PlayerSlot.slot3],
        currentTurn: PlayerSlot.slot3, // Green's turn
        winners: [PlayerSlot.slot1], // Blue already won
      );

      // Green rolls a 3 and moves (normal turn end)
      final stateAfterRoll = state.copyWith(diceValue: 3, isDiceRolled: true);
      final result = engine.moveToken(stateAfterRoll, 0);

      // Should skip Blue (slot 1) and go to Red (slot 4)
      expect(result.state.currentTurn, PlayerSlot.slot4);
    });

    test("Turn system skips multiple winners", () {
      final state = GameState(
        gameId: "4p-skipping",
        players: [
          Player(
              slot: PlayerSlot.slot1,
              name: "B",
              tokens: List.generate(
                  4,
                  (i) => Token(
                      id: i,
                      slot: PlayerSlot.slot1,
                      state: TokenState.finished,
                      position: 56))),
          Player(
              slot: PlayerSlot.slot4,
              name: "R",
              tokens: List.generate(
                  4,
                  (i) => Token(
                      id: i,
                      slot: PlayerSlot.slot4,
                      state: TokenState.board,
                      position: 1))),
          Player(
              slot: PlayerSlot.slot3,
              name: "G",
              tokens: List.generate(
                  4,
                  (i) => Token(
                      id: i,
                      slot: PlayerSlot.slot3,
                      state: TokenState.finished,
                      position: 56))),
          Player(
              slot: PlayerSlot.slot2,
              name: "Y",
              tokens: List.generate(
                  4,
                  (i) => Token(
                      id: i,
                      slot: PlayerSlot.slot2,
                      state: TokenState.board,
                      position: 1))),
        ],
        turnOrder: [
          PlayerSlot.slot1,
          PlayerSlot.slot4,
          PlayerSlot.slot3,
          PlayerSlot.slot2
        ],
        currentTurn: PlayerSlot.slot4, // Red's turn
        winners: [PlayerSlot.slot1, PlayerSlot.slot3], // Blue and Green won
      );

      // Red rolls a 2 and moves
      final stateAfterRoll = state.copyWith(diceValue: 2, isDiceRolled: true);
      // We simulate applyStep and then moveToken
      final result = engine.moveToken(stateAfterRoll, 0);

      // Should skip Green (slot 3) and go to Yellow (slot 2)
      expect(result.state.currentTurn, PlayerSlot.slot2);
    });
  });
}
