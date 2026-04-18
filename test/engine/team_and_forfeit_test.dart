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

  group("Team Mode Mechanics", () {
    test("Teammates cannot capture each other", () {
      // Slot 1 (Blue) and Slot 3 (Green) are teammates
      // Setup Slot 3 token at relative 26 (Absolute 13 + 26 = 39)
      // Slot 1 start is 39. So Slot 3 relative 26 is Absolute 39.
      // Slot 1 relative 0 is also Absolute 39.

      var state = GameState(
        gameId: "team-test",
        gameMode: GameMode.team,
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: "Blue",
            tokens: [
              Token(
                id: 0,
                slot: PlayerSlot.slot1,
                state: TokenState.board,
                position: 0,
              ),
            ],
          ),
          Player(
            slot: PlayerSlot.slot3,
            name: "Green",
            tokens: [
              Token(
                id: 0,
                slot: PlayerSlot.slot3,
                state: TokenState.board,
                position: 26,
              ),
            ],
          ),
        ],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot3],
        currentTurn: PlayerSlot.slot1,
        winners: const [],
      );

      // Slot 1 lands on Slot 3's position
      final blueToken = state.players[0].tokens[0];
      final result = engine.applyStep(state, blueToken, allowCapture: true);

      expect(
        result.events.contains(EngineEvent.capture),
        false,
        reason: "Teammates should not capture each other",
      );
      expect(
        result.state.players[1].tokens[0].state,
        TokenState.board,
        reason: "Teammate token should remain on board",
      );
    });

    test("Team win condition: both teammates must finish", () {
      // Slot 1 finished all, Slot 3 has one remaining
      var state = GameState(
        gameId: "team-win-test",
        gameMode: GameMode.team,
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: "Blue",
            tokens: List.generate(
              4,
              (i) => Token(
                id: i,
                slot: PlayerSlot.slot1,
                state: TokenState.finished,
                position: 56,
              ),
            ),
          ),
          Player(
            slot: PlayerSlot.slot3,
            name: "Green",
            tokens: [
              Token(
                id: 0,
                slot: PlayerSlot.slot3,
                state: TokenState.homeStretch,
                position: 55,
              ),
              ...List.generate(
                3,
                (i) => Token(
                  id: i + 1,
                  slot: PlayerSlot.slot3,
                  state: TokenState.finished,
                  position: 56,
                ),
              ),
            ],
          ),
        ],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot3],
        currentTurn: PlayerSlot.slot3,
        winners: const [],
        diceValue: 1,
        isDiceRolled: true,
      );

      // Move last token of Slot 3 to finish
      final token = state.players[1].tokens[0];
      final finishedToken = engine.advanceOneStep(token);
      state = engine.applyStep(state, finishedToken).state;

      final result = engine.moveToken(state, 0);

      // Now both should be in winners
      expect(result.state.winners.contains(PlayerSlot.slot1), true);
      expect(result.state.winners.contains(PlayerSlot.slot3), true);
      expect(result.state.isGameOver, true);
    });

    test("Turn rotation: finished player is skipped", () {
      // Slot 1 finished all tokens, Slot 3 is still playing
      // Opponent Slot 4 is also playing
      var state = GameState(
        gameId: "turn-skip-test",
        gameMode: GameMode.team,
        players: [
          Player(
            slot: PlayerSlot.slot1,
            name: "Blue",
            tokens: List.generate(
              4,
              (i) => Token(
                id: i,
                slot: PlayerSlot.slot1,
                state: TokenState.finished,
                position: 56,
              ),
            ),
          ),
          Player(
            slot: PlayerSlot.slot3,
            name: "Green",
            tokens: List.generate(
              4,
              (i) => Token(
                id: i,
                slot: PlayerSlot.slot3,
                state: TokenState.board,
                position: 0,
              ),
            ),
          ),
          Player(
            slot: PlayerSlot.slot4,
            name: "Red",
            tokens: List.generate(
              4,
              (i) => Token(
                id: i,
                slot: PlayerSlot.slot4,
                state: TokenState.board,
                position: 0,
              ),
            ),
          ),
        ],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot4, PlayerSlot.slot3],
        currentTurn: PlayerSlot.slot3, // Green's turn
        winners:
            const [], // Note: Slot 1 is NOT in winners yet because Green hasn't finished
      );

      // Verify slot 1 has finished all tokens
      expect(
        state.players[0].tokens.every((t) => t.state == TokenState.finished),
        true,
      );

      // Green moves
      final stateAfterRoll = state.copyWith(diceValue: 2, isDiceRolled: true);
      final result = engine.moveToken(stateAfterRoll, 0);

      // Should skip Slot 1 and go to Slot 4
      expect(result.state.currentTurn, PlayerSlot.slot4);
    });
  });

  group("Forfeit Logic", () {
    test("Active player quits during their turn", () {
      var state = baseState(); // Slot 1 turn
      expect(state.currentTurn, PlayerSlot.slot1);

      final result = engine.quitPlayer(state, PlayerSlot.slot1);

      expect(result.state.players[0].status, PlayerStatus.left);
      expect(result.state.currentTurn, PlayerSlot.slot4);
      expect(result.events.contains(EngineEvent.quit), true);
    });

    test("Classic mode forfeit: last remaining player wins", () {
      // 3 players
      var state = GameState(
        gameId: "forfeit-classic",
        gameMode: GameMode.classic,
        players: [
          Player(slot: PlayerSlot.slot1, name: "P1", tokens: []),
          Player(slot: PlayerSlot.slot4, name: "P2", tokens: []),
          Player(slot: PlayerSlot.slot3, name: "P3", tokens: []),
        ],
        turnOrder: [PlayerSlot.slot1, PlayerSlot.slot4, PlayerSlot.slot3],
        currentTurn: PlayerSlot.slot1,
        winners: [],
      );

      // P1 quits
      state = engine.quitPlayer(state, PlayerSlot.slot1).state;
      expect(state.isGameOver, false);

      // P2 quits -> P3 should win
      state = engine.quitPlayer(state, PlayerSlot.slot4).state;

      expect(state.isGameOver, true);
      expect(state.winners.first, PlayerSlot.slot3);
      expect(state.message.contains("forfeit"), true);
    });

    test("Team mode forfeit: any opponent quits leads to win", () {
      // Team 1 (1, 3) vs Team 2 (2, 4)
      var state = GameState(
        gameId: "forfeit-team",
        gameMode: GameMode.team,
        players: [
          Player(slot: PlayerSlot.slot1, name: "T1-A", tokens: []),
          Player(slot: PlayerSlot.slot3, name: "T1-B", tokens: []),
          Player(slot: PlayerSlot.slot2, name: "T2-A", tokens: []),
          Player(slot: PlayerSlot.slot4, name: "T2-B", tokens: []),
        ],
        turnOrder: [
          PlayerSlot.slot1,
          PlayerSlot.slot2,
          PlayerSlot.slot3,
          PlayerSlot.slot4,
        ],
        currentTurn: PlayerSlot.slot1,
        winners: [],
      );

      // One player from Team 2 quits
      state = engine.quitPlayer(state, PlayerSlot.slot2).state;

      expect(state.isGameOver, true);
      expect(state.winners.contains(PlayerSlot.slot1), true);
      expect(state.winners.contains(PlayerSlot.slot3), true);
      expect(state.message.contains("Team A wins"), true);
    });
  });
}
