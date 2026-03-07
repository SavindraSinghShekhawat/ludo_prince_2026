import 'package:flutter_test/flutter_test.dart';
import 'package:ludo_prince/engine/game_engine.dart';
import 'package:ludo_prince/models/game_state.dart';
import 'package:ludo_prince/models/player.dart';
import 'package:ludo_prince/models/token.dart';
import 'package:ludo_prince/models/board_path.dart';
import 'test_utils.dart';

void main() {
  late GameEngine engine;

  setUp(() {
    engine = GameEngine();
  });

  group("Capture Logic", () {
    test("Capture happens on same absolute position", () {
      // Blue at relative 14 (Absolute 39 + 14 = 53 % 52 = 1)
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 14);
      // Red at relative 1 (Absolute 0 + 1 = 1)
      state = state.copyWith(
        players: state.players.map((p) {
          if (p.slot != PlayerSlot.slot4) return p;
          return p.copyWith(
            tokens: p.tokens.map((t) {
              if (t.id != 0) return t;
              return t.copyWith(state: TokenState.board, position: 1);
            }).toList(),
          );
        }).toList(),
      );

      bool captured = false;
      final blueToken = state.players[0].tokens[0];

      final engineResult = engine.applyStep(
        state,
        blueToken,
        allowCapture: true,
      );
      captured = engineResult.events.contains(EngineEvent.capture);
      final result = engineResult.state;

      expect(captured, true);
      expect(result.players[1].tokens[0].state, TokenState.home);
      expect(result.players[1].tokens[0].position, -1);
    });

    test("No capture on safe spot", () {
      // Blue at relative 0 (Safe spot)
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 0);
      // Red at relative 13 (Absolute 0 + 13 = 13)
      // Blue absolute 39 + 0 = 39.
      // Wait, let's align them.
      // Red Slot 4 start is 0. Safe spots: 0, 8, 13...
      // Blue Slot 1 start is 39. Safe spots: 0, 8, 13... (Relative)
      // Absolute of Blue relative 0 is 39.
      // Absolute of Red relative 39 is (0 + 39) = 39.

      state = state.copyWith(
        players: state.players.map((p) {
          if (p.slot != PlayerSlot.slot4) return p;
          return p.copyWith(
            tokens: p.tokens.map((t) {
              if (t.id != 0) return t;
              return t.copyWith(state: TokenState.board, position: 39);
            }).toList(),
          );
        }).toList(),
      );

      expect(BoardPath.isSafeSpot(0), true);

      bool captured = false;
      final blueToken = state.players[0].tokens[0];

      final result = engine.applyStep(
        state,
        blueToken,
        allowCapture: true,
      );
      captured = result.events.contains(EngineEvent.capture);

      expect(captured, false);
    });

    test("Capturing multiple tokens of the same opponent", () {
      // Blue at relative 14 (Absolute 1)
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 14);
      // Two Red tokens at absolute 1
      state = state.copyWith(
        players: state.players.map((p) {
          if (p.slot != PlayerSlot.slot4) return p;
          return p.copyWith(
            tokens: [
              p.tokens[0].copyWith(state: TokenState.board, position: 1),
              p.tokens[1].copyWith(state: TokenState.board, position: 1),
              p.tokens[2],
              p.tokens[3],
            ],
          );
        }).toList(),
      );

      bool captured = false;
      final blueToken = state.players[0].tokens[0];

      final engineResult = engine.applyStep(
        state,
        blueToken,
        allowCapture: true,
      );
      captured = engineResult.events.contains(EngineEvent.capture);
      final result = engineResult.state;

      expect(captured, true);
      expect(result.players[1].tokens[0].state, TokenState.home);
      expect(result.players[1].tokens[1].state, TokenState.home);
    });

    test("Extra turn on capture", () {
      // Setup a state where blue is about to capture red
      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 14);
      state = state.copyWith(
        players: state.players.map((p) {
          if (p.slot != PlayerSlot.slot4) return p;
          return p.copyWith(
            tokens: p.tokens.map((t) {
              if (t.id != 0) return t;
              return t.copyWith(state: TokenState.board, position: 1);
            }).toList(),
          );
        }).toList(),
        diceValue:
            3, // Doesn't matter for the call itself but for moveToken logic
        isDiceRolled: true,
      );

      // We need to simulate the capture happening in applyStep and then moveToken checking it
      // Actually moveToken takes a `captured` flag.

      final engineResult = engine.moveToken(state, 0, captured: true);
      final result = engineResult.state;

      expect(result.currentTurn, PlayerSlot.slot1);
      expect(result.message.contains("extra turn"), true);
      expect(engineResult.events.contains(EngineEvent.extraTurn), true);
    });
    test("No capture on path (intermediate steps)", () {
      // Blue starting at relative 10, moving to 13 (rolling a 3)
      // Red at relative 11 (Absolute mapping: Blue 10 is absolute 49, Blue 11 is absolute 50)
      // Blue Slot 1: Starts 39. Rel 10 -> Abs (39+10)%52 = 49. Rel 11 -> Abs (39+11)%52 = 50.

      var state = stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, 10);

      // Red Slot 4: Starts 0. Rel 50 -> Abs 50.
      state = state.copyWith(
        players: state.players.map((p) {
          if (p.slot != PlayerSlot.slot4) return p;
          return p.copyWith(
            tokens: [
              p.tokens[0].copyWith(state: TokenState.board, position: 50),
              ...p.tokens.sublist(1),
            ],
          );
        }).toList(),
      );

      bool captured = false;
      var blueToken = state.players[0].tokens[0];

      // Simulate intermediate step (Rel 11)
      blueToken = blueToken.copyWith(position: 11);

      // Call applyStep with allowCapture: false (this is how it should be called for intermediate steps)
      final engineResultIntermediate = engine.applyStep(
        state,
        blueToken,
        allowCapture: false,
      );
      captured = engineResultIntermediate.events.contains(EngineEvent.capture);
      final resultIntermediate = engineResultIntermediate.state;

      expect(captured, false);
      expect(resultIntermediate.players[1].tokens[0].state, TokenState.board);

      // Verify that if we DID allow capture at intermediate, it WOULD capture (verifying the setup)
      bool capturedInError = false;
      final engineResultError = engine.applyStep(
        state,
        blueToken,
        allowCapture: true,
      );
      capturedInError = engineResultError.events.contains(EngineEvent.capture);
      expect(capturedInError, true);
    });

    test("No capture in Home Stretch", () {
      // Blue at relative 52 (Home Stretch)
      // Red doesn't have an absolute position that overlaps with Blue's home stretch,
      // but let's verify the logic in applyStep specifically.

      var state =
          stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.homeStretch, 52);

      // Even if another token somehow shared the same "absolute position" (which is impossible for Home Stretch)
      // applyStep checks TokenState.board

      bool captured = false;
      final blueToken = state.players[0].tokens[0];

      final engineResult = engine.applyStep(
        state,
        blueToken,
        allowCapture: true,
      );
      captured = engineResult.events.contains(EngineEvent.capture);

      expect(captured, false);
    });

    test("Collision logic with 4 players", () {
      // Slot 1 (Blue) at Rel 0 -> Abs 39
      // Slot 4 (Red) at Rel 39 -> Abs 39 (Collision!)
      // Slot 3 (Green) at Rel 26 -> Abs 13 + 26 = 39 (Collision!)
      // Slot 2 (Yellow) at Rel 13 -> Abs 26 + 13 = 39 (Collision!)

      final state = GameState(
        gameId: "4p",
        players: [
          Player(slot: PlayerSlot.slot1, name: "B", tokens: [
            Token(
                id: 0,
                slot: PlayerSlot.slot1,
                state: TokenState.board,
                position: 0)
          ]),
          Player(slot: PlayerSlot.slot4, name: "R", tokens: [
            Token(
                id: 0,
                slot: PlayerSlot.slot4,
                state: TokenState.board,
                position: 39)
          ]),
          Player(slot: PlayerSlot.slot3, name: "G", tokens: [
            Token(
                id: 0,
                slot: PlayerSlot.slot3,
                state: TokenState.board,
                position: 26)
          ]),
          Player(slot: PlayerSlot.slot2, name: "Y", tokens: [
            Token(
                id: 0,
                slot: PlayerSlot.slot2,
                state: TokenState.board,
                position: 13)
          ]),
        ],
        turnOrder: [
          PlayerSlot.slot1,
          PlayerSlot.slot4,
          PlayerSlot.slot3,
          PlayerSlot.slot2
        ],
        currentTurn: PlayerSlot.slot1,
        winners: const [],
      );

      bool captured = false;

      // Blue moves to its relative 0 (which is a safe spot)
      // Wait, Rel 0 IS a safe spot. Let's move to Rel 1 which is NOT a safe spot.

      // Slot 1 (Blue) at Rel 1 -> Abs 40
      // Slot 4 (Red) at Rel 40 -> Abs 40
      // Slot 3 (Green) at Rel 27 -> Abs 13 + 27 = 40
      // Slot 2 (Yellow) at Rel 14 -> Abs 26 + 14 = 40

      final collidingState = GameState(
        gameId: "collision",
        players: [
          Player(slot: PlayerSlot.slot1, name: "B", tokens: [
            Token(
                id: 0,
                slot: PlayerSlot.slot1,
                state: TokenState.board,
                position: 1)
          ]),
          Player(slot: PlayerSlot.slot4, name: "R", tokens: [
            Token(
                id: 1,
                slot: PlayerSlot.slot4,
                state: TokenState.board,
                position: 40)
          ]),
          Player(slot: PlayerSlot.slot3, name: "G", tokens: [
            Token(
                id: 2,
                slot: PlayerSlot.slot3,
                state: TokenState.board,
                position: 27)
          ]),
          Player(slot: PlayerSlot.slot2, name: "Y", tokens: [
            Token(
                id: 3,
                slot: PlayerSlot.slot2,
                state: TokenState.board,
                position: 14)
          ]),
        ],
        turnOrder: [
          PlayerSlot.slot1,
          PlayerSlot.slot4,
          PlayerSlot.slot3,
          PlayerSlot.slot2
        ],
        currentTurn: PlayerSlot.slot1,
        winners: const [],
      );

      final blueToken = collidingState.players[0].tokens[0];

      final engineResult = engine.applyStep(
        collidingState,
        blueToken,
        allowCapture: true,
      );
      captured = engineResult.events.contains(EngineEvent.capture);
      final result = engineResult.state;

      expect(captured, true);
      // All other players' tokens at that spot should be captured
      expect(result.players[1].tokens[0].state, TokenState.home);
      expect(result.players[2].tokens[0].state, TokenState.home);
      expect(result.players[3].tokens[0].state, TokenState.home);
    });

    test("Global Safe Spots Immunity", () {
      // For each safe spot (relative 0, 8, 13, 21, 26, 34, 39, 47)
      // verify that any player landing on it with another player present does NOT capture.

      for (int spot in BoardPath.safeRelativeSpots) {
        // Setup Blue (slot 1) already on that absolute spot
        int absPos = BoardPath.getAbsolutePosition(PlayerSlot.slot1, spot);

        var state =
            stateWithTokenAt(PlayerSlot.slot1, 0, TokenState.board, spot);

        // Find another player (e.g. Red) and put them on the SAME absolute position
        // Red (Slot 4) start is 0.
        // We need to find Red's relative position for that absolute position.
        // abs = (start + rel) % 52  => rel = (abs - start + 52) % 52
        int redRel = (absPos - 0 + 52) % 52;

        state = state.copyWith(
          players: state.players.map((p) {
            if (p.slot != PlayerSlot.slot4) return p;
            return p.copyWith(
              tokens: [
                p.tokens[0].copyWith(state: TokenState.board, position: redRel),
                ...p.tokens.sublist(1),
              ],
            );
          }).toList(),
        );

        bool captured = false;
        // Red "lands" on the spot (simulated by applyStep with allowCapture: true)
        final redToken = state.players[1].tokens[0];

        final engineResult = engine.applyStep(
          state,
          redToken,
          allowCapture: true,
        );
        captured = engineResult.events.contains(EngineEvent.capture);

        expect(captured, false,
            reason:
                "Capture should not happen on safe spot relative $spot (Absolute $absPos)");
      }
    });
  });
}
